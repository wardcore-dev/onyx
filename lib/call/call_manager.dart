// lib/call/call_manager.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:permission_handler/permission_handler.dart';
import '../screens/call_overlay.dart';
import '../globals.dart';
import '../l10n/app_localizations.dart';
import '../managers/settings_manager.dart';
import '../services/onion/onion_requests.dart';
import '../services/onion/onion_transport_service.dart';
import 'local_turn_server.dart';
import 'upnp_port_mapper.dart';
import 'package:audio_session/audio_session.dart';

import 'dart:io' show Platform;
import 'package:flutter/services.dart';

class CallManager {
  static final CallManager _instance = CallManager._internal();
  factory CallManager() => _instance;
  CallManager._internal();

  String? _currentCallId;
  String? peerUsername;

  bool _isCleaningUp = false;
  
  late RTCVideoRenderer _localRenderer;
  late RTCVideoRenderer _remoteRenderer;
  RTCPeerConnection? _peerConnection; 
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  
  RTCRtpSender? _audioSenderForMute;
  MediaStreamTrack? _savedAudioTrackForMute;
  bool _appMuted = false;

  final ValueNotifier<bool> isSpeakerOn = ValueNotifier(false); 
  final ValueNotifier<bool> isInCall = ValueNotifier(false);
  final ValueNotifier<bool> isConnecting = ValueNotifier(false);

  /// Outgoing call the other side hasn't picked up yet ("Calling..."); once
  /// they answer it's [isConnecting] until media flows.
  final ValueNotifier<bool> isRinging = ValueNotifier(false);
  final ValueNotifier<bool> isRemoteVideoEnabled = ValueNotifier(false);
  final ValueNotifier<bool> isMuted = ValueNotifier(false);
  final ValueNotifier<bool> isVideoMuted = ValueNotifier(true);
  final ValueNotifier<String> relayMode = ValueNotifier('P2P');
  String? _incomingOfferSdp;
  final ValueNotifier<bool> isIncomingCall = ValueNotifier(false);
  final ValueNotifier<bool> isMinimized = ValueNotifier(false);
  String? _incomingCallId;
  String? incomingPeer;

  OverlayEntry? _callOverlayEntry;

  // ─── Call log ───────────────────────────────────────────────────────────
  // Every call leaves a CALLv1 record in the chat with the peer (see
  // RootScreen.addCallRecord). Local only: each side writes its own, like
  // Telegram's "Outgoing call · 2:14" / "Missed call".

  /// Peer of the call being tracked (outgoing, or incoming once accepted).
  String? _logPeer;
  bool _logOutgoing = false;
  DateTime? _logConnectedAt;

  /// Why it ended before connecting: 'declined' | 'busy' | 'no_answer'.
  String? _logReason;

  void _logRecord(String peer,
      {required bool outgoing, required String status, int duration = 0}) {
    rootScreenKey.currentState?.addCallRecord(peer,
        outgoing: outgoing, status: status, duration: duration);
  }

  /// Writes the record for the tracked call (if any) and stops tracking.
  void _flushCallLog() {
    final peer = _logPeer;
    _logPeer = null;
    if (peer == null) return;
    final at = _logConnectedAt;
    _logConnectedAt = null;
    final reason = _logReason;
    _logReason = null;
    if (at != null) {
      _logRecord(peer,
          outgoing: _logOutgoing,
          status: 'ended',
          duration: DateTime.now().difference(at).inSeconds);
    } else if (_logOutgoing) {
      _logRecord(peer, outgoing: true, status: reason ?? 'cancelled');
    } else {
      _logRecord(peer, outgoing: false, status: 'missed');
    }
  }

  // ─── Tor ("onion") calls ────────────────────────────────────────────────
  // Signaling goes over the onion chat channel instead of the server. Media
  // always goes through a LocalTurnServer on each side whose packets travel
  // over Tor (see local_turn_server.dart) -- never directly, so neither side
  // ever learns the other's IP. (There used to be an opt-in direct mode;
  // removed: one path, no choices to make.)

  /// Whether the current (or incoming) call is a Tor call.
  bool _onion = false;
  bool get isOnionCall => _onion;

  /// The device of the peer we're talking to (known once it answers / from
  /// the incoming offer). Before that, a new outgoing call rings all of the
  /// contact's connected devices: [_rungPubs].
  String? _onionPeerPub;
  List<String> _rungPubs = const [];

  LocalTurnServer? _turn;
  Timer? _ringTimeout;

  /// Signals are sent and handled strictly in order: sealing is async, so
  /// without this a candidate could overtake the answer it belongs to.
  Future<void> _sigOut = Future<void>.value();
  Future<void> _sigIn = Future<void>.value();

  /// Remote candidates that arrived before the remote description was set
  /// (or before the user accepted) -- applied once it is.
  final List<Map<String, dynamic>> _pendingRemoteCands = [];
  bool _remoteDescSet = false;

  /// Incoming Tor call: the caller's device.
  String? _incomingPub;
  bool _incomingIsOnion = false;
  bool get incomingIsOnion => _incomingIsOnion;

  /// Connection quality 0 (unknown) .. 4 (excellent), from WebRTC stats.
  final ValueNotifier<int> quality = ValueNotifier(0);

  Timer? _statsTimer;
  int? _lastLost;
  int? _lastReceived;

  AppLocalizations get _l =>
      lookupAppLocalizations(SettingsManager.appLocale.value);

  late WebSocketChannel? Function() _getWs;

  void init({required WebSocketChannel? Function() getWs}) {
    _getWs = getWs;
    _localRenderer = RTCVideoRenderer();
    _remoteRenderer = RTCVideoRenderer();
  }

  String _generateCallId() =>
      DateTime.now().microsecondsSinceEpoch.toString().padLeft(16, '0');

  Future<void> _createPeerConnection() async {
    Map<String, dynamic> config;
    if (_onion) {
      // Only ever the relay path over Tor (works through any NAT, reveals
      // nothing): with 'relay' policy WebRTC gathers no host/STUN
      // candidates at all, so no real IP is even known to the call.
      _turn?.stop();
      final turn = LocalTurnServer(onRelayOut: (from, to, data) {
        final pub = _onionPeerPub;
        if (pub == null) return;
        OnionTransportService.instance
            .sendCallMedia(pub, from.toString(), to.toString(), data);
      });
      await turn.start();
      _turn = turn;
      config = {
        'iceServers': [
          {
            'urls': turn.url,
            'username': turn.username,
            'credential': turn.password,
          },
        ],
        'iceTransportPolicy': 'relay',
      };
    } else {
      config = {
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'},
          {'urls': 'stun:stun.cloudflare.com:3478'},
        ],
        'iceTransportPolicy': 'all',
      };
    }

