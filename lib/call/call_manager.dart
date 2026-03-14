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
import 'package:audio_session/audio_session.dart';

import 'dart:io' show Platform;
import 'package:flutter/services.dart';

class CallManager {
  static final CallManager _instance = CallManager._internal();
  factory CallManager() => _instance;
  CallManager._internal();

  String? _currentCallId;
  String? peerUsername;

  bool _isAudioOnly = true;
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

  late WebSocketChannel? Function() _getWs;

  void init({required WebSocketChannel? Function() getWs}) {
    _getWs = getWs;
    _localRenderer = RTCVideoRenderer();
    _remoteRenderer = RTCVideoRenderer();
  }

  String _generateCallId() =>
      DateTime.now().microsecondsSinceEpoch.toString().padLeft(16, '0');

  Future<void> _createPeerConnection() async {
    final config = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
        {'urls': 'stun:stun.cloudflare.com:3478'},
      ],
      'iceTransportPolicy': 'all',
    };

    _peerConnection = await createPeerConnection(config);

    _peerConnection!.onIceCandidate = (candidate) {
      if (candidate == null) return;
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
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        isConnecting.value = false;
        _fallbackToRelay();
      }
    };

    _peerConnection!.onIceConnectionState = (state) {
      debugPrint('[call] ICE state: $state');
      if (state == RTCIceConnectionState.RTCIceConnectionStateConnected) {
        relayMode.value = 'P2P';
      } else if (state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
        debugPrint('[call] ICE failed → fallback to relay');
        _fallbackToRelay();
      }
    };
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

  Future<void> switchCamera() async {
    if (_localStream == null) return;
    final videoTracks = _localStream!.getVideoTracks();
    if (videoTracks.isEmpty) return;
    try {
      await Helper.switchCamera(videoTracks.first);
      debugPrint('[call] camera switched');
    } catch (e) {
      debugPrint('[call] switchCamera failed: $e');
    }
  }

  Future<void> toggleSpeaker() async {
    try {
      final willOn = !(isSpeakerOn.value);
      await Helper.setSpeakerphoneOn(willOn);
      isSpeakerOn.value = willOn;
      debugPrint('[call] speaker toggled: \$willOn');
    } catch (e) {
      debugPrint('[call] toggleSpeaker failed: \$e');
    }
  }

  Future<void> _addLocalStream() async {
    final mediaConstraints = <String, dynamic>{
      'audio': {
        'echoCancellation': false,
        'noiseSuppression': false,
        'autoGainControl': true,
        'googEchoCancellation': false,
        'googNoiseSuppression': false,
        'sampleRate': 48000,
        'sampleSize': 16,
        'channelCount': 1,
      },
      'video': true,
    };

    _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);

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

    if (_isAudioOnly) {
      final videoTracks = _localStream!.getVideoTracks();
      if (videoTracks.isNotEmpty) {
        final videoTrack = videoTracks.first;
        videoTrack.enabled = false;
        isVideoMuted.value = true;
      }
    } else {
      isVideoMuted.value = false;
    }

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
    final answer = RTCSessionDescription(sdp, 'answer');
    await _peerConnection!.setRemoteDescription(answer);
  }

  void _sendCallSignal(Map<String, dynamic> payload) {
    final ws = _getWs();
    ws?.sink.add(jsonEncode(payload));
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

  Future<void> startCall(String peer, {bool video = false}) async {
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

      if (video) {
        final camStatus = await Permission.camera.request();
        if (camStatus.isPermanentlyDenied) {
          rootScreenKey.currentState?.showSnack(
            'Camera permission is required. Go to Settings → Permissions.',
          );
          await openAppSettings();
          return;
        }
        if (!camStatus.isGranted) {
          rootScreenKey.currentState?.showSnack(
            'Camera access required for video calls',
          );
          return;
        }
      }
    }

    peerUsername = peer;
    _isAudioOnly = !video;
    _currentCallId = _generateCallId();
    isInCall.value = true;
    isConnecting.value = true;

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
    isInCall.value = true;
    isConnecting.value = true;

    try {
      await _localRenderer.initialize();
      await _remoteRenderer.initialize();
      await _createPeerConnection();
      await _addLocalStream();

      final offer = RTCSessionDescription(_incomingOfferSdp!, 'offer');
      await _peerConnection!.setRemoteDescription(offer);

      final answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);

      _sendCallSignal({
        'type': 'call_answer',
        'to': peerUsername,
        'call_id': _currentCallId,
        'sdp': answer.sdp,
      });

      debugPrint('[call]  answer sent successfully');
      isIncomingCall.value = false;
      _cleanupIncomingData();
    } catch (e, st) {
      debugPrint('[call]  accept failed: $e\n$st');
      cleanup();
      isIncomingCall.value = true;
    }
  }

  void rejectCall() {
    if (incomingPeer != null && _incomingCallId != null) {
      _sendCallSignal({
        'type': 'call_hangup',
        'to': incomingPeer,
        'call_id': _incomingCallId,
        'reason': 'rejected',
      });
    }
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

  Future<void> toggleVideo() async {
    if (_localStream == null || _peerConnection == null) return;

    final videoTrack = _localStream!.getVideoTracks().firstOrNull;
    if (videoTrack == null) return;

    final wasEnabled = videoTrack.enabled;
    final willEnable = !wasEnabled;

    videoTrack.enabled = willEnable;
    isVideoMuted.value = !willEnable;

    if (willEnable) {
      try {
        
        final newOffer = await _peerConnection!.createOffer();
        await _peerConnection!.setLocalDescription(newOffer);
        _sendCallSignal({
          'type': 'call_offer',
          'to': peerUsername,
          'call_id': _currentCallId,
          'sdp': newOffer.sdp,
        });
        debugPrint('[call] renegotiation offer sent with video enabled');
      } catch (e, st) {
        debugPrint('[call] renegotiation failed: $e\n$st');
        
        videoTrack.enabled = wasEnabled;
        isVideoMuted.value = !wasEnabled;
      }
    }
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
          final offer = RTCSessionDescription(sdp, 'offer');
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

      _localStream = null;
      _remoteStream = null;
      
      try {
        isInCall.value = false;
      } catch (e) { debugPrint('[err] $e'); }
      try {
        isConnecting.value = false;
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