    _peerConnection = await createPeerConnection(config);

    _peerConnection!.onIceCandidate = (candidate) {
      if (candidate == null) return;
      _emitLocalCandidate(candidate);
      _maybeUpnp(candidate);
    };

    _peerConnection!.onTrack = (event) async {
      try {
        if (event.streams.isNotEmpty) {
          _remoteStream = event.streams[0];

          try {
            _remoteRenderer = await _recreateAndInitRenderer(_remoteRenderer);
          } catch (e) {
            debugPrint('[call] failed to ensure remote renderer: $e');
          }

          try {
            _remoteRenderer.srcObject = _remoteStream;
          } catch (e) {
            debugPrint(
              '[call] setting remoteRenderer.srcObject failed: $e — recreating renderer and retrying',
            );
            try {
              _remoteRenderer = await _recreateAndInitRenderer(null);
              _remoteRenderer.srcObject = _remoteStream;
            } catch (e2) {
              debugPrint('[call] retry set remote srcObject failed: $e2');
            }
          }

          isRemoteVideoEnabled.value = _remoteStream!
              .getVideoTracks()
              .isNotEmpty;
        }
      } catch (e, st) {
        debugPrint('[call] onTrack handler failed: $e\n$st');
      }
    };

    _peerConnection!.onConnectionState = (state) {
      debugPrint('[call] connection state: $state');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        isConnecting.value = false;
        _logConnectedAt ??= DateTime.now();
        isRinging.value = false;
        _startStats();
        // Audio has really started: re-assert the chosen route.
        unawaited(_applySpeakerRoute());
      } else if (_onion) {
        // No server fallback for Tor calls. A brief "disconnected" can
        // recover on its own; "failed" can't.
        if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
          rootScreenKey.currentState?.showSnack(_l.onionCallFailed, force: true);
          unawaited(hangup());
        }
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        isConnecting.value = false;
        _fallbackToRelay();
      }
    };

    _peerConnection!.onIceConnectionState = (state) {
      debugPrint('[call] ICE state: $state');
      if (_onion) return; // path is read from stats, see _pollStats
      if (state == RTCIceConnectionState.RTCIceConnectionStateConnected) {
        relayMode.value = 'P2P';
      } else if (state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
        debugPrint('[call] ICE failed → fallback to relay');
        _fallbackToRelay();
      }
    };
  }

  void _emitLocalCandidate(RTCIceCandidate candidate) {
    if (_onion) {
      _onLocalOnionCandidate(candidate);
      return;
    }
    _sendCallSignal({
      'type': 'ice_candidate',
      'to': peerUsername,
      'call_id': _currentCallId,
      'candidate': {
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
        'candidate': candidate.candidate,
      },
    });
  }

  // ─── UPnP (direct calls through a mobile carrier's NAT) ─────────────────

  final List<UpnpMapping> _upnpMappings = [];
  final Set<String> _upnpTried = {};

  /// For each local IPv4 UDP host candidate, asks the home router (if it
  /// speaks UPnP) to forward a public port to it, and offers that as an
  /// extra srflx candidate. See upnp_port_mapper.dart for why: without it
  /// a phone on mobile data and a PC at home almost never connect directly.
  /// Never on a Tor call (those never go direct).
  void _maybeUpnp(RTCIceCandidate c) {
    if (_onion) return;
    final parts = (c.candidate ?? '').split(' ');
    // candidate:<foundation> <component> udp <prio> <ip> <port> typ host ...
    if (parts.length < 8 ||
        parts[2].toLowerCase() != 'udp' ||
        parts[6] != 'typ' ||
        parts[7] != 'host') {
      return;
    }
    final ip = parts[4];
    final port = int.tryParse(parts[5]);
    if (port == null || !RegExp(r'^\d+\.\d+\.\d+\.\d+$').hasMatch(ip)) return;
    if (!_upnpTried.add('$ip:$port')) return;
    final pc = _peerConnection;
    unawaited(() async {
      final m = await UpnpPortMapper.instance.map(ip, port);
      if (m == null) return;
      if (_peerConnection == null || _peerConnection != pc) {
        await UpnpPortMapper.instance.unmap(m); // call ended meanwhile
        return;
      }
      _upnpMappings.add(m);
      final component = int.tryParse(parts[1]) ?? 1;
      final prio = (100 << 24) | (65535 << 8) | (256 - component);
      final extras = parts.sublist(8).join(' ');
      final s = 'candidate:upnp${m.externalPort} $component udp $prio '
          '${m.externalIp} ${m.externalPort} typ srflx raddr $ip rport $port'
          '${extras.isEmpty ? '' : ' $extras'}';
      _emitLocalCandidate(RTCIceCandidate(s, c.sdpMid, c.sdpMLineIndex));
    }());
  }

  void _releaseUpnp() {
    final maps = List<UpnpMapping>.from(_upnpMappings);
    _upnpMappings.clear();
    _upnpTried.clear();
    for (final m in maps) {
      unawaited(UpnpPortMapper.instance.unmap(m));
    }
  }

  // ─── Tor call helpers ───────────────────────────────────────────────────

  /// Only relay candidates go out (their address is a virtual one, see
  /// LocalTurnServer), with the "related address" blanked. Anything else
  /// would carry a real IP -- with the 'relay' policy WebRTC shouldn't even
  /// produce one, this is just the second lock on the door.
  void _onLocalOnionCandidate(RTCIceCandidate c) {
    final s = c.candidate ?? '';
    if (!s.contains(' typ relay')) return;
    _sendOnionCandidate(RTCIceCandidate(
        s.replaceAll(RegExp(r' raddr \S+ rport \d+'), ' raddr 0.0.0.0 rport 0'),
        c.sdpMid,
        c.sdpMLineIndex));
  }

  void _sendOnionCandidate(RTCIceCandidate c) {
    _sendCallSignal({
      'type': 'ice_candidate',
      'to': peerUsername,
      'call_id': _currentCallId,
      'candidate': {
        'sdpMid': c.sdpMid,
        'sdpMLineIndex': c.sdpMLineIndex,
        'candidate': c.candidate,
      },
    });
  }

  /// Starts a Tor call (always relayed over Tor, see above).
  Future<void> startOnionCall(String peer) async {
    if (isInCall.value) return;
    if (OnionRequests.isOutgoingPending(peer)) {
      // Not a contact on their side yet: they'd drop the call anyway.
      rootScreenKey.currentState
          ?.showSnack(_l.contactRequestPendingCall, force: true);
      return;
    }
    if (!OnionTransportService.instance.isLive(peer)) {
      rootScreenKey.currentState?.showSnack(_l.onionCallPeerOffline, force: true);
      return;
    }
    _onion = true;
    _onionPeerPub = null;
    relayMode.value = 'Tor';
    await startCall(peer);
    if (!_onion || !isInCall.value) return;
    // Nobody picked up.
    _ringTimeout?.cancel();
    _ringTimeout = Timer(const Duration(seconds: 45), () {
      if (_onion && isInCall.value && _onionPeerPub == null) {
        _logReason = 'no_answer';
        rootScreenKey.currentState?.showSnack(_l.onionCallNoAnswer, force: true);
        unawaited(hangup());
      }
    });
  }

  /// Entry point for call signals arriving over Tor (handled one at a time,
  /// in arrival order).
  Future<void> handleOnionSignal(
      String from, String fromPub, Map<String, dynamic> signal) {
    _sigIn = _sigIn
        .then((_) => _handleOnionSignal(from, fromPub, signal))
        .catchError((e) => debugPrint('[call] onion signal failed: $e'));
    return _sigIn;
  }

  Future<void> _flushRemoteCandidates() async {
    _remoteDescSet = true;
    final pending = List<Map<String, dynamic>>.from(_pendingRemoteCands);
    _pendingRemoteCands.clear();
    for (final s in pending) {
      // Only from the device we actually ended up talking to.
      if (s['_pub'] == _onionPeerPub) await _addRemoteCandidate(s);
    }
  }

  Future<void> _addRemoteCandidate(Map<String, dynamic> signal) async {
    final cand = signal['candidate'];
    final pc = _peerConnection;
    if (cand is! Map || pc == null) return;
    try {
      await pc.addCandidate(RTCIceCandidate(
          cand['candidate'], cand['sdpMid'], cand['sdpMLineIndex']));
    } catch (e) {
      debugPrint('[call] addCandidate failed: $e');
    }
  }

  Future<void> _handleOnionSignal(
      String from, String fromPub, Map<String, dynamic> signal) async {
    signal['from'] = from;
    final type = signal['type'] as String?;
    final callId = signal['call_id'] as String?;
    switch (type) {
      case 'call_offer':
        final ours = _onion && isInCall.value && peerUsername == from;
        if (ours && callId == _currentCallId) {
          onCallOffer(signal); // renegotiation (e.g. video turned on)
          return;
        }
        if (isInCall.value || isIncomingCall.value) {
          // Both called each other at the same moment: keep the call placed
          // by the alphabetically smaller username, drop the other.
          final me = rootScreenKey.currentState?.currentUsername ?? '';
          final glare = ours && _onionPeerPub == null;
          if (glare && me.compareTo(from) > 0) {
            await _silentlyDropOutgoing();
          } else {
            unawaited(OnionTransportService.instance.sendCallSignal(
                from, {'type': 'call_hangup', 'call_id': callId, 'reason': 'busy'},
                toPub: fromPub));
            return;
          }
        }
        _incomingIsOnion = true;
        _incomingPub = fromPub;
        onCallOffer(signal);
        return;
      case 'call_answer':
        if (!_onion || callId != _currentCallId) return;
        if (_onionPeerPub == null) {
          // First device to answer wins; stop ringing the others.
          _onionPeerPub = fromPub;
          isRinging.value = false;
          // Extra Tor circuits for the audio (we're the caller: we open).
          OnionTransportService.instance
              .startCallPaths(fromPub, opener: true);
          _ringTimeout?.cancel();
          for (final p in _rungPubs.where((p) => p != fromPub)) {
            unawaited(OnionTransportService.instance.sendCallSignal(from,
                {'type': 'call_hangup', 'call_id': callId, 'reason': 'answered_elsewhere'},
                toPub: p));
          }
        } else if (_onionPeerPub != fromPub) {
          return;
        }
        final sdp = signal['sdp'];
        if (sdp is String) {
          await _setRemoteAnswer(sdp);
          await _flushRemoteCandidates();
        }
        return;
      case 'ice_candidate':
        final forActive = _onion &&
            callId == _currentCallId &&
            (fromPub == _onionPeerPub || _onionPeerPub == null);
        final forRinging = _incomingIsOnion &&
            callId == _incomingCallId &&
            fromPub == _incomingPub;
        if (!forActive && !forRinging) return;
        if (forActive && _remoteDescSet && fromPub == _onionPeerPub) {
          await _addRemoteCandidate(signal);
        } else {
          _pendingRemoteCands.add({...signal, '_pub': fromPub});
        }
        return;
      case 'call_hangup':
        final activeHere = _onion &&
            callId == _currentCallId &&
            (_onionPeerPub == null || _onionPeerPub == fromPub);
        final ringingHere = _incomingIsOnion && callId == _incomingCallId;
        if (!activeHere && !ringingHere) return;
        if (activeHere && signal['reason'] == 'busy' && _onionPeerPub == null) {
          // One of their devices is busy; others may still answer.
          _rungPubs = _rungPubs.where((p) => p != fromPub).toList();
          if (_rungPubs.isNotEmpty) return;
        }
        onHangup(signal);
        return;
    }
  }

  /// Relayed call media from the other side (see LocalTurnServer).
  void onOnionMedia(String fromPub, String from, String to, Uint8List data) {
    if (!_onion || fromPub != _onionPeerPub) return;
    final f = TurnAddr.parse(from), t = TurnAddr.parse(to);
    if (f == null || t == null) return;
    _turn?.deliverFromTunnel(f, t, data);
  }

  Future<void> _silentlyDropOutgoing() async {
    for (final p in _rungPubs) {
      final peer = peerUsername;
      if (peer == null) break;
      unawaited(OnionTransportService.instance.sendCallSignal(peer,
          {'type': 'call_hangup', 'call_id': _currentCallId, 'reason': 'glare'},
          toPub: p));
    }
    _logPeer = null; // replaced by their call to us, not a call of its own
    await cleanup();
  }

  // ─── quality ────────────────────────────────────────────────────────────

  void _startStats() {
    _statsTimer?.cancel();
    _lastLost = null;
    _lastReceived = null;
    _statsTimer =
        Timer.periodic(const Duration(seconds: 2), (_) => unawaited(_pollStats()));
    unawaited(_pollStats());
  }

  Future<void> _pollStats() async {
    final pc = _peerConnection;
    if (pc == null) return;
    List<StatsReport> reports;
    try {
      reports = await pc.getStats();
    } catch (_) {
      return;
    }
    double? rtt;
    String? localCandId;
    int? lost, received;
    final candTypes = <String, String>{};
    for (final r in reports) {
      final v = r.values;
      switch (r.type) {
        case 'candidate-pair':
          if (v['state'] == 'succeeded' &&
              (v['nominated'] == true || v['selected'] == true)) {
            final x = v['currentRoundTripTime'];
            if (x is num) rtt = x.toDouble();
            localCandId = v['localCandidateId']?.toString();
          }
          break;
        case 'local-candidate':
          candTypes[r.id] = v['candidateType']?.toString() ?? '';
          break;
        case 'inbound-rtp':
          if (v['kind'] == 'audio' || v['mediaType'] == 'audio') {
            final l = v['packetsLost'], p = v['packetsReceived'];
            if (l is num) lost = l.toInt();
            if (p is num) received = p.toInt();
          }
          break;
      }
    }
    final viaRelay = localCandId != null && candTypes[localCandId] == 'relay';
    if (_onion && localCandId != null) {
      relayMode.value = viaRelay ? 'Tor' : 'P2P';
    }

    double loss = 0;
    if (lost != null && received != null &&
        _lastLost != null && _lastReceived != null) {
      final dl = lost - _lastLost!, dr = received - _lastReceived!;
      if (dl + dr > 0) loss = (dl / (dl + dr)).clamp(0.0, 1.0);
    }
    _lastLost = lost;
    _lastReceived = received;

    int q;
    if (rtt == null) {
      q = 0;
    } else if (rtt < 0.25 && loss < 0.02) {
      q = 4;
    } else if (rtt < 0.5 && loss < 0.05) {
      q = 3;
    } else if (rtt < 1.0 && loss < 0.10) {
      q = 2;
    } else {
      q = 1;
    }
    quality.value = q;

  }

  void _showCallOverlay(BuildContext context) {
    if (_callOverlayEntry != null) return;

    _callOverlayEntry = OverlayEntry(builder: (context) => CallOverlay());

    Overlay.of(context).insert(_callOverlayEntry!);
  }

  void _hideCallOverlay() {
    _callOverlayEntry?.remove();
    _callOverlayEntry = null;
  }

  void minimizeCall() {
    isMinimized.value = true;
  }

  void restoreCall() {
    isMinimized.value = false;
  }

  bool _speakerBusy = false;

  /// Pushes [isSpeakerOn] to the audio hardware (phones only).
  ///
  /// This has to be done explicitly, not just on a tap: flutter_webrtc's
  /// Android audio switch prefers the loudspeaker over the earpiece by
  /// default, so a call that starts with the button showing "off" was in
  /// fact playing through the loudspeaker -- the first tap then "turned on"
  /// what was already on. It is applied when the microphone stream is
  /// created (the audio switch is live from then on) and again once the call
  /// connects, because the route can be reset when audio actually starts.
  Future<void> _applySpeakerRoute() async {
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) return;
    try {
      await Helper.setSpeakerphoneOn(isSpeakerOn.value);
    } catch (e) {
      debugPrint('[call] applying speaker route failed: $e');
    }
  }

  Future<void> toggleSpeaker() async {
    // Taps arriving while the previous switch is still in flight would
    // each compute "the opposite" of a stale value.
    if (_speakerBusy) return;
    _speakerBusy = true;
    try {
      final willOn = !isSpeakerOn.value;
      await Helper.setSpeakerphoneOn(willOn);
      isSpeakerOn.value = willOn;
      debugPrint('[call] speaker toggled: $willOn');
    } catch (e) {
      debugPrint('[call] toggleSpeaker failed: $e');
    } finally {
      _speakerBusy = false;
    }
  }

  Future<void> _addLocalStream() async {
    // Over Tor the round trip can be a second or more: without echo
    // cancellation you'd hear yourself back a second later on speaker.
    final ec = _onion;
    final mediaConstraints = <String, dynamic>{
      'audio': {
        'echoCancellation': ec,
        'noiseSuppression': ec,
        'autoGainControl': true,
        'googEchoCancellation': ec,
        'googNoiseSuppression': ec,
        'sampleRate': 48000,
        'sampleSize': 16,
        'channelCount': 1,
      },
      // Voice only: calls have no video (product decision).
      'video': false,
    };

    _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);

    // Every call starts on the earpiece, with the button agreeing with it.
    isSpeakerOn.value = false;
    await _applySpeakerRoute();

    try {
      _localRenderer = await _recreateAndInitRenderer(_localRenderer);
    } catch (e) {
      debugPrint('[call] failed to ensure local renderer: $e');
    }

    try {
      _localRenderer.srcObject = _localStream;
    } catch (e) {
      debugPrint(
        '[call] setting localRenderer.srcObject failed: $e — recreating renderer and retrying',
      );
      try {
        _localRenderer = await _recreateAndInitRenderer(null);
        _localRenderer.srcObject = _localStream;
      } catch (e2) {
        debugPrint('[call] retry set srcObject failed: $e2');
      }
    }

    isVideoMuted.value = true;

    _localStream!.getTracks().forEach((track) {
      try {
        _peerConnection!.addTrack(track, _localStream!);
      } catch (e) {
        debugPrint('[call] addTrack error: $e');
      }
    });
  }

  Future<void> _createOffer() async {
    await _addLocalStream();
    final offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);
    _sendCallSignal({
      'type': 'call_offer',
      'to': peerUsername,
      'call_id': _currentCallId,
      'sdp': offer.sdp,
    });
  }

  Future<void> _setRemoteAnswer(String sdp) async {
    final answer = RTCSessionDescription(_tuneRemoteSdp(sdp), 'answer');
    await _peerConnection!.setRemoteDescription(answer);
  }

  /// Tor calls only: tunes how *we* encode audio for the peer. The Opus
  /// parameters in the remote description are what our sender obeys, so
  /// this is where they go. Over Tor every packet costs at least one 512-
  /// byte Tor cell no matter how small it is, so the packet rate matters
  /// more than the bitrate:
  ///  - ptime 60 cuts packets/s to a third of the default 20ms (+40ms of
  ///    framing delay, nothing next to Tor's own latency), and every packet
  ///    is sent over several circuits (see OnionTransportService's call
  ///    paths);
  ///  - DTX sends almost nothing while you're silent (half of any call);
  ///  - 32 kbps is plenty for voice and leaves Tor headroom.
  String _tuneRemoteSdp(String sdp) {
    if (!_onion) return sdp;
    final opus = RegExp(r'a=rtpmap:(\d+) opus/48000', caseSensitive: false)
        .firstMatch(sdp);
    if (opus == null) return sdp;
    final pt = opus.group(1)!;
    final nl = sdp.contains('\r\n') ? '\r\n' : '\n';
    final lines = sdp.split(nl);
    final out = <String>[];
    var inAudio = false;
    var hasPtime = false;
    for (final line in lines) {
      if (line.startsWith('m=')) {
        if (inAudio && !hasPtime) out.add('a=ptime:60');
        inAudio = line.startsWith('m=audio');
        hasPtime = false;
      }
      if (inAudio && line.startsWith('a=ptime:')) {
        hasPtime = true;
        out.add('a=ptime:60');
        continue;
      }
      if (inAudio && line.startsWith('a=fmtp:$pt ')) {
        var l = line;
        if (!l.contains('usedtx=')) l += ';usedtx=1';
        if (!l.contains('maxaveragebitrate=')) l += ';maxaveragebitrate=32000';
        out.add(l);
        continue;
      }
      out.add(line);
    }
    // Audio was the last m-section: ptime goes before the trailing ''.
    if (inAudio && !hasPtime) {
      final at = out.isNotEmpty && out.last.isEmpty ? out.length - 1 : out.length;
      out.insert(at, 'a=ptime:60');
    }
    return out.join(nl);
  }

  void _sendCallSignal(Map<String, dynamic> payload) {
    if (_onion || _incomingIsOnion) {
      _sendOnionSignal(payload);
      return;
    }
    final ws = _getWs();
    ws?.sink.add(jsonEncode(payload));
  }

  void _sendOnionSignal(Map<String, dynamic> payload) {
    final to = (payload.remove('to') as String?) ?? peerUsername ?? incomingPeer;
    if (to == null) return;
    final type = payload['type'];
    final toPub = _onionPeerPub ?? _incomingPub;
    final svc = OnionTransportService.instance;
    void queue(Future<void> Function() send) {
      _sigOut = _sigOut
          .then((_) => send())
          .catchError((e) => debugPrint('[call] onion send failed: $e'));
    }

    if (type == 'call_offer' && toPub == null) {
      // A new outgoing call: ring every connected device of theirs.
      // Older builds still read this; false = never go direct with us.
      payload['allow_direct'] = false;
      final callId = payload['call_id'];
      queue(() async {
        final pubs = await svc.sendCallSignal(to, payload);
        _rungPubs = pubs;
        if (pubs.isEmpty && isInCall.value && _currentCallId == callId) {
          rootScreenKey.currentState?.showSnack(_l.onionCallPeerOffline, force: true);
          await cleanup();
        }
      });
      return;
    }
    if (type == 'call_answer') payload['allow_direct'] = false;
    if (toPub == null) {
      // e.g. hanging up before anyone answered: tell every rung device.
      final pubs = List<String>.from(_rungPubs);
      queue(() async {
        for (final p in pubs) {
          await svc.sendCallSignal(to, payload, toPub: p);
        }
      });
      return;
    }
    queue(() => svc.sendCallSignal(to, payload, toPub: toPub));
  }

  void _fallbackToRelay() async {
    relayMode.value = 'Relay'; 
    debugPrint('[call] using relay fallback');

    try {
      final localDesc = await _peerConnection?.getLocalDescription();
      if (localDesc?.sdp == null) {
        debugPrint('[call] no local SDP (getLocalDescription returned null)');
        return;
      }

      final plain = utf8.encode(localDesc!.sdp!);
      final encrypted = await rootScreenKey.currentState!.encryptMediaForPeer(
        peerUsername!,
        plain,
        kind: 'call',
      );

      final ws = _getWs();
      if (ws != null) {
        
        ws.sink.add(
          jsonEncode({
            'type': 'call_audio_start',
            'to': peerUsername,
            'call_id': _currentCallId,
          }),
        );

        ws.sink.add(
          jsonEncode({
            'type': 'call_audio',
            'to': peerUsername,
            'call_id': _currentCallId,
            'data': base64Encode(encrypted),
          }),
        );
      }
    } catch (e, st) {
      debugPrint('[call] fallback error: $e\n$st');
    }
  }

  Future<void> startCall(String peer) async {
    isMinimized.value = false;

    if (isInCall.value) return;

    if (kIsWeb || !Platform.isMacOS) {
      final micStatus = await Permission.microphone.request();
      if (micStatus.isPermanentlyDenied) {
        rootScreenKey.currentState?.showSnack(
          'Microphone permission is required. Go to Settings → Permissions.',
        );
        await openAppSettings();
        return;
      }
      if (!micStatus.isGranted) {
        rootScreenKey.currentState?.showSnack(
          'Microphone access required for calls',
        );
        return;
      }
    }

    peerUsername = peer;
    _currentCallId = _generateCallId();
    isInCall.value = true;
    isConnecting.value = true;
    isRinging.value = true;
    _logPeer = peer;
    _logOutgoing = true;
    _logConnectedAt = null;
    _logReason = null;

    try {
      _localRenderer = await _recreateAndInitRenderer(_localRenderer);
    } catch (e) {
      debugPrint('[call] localRenderer ensure failed: $e');
    }
    try {
      _remoteRenderer = await _recreateAndInitRenderer(_remoteRenderer);
    } catch (e) {
      debugPrint('[call] remoteRenderer ensure failed: $e');
    }

    await _createPeerConnection();
    await _createOffer();
  }

  Future<void> acceptCall() async {
    isMinimized.value = false;

    debugPrint('[call]  acceptCall() called');
    debugPrint('  - isIncomingCall: ${isIncomingCall.value}');
    debugPrint('  - incomingPeer: $incomingPeer');
    debugPrint('  - _incomingCallId: $_incomingCallId');
    debugPrint(
      '  - _incomingOfferSdp length: ${_incomingOfferSdp?.length ?? 0}',
    );

    if (!isIncomingCall.value ||
        incomingPeer == null ||
        _incomingCallId == null) {
      debugPrint('[call]  accept: missing incoming data - cannot proceed');
      return;
    }

    if (kIsWeb || !Platform.isMacOS) {
      final micStatus = await Permission.microphone.request();
      final camStatus = await Permission.camera.request();

      if (micStatus.isPermanentlyDenied || camStatus.isPermanentlyDenied) {
        debugPrint('[call]  permissions permanently denied');
        rootScreenKey.currentState?.showSnack(
          'Microphone and camera permissions are required. Go to Settings → Permissions.',
        );
        await openAppSettings();
        rejectCall();
        return;
      }

      if (!micStatus.isGranted || !camStatus.isGranted) {
        debugPrint('[call]  permissions denied');
        rootScreenKey.currentState?.showSnack(
          'Microphone and camera access required for calls',
        );
        rejectCall();
        return;
      }
    }

    if (_incomingOfferSdp == null || _incomingOfferSdp!.trim().isEmpty) {
      debugPrint(
        '[call] SDP is empty — sending request to peer for offer (call_offer_request)',
      );
      _sendCallSignal({
        'type': 'call_offer_request',
        'to': incomingPeer,
        'call_id': _incomingCallId,
      });

      final got = await _waitForOffer(timeout: const Duration(seconds: 5));
      if (!got) {
        debugPrint(
          '[call]  did not receive SDP after request — falling back to relay or aborting',
        );
        _fallbackToRelay();
        return;
      }
      debugPrint(
        '[call] SDP received after request (len=${_incomingOfferSdp!.length})',
      );
    }

    peerUsername = incomingPeer;
    _currentCallId = _incomingCallId;
    if (_incomingIsOnion) {
      _onion = true;
      _onionPeerPub = _incomingPub;
      if (_incomingPub != null) {
        OnionTransportService.instance
            .startCallPaths(_incomingPub!, opener: false);
      }
      relayMode.value = 'Tor';
    }
    isInCall.value = true;
    isConnecting.value = true;

    try {
      await _localRenderer.initialize();
      await _remoteRenderer.initialize();
      await _createPeerConnection();
      await _addLocalStream();

      final offer =
          RTCSessionDescription(_tuneRemoteSdp(_incomingOfferSdp!), 'offer');
      await _peerConnection!.setRemoteDescription(offer);
      // Caller's candidates that arrived while it was ringing.
      if (_onion) await _flushRemoteCandidates();

      final answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);

      _sendCallSignal({
        'type': 'call_answer',
        'to': peerUsername,
        'call_id': _currentCallId,
        'sdp': answer.sdp,
      });

      debugPrint('[call]  answer sent successfully');
      _logPeer = peerUsername;
      _logOutgoing = false;
      _logConnectedAt = null;
      _logReason = null;
      isIncomingCall.value = false;
      _cleanupIncomingData();
    } catch (e, st) {
      debugPrint('[call]  accept failed: $e\n$st');
      cleanup();
      isIncomingCall.value = true;
    }
  }

  void rejectCall() {
    final peer = incomingPeer;
    if (peer != null && isIncomingCall.value) {
      _logRecord(peer, outgoing: false, status: 'declined');
    }
    if (incomingPeer != null && _incomingCallId != null) {
      _sendCallSignal({
        'type': 'call_hangup',
        'to': incomingPeer,
        'call_id': _incomingCallId,
        'reason': 'rejected',
      });
    }
    _pendingRemoteCands.clear();
    _cleanupIncoming();
  }

  void _cleanupIncoming() {
    isIncomingCall.value = false;
    _cleanupIncomingData();
  }

  void _cleanupIncomingData() {
    incomingPeer = null;
    _incomingCallId = null;
    _incomingOfferSdp = null;
    _incomingIsOnion = false;
    _incomingPub = null;
    debugPrint('[call] incoming data cleaned up');
  }

  Future<RTCVideoRenderer> _recreateAndInitRenderer(
    RTCVideoRenderer? current,
  ) async {
    
    try {
      if (current == null) {
        final r = RTCVideoRenderer();
        await r.initialize();
        return r;
      }
      
      await current.initialize();
      return current;
    } catch (e) {
      debugPrint(
        '[call] renderer initialize failed or disposed: $e — recreating renderer',
      );
      try {
        final r = RTCVideoRenderer();
        await r.initialize();
        return r;
      } catch (e2) {
        debugPrint('[call] failed to recreate renderer: $e2');
        rethrow;
      }
    }
  }

  Future<void> hangup() async {
    try {
      if (peerUsername != null && _currentCallId != null) {
        _sendCallSignal({
          'type': 'call_hangup',
          'to': peerUsername!,
          'call_id': _currentCallId!,
          'reason': 'hangup',
        });
      } else {
        debugPrint(
          '[call] hangup called but no peer/call_id present — local cleanup only',
        );
      }
    } catch (e) {
      debugPrint('[call] error sending hangup signal: $e');
    } finally {
      await cleanup();
    }
  }

  Future<void> toggleMute() async {
    final tracks = _localStream?.getAudioTracks();
    final currentTrack = (tracks != null && tracks.isNotEmpty)
        ? tracks[0]
        : null;

    if (_peerConnection == null || currentTrack == null) {
      if (currentTrack != null) {
        currentTrack.enabled = !currentTrack.enabled;
        isMuted.value = !currentTrack.enabled;
      }
      return;
    }

    try {
      final senders = await _peerConnection!.getSenders();
      final audioSenders = senders.where((s) => s.track?.kind == 'audio');
      _audioSenderForMute = audioSenders.isNotEmpty ? audioSenders.first : null;
    } catch (e) {
      debugPrint('[call] failed to getSenders: $e');
      _audioSenderForMute = null;
    }

    if (!_appMuted) {
      _savedAudioTrackForMute = currentTrack;
      try {
        if (_audioSenderForMute != null) {
          await _audioSenderForMute!.replaceTrack(null);
          isMuted.value = true;
          _appMuted = true;
          debugPrint('[call] app-mute: replaced audio track with null');
        } else {
          currentTrack.enabled = false;
          isMuted.value = true;
          _appMuted = true;
          debugPrint('[call] app-mute fallback: disabled track.enabled');
        }
      } catch (e) {
        debugPrint(
          '[call] replaceTrack(null) failed: $e — falling back to track.enabled=false',
        );
        currentTrack.enabled = false;
        isMuted.value = true;
        _appMuted = true;
      }
      return;
    }

    try {
      if (_audioSenderForMute != null) {
        await _audioSenderForMute!.replaceTrack(_savedAudioTrackForMute);
        isMuted.value = !(_savedAudioTrackForMute?.enabled ?? false);
        _appMuted = false;
        _savedAudioTrackForMute = null;
        debugPrint('[call] app-unmute: restored saved audio track');
      } else {
        if (_savedAudioTrackForMute != null) {
          _savedAudioTrackForMute!.enabled = true;
          isMuted.value = false;
        }
        _appMuted = false;
        _savedAudioTrackForMute = null;
        debugPrint('[call] app-unmute fallback: re-enabled saved track');
      }
    } catch (e) {
      debugPrint(
        '[call] replaceTrack(restore) failed: $e — leaving as fallback',
      );
      try {
        if (_savedAudioTrackForMute != null) {
          _savedAudioTrackForMute!.enabled = true;
          isMuted.value = false;
        }
      } catch (e) { debugPrint('[err] $e'); }
      _appMuted = false;
      _savedAudioTrackForMute = null;
    }
  }

  String _remoteNameSafe() {
    try {
      
      final dyn = callManager as dynamic;
      final name = dyn.remoteDisplayName;
      if (name is String && name.isNotEmpty) return name;
    } catch (e) {
      debugPrint('[err] $e');
    }
    return 'Unknown';
  }

  Future<bool> _waitForOffer({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      if (_incomingOfferSdp != null && _incomingOfferSdp!.trim().isNotEmpty) {
        return true;
      }
      await Future.delayed(const Duration(milliseconds: 100));
    }
    return false;
  }

  String? _extractSdpFromSignal(Map<String, dynamic> signal) {
    
    var sdp = (signal['sdp'] as String?) ?? (signal['offer'] as String?);

    if (sdp != null && sdp.trim().isNotEmpty) {
      final trimmed = sdp.trim();
      
      final maybeBase64 = RegExp(r'^[A-Za-z0-9+/=\s]+$');
      if (trimmed.length > 200 && maybeBase64.hasMatch(trimmed)) {
        try {
          final decoded = utf8.decode(base64Decode(trimmed));
          if (decoded.contains('v=0') && decoded.contains('o=')) {
            return decoded;
          }
        } catch (e) {
      debugPrint('[err] $e');
    }
      }
      return trimmed;
    }

    return null;
  }

  void onCallOffer(Map<String, dynamic> signal) async {
    
    final incomingCallId = signal['call_id'] as String?;

    if (isInCall.value && _currentCallId == incomingCallId) {
      final sdp = _extractSdpFromSignal(signal);
      if (sdp != null && _peerConnection != null) {
        try {
          final offer = RTCSessionDescription(_tuneRemoteSdp(sdp), 'offer');
          await _peerConnection!.setRemoteDescription(offer);
          final answer = await _peerConnection!.createAnswer();
          await _peerConnection!.setLocalDescription(answer);
          _sendCallSignal({
            'type': 'call_answer',
            'to': signal['from'] as String?,
            'call_id': incomingCallId,
            'sdp': answer.sdp,
          });
          debugPrint('[call] renegotiation answer sent');
        } catch (e, st) {
          debugPrint('[call] renegotiation error: $e\n$st');
        }
        return;
      }
    }

    incomingPeer = signal['from'] as String?;
    _incomingCallId = signal['call_id'] as String?;
    
    dynamic sdpCandidate = signal['sdp'] ?? signal['data'] ?? signal['content'];

    String sdpStr = '';
    if (sdpCandidate is String) {
      sdpStr = sdpCandidate;
    } else if (sdpCandidate != null) {
      
      try {
        sdpStr = sdpCandidate.toString();
      } catch (e) {
        sdpStr = '';
      }
    }

    debugPrint('[call]  incoming offer saved:');
    debugPrint('  - from: $incomingPeer');
    debugPrint('  - call_id: $_incomingCallId');
    debugPrint('  - raw sdp length: ${sdpStr.length}');

    bool looksLikeSdp(String s) {
      return s.contains('v=0') &&
          s.contains('o=') &&
          s.contains('s=') &&
          s.contains('t=');
    }

    if (sdpStr.isEmpty) {
      debugPrint(
        '[call] SDP is empty — sending request to peer for offer (call_offer_request)',
      );
      if (incomingPeer != null && _incomingCallId != null) {
        _sendCallSignal({
          'type': 'call_offer_request',
          'to': incomingPeer,
          'call_id': _incomingCallId,
        });
      }
      isIncomingCall.value = true;
      isInCall.value = false;
      isConnecting.value = false;
      return;
    }

    String finalSdp = sdpStr;
    bool ok = looksLikeSdp(finalSdp);

    if (!ok) {
      try {
        final bytes = base64Decode(finalSdp);
        final decoded = utf8.decode(bytes);
        if (looksLikeSdp(decoded)) {
          finalSdp = decoded;
          ok = true;
          debugPrint('[call] decoded SDP from base64 (looks valid)');
        } else {
          debugPrint('[call] base64 decoded but not SDP');
        }
      } catch (e) {
        debugPrint('[call] base64 decode failed: $e');
      }
    }

    if (!ok) {
      debugPrint(
        '[call] SDP is invalid or wrapped — requesting plain offer from peer (call_offer_request)',
      );
      if (incomingPeer != null && _incomingCallId != null) {
        _sendCallSignal({
          'type': 'call_offer_request',
          'to': incomingPeer,
          'call_id': _incomingCallId,
        });
      }
      
      isIncomingCall.value = true;
      isInCall.value = false;
      isConnecting.value = false;
      return;
    }

    _incomingOfferSdp = finalSdp;
    isIncomingCall.value = true;
    isInCall.value = false;
    isConnecting.value = false;

    debugPrint(
      '  - sdp length after normalize: ${_incomingOfferSdp?.length ?? 0}',
    );
  }

  void onCallAnswer(Map<String, dynamic> signal) async {
    final sdp = signal['sdp'];
    isRinging.value = false;
    if (sdp != null) {
      await _setRemoteAnswer(sdp);
      debugPrint('[call] answer received and applied');
    }
  }

  void onIceCandidate(Map<String, dynamic> signal) async {
    final cand = signal['candidate'];
    if (cand != null && _peerConnection != null) {
      final candidate = RTCIceCandidate(
        cand['candidate'],
        cand['sdpMid'],
        cand['sdpMLineIndex'],
      );
      await _peerConnection!.addCandidate(candidate);
      debugPrint('[call] ICE candidate added');
    }
  }

  void onHangup(Map<String, dynamic> signal) {
    debugPrint('[call] hangup received');
    final ringingFrom = incomingPeer;
    if (isIncomingCall.value && !isInCall.value && ringingFrom != null) {
      // They gave up before we answered (another of our devices picking up
      // isn't a missed call).
      if (signal['reason'] != 'answered_elsewhere') {
        _logRecord(ringingFrom, outgoing: false, status: 'missed');
      }
    } else if (_logOutgoing && _logConnectedAt == null) {
      final reason = signal['reason'];
      if (reason == 'rejected') {
        _logReason = 'declined';
      } else if (reason == 'busy') {
        _logReason = 'busy';
      }
    }
    isIncomingCall.value = false;
    _cleanupIncomingData();
    cleanup();
  }

  Future<void> _closePeerConnection() async {
    if (_peerConnection == null) return;

    try {
      
      try {
        final senders = await _peerConnection!.getSenders();
        if (senders != null) {
          for (final s in senders) {
            try {
              
              await _peerConnection!.removeTrack(s);
            } catch (e) {
              debugPrint('[call] removeTrack error: $e');
            }
          }
        }
      } catch (e) {
        debugPrint('[call] getSenders/removeTrack failed: $e');
      }

      try {
        await _peerConnection!.close();
        debugPrint('[call] peerConnection closed');
      } catch (e) {
        debugPrint('[call] peerConnection close error: $e');
      }
    } catch (e, st) {
      debugPrint('[call] _closePeerConnection unexpected: $e\n$st');
    } finally {
      
      _peerConnection = null;
    }
  }

  Future<void> cleanup() async {
    
    if (_isCleaningUp) {
      debugPrint(
        '[call] cleanup already in progress — skipping duplicate call',
      );
      return;
    }
    _isCleaningUp = true;
    debugPrint('[call] starting cleanup');

    try {
      _flushCallLog();
    } catch (e) {
      debugPrint('[call] call log failed: $e');
    }

    try {
      isMinimized.value = false;
    } catch (e) { debugPrint('[err] $e'); }

    try {
      
      try {
        final audioTrack = _localStream?.getAudioTracks().isNotEmpty == true
            ? _localStream!.getAudioTracks().first
            : null;

        try {
          await Helper.setSpeakerphoneOn(false);
        } catch (e) {
          debugPrint('[call] Helper.setSpeakerphoneOn() failed: $e');
        }
        // The button must not keep showing "on" for the next call.
        isSpeakerOn.value = false;

        if (audioTrack != null) {
          try {
            
            await Helper.setMicrophoneMute(false, audioTrack);
          } catch (e) {
            debugPrint('[call] Helper.setMicrophoneMute() failed: $e');
          }
        }
      } catch (e) {
        debugPrint('[call] audio reset attempts failed: $e');
      }

      await _closePeerConnection();

      try {
        if (_localStream != null) {
          final localTracks = List<MediaStreamTrack>.from(
            _localStream!.getTracks(),
          );
          for (final t in localTracks) {
            try {
              t.stop();
            } catch (e) {
              debugPrint('[call] error stopping local track: $e');
            }
            try {
              
              t.dispose();
            } catch (e) {
              debugPrint('[call] error disposing local track: $e');
            }
          }
        }
      } catch (e, st) {
        debugPrint('[call] error iterating local tracks: $e\n$st');
      }

      try {
        if (_remoteStream != null) {
          final remoteTracks = List<MediaStreamTrack>.from(
            _remoteStream!.getTracks(),
          );
          for (final t in remoteTracks) {
            try {
              t.stop();
            } catch (e) {
              debugPrint('[call] error stopping remote track: $e');
            }
            try {
              t.dispose();
            } catch (e) {
              debugPrint('[call] error disposing remote track: $e');
            }
          }
        }
      } catch (e, st) {
        debugPrint('[call] error iterating remote tracks: $e\n$st');
      }

      try {
        if (_localStream != null) {
          try {
            await _localStream!.dispose().catchError((e) {
              debugPrint('[call] _localStream.dispose() failed: $e');
            });
            debugPrint('[call] _localStream disposed');
          } catch (e) {
            debugPrint('[call] exception disposing localStream: $e');
          }
        }
      } catch (e) {
        debugPrint('[call] error disposing localStream outer: $e');
      }

      try {
        if (_remoteStream != null) {
          try {
            await _remoteStream!.dispose().catchError((e) {
              debugPrint('[call] _remoteStream.dispose() failed: $e');
            });
            debugPrint('[call] _remoteStream disposed');
          } catch (e) {
            debugPrint('[call] exception disposing remoteStream: $e');
          }
        }
      } catch (e) {
        debugPrint('[call] error disposing remoteStream outer: $e');
      }

      try {
        _localRenderer.srcObject = null;
      } catch (e) {
        debugPrint('[call] error clearing localRenderer.srcObject: $e');
      }
      try {
        _remoteRenderer.srcObject = null;
      } catch (e) {
        debugPrint('[call] error clearing remoteRenderer.srcObject: $e');
      }

      try {
        debugPrint('[call] localRenderer disposed');
      } catch (e) {
        debugPrint('[call] error disposing localRenderer: $e');
      }
      try {
        relayMode.value = 'P2P';
      } catch (e) { debugPrint('[err] $e'); }
      try {
        
        try {
          _localRenderer.srcObject = null;
        } catch (e) {
          debugPrint('[call] error clearing localRenderer.srcObject: $e');
        }
        try {
          _remoteRenderer.srcObject = null;
        } catch (e) {
          debugPrint('[call] error clearing remoteRenderer.srcObject: $e');
        }

        debugPrint('[call] remoteRenderer disposed');
      } catch (e) {
        debugPrint('[call] error disposing remoteRenderer: $e');
      }

      _currentCallId = null;
      peerUsername = null;

      // Tor call state.
      _statsTimer?.cancel();
      _statsTimer = null;
      _ringTimeout?.cancel();
      _ringTimeout = null;
      _turn?.stop();
      _turn = null;
      _releaseUpnp();
      final pathsPub = _onionPeerPub;
      if (pathsPub != null) {
        OnionTransportService.instance.stopCallPaths(pathsPub);
      }
      _onion = false;
      _onionPeerPub = null;
      _rungPubs = const [];
      _pendingRemoteCands.clear();
      _remoteDescSet = false;
      quality.value = 0;

      _localStream = null;
      _remoteStream = null;
      
      try {
        isInCall.value = false;
      } catch (e) { debugPrint('[err] $e'); }
      try {
        isConnecting.value = false;
        isRinging.value = false;
      } catch (e) { debugPrint('[err] $e'); }
      try {
        isMuted.value = false;
      } catch (e) { debugPrint('[err] $e'); }
      try {
        isVideoMuted.value = true;
      } catch (e) { debugPrint('[err] $e'); }
      try {
        isRemoteVideoEnabled.value = false;
      } catch (e) { debugPrint('[err] $e'); }

      try {
        _cleanupIncomingData();
      } catch (e) {
        debugPrint('[call] error cleaning incoming data: $e');
      }
      
try {
  final session = await AudioSession.instance;
  await session.setActive(false);
  debugPrint('[call] audio session deactivated');
} catch (e) {
  debugPrint('[call] failed to deactivate audio session: $e');
}

if (!kIsWeb && Platform.isAndroid) {
  try {
    await const MethodChannel('onyx/audio').invokeMethod('resetAudioMode');
    debugPrint('[call] Android AudioManager.mode reset to MODE_NORMAL');
  } catch (e) {
    debugPrint('[call] MethodChannel resetAudioMode failed: $e');
  }
}
      debugPrint('[call] cleanup complete');
    } catch (e, st) {
      debugPrint('[call] cleanup unexpected error: $e\n$st');
    } finally {
      _isCleaningUp = false;
    }
  }

  RTCVideoRenderer get localRenderer => _localRenderer;
  RTCVideoRenderer get remoteRenderer => _remoteRenderer;
}

final CallManager callManager = CallManager();