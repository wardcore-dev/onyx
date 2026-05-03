// lib/voice/voice_channel_manager.dart
import 'dart:async';
import 'dart:io';
import 'dart:math' show sqrt;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audio_session/audio_session.dart';
import 'package:record/record.dart';
import 'package:media_kit/media_kit.dart' as mk;

import '../managers/external_server_manager.dart';
import '../managers/settings_manager.dart';
import '../globals.dart' show navigatorKey;

// ── Audio quality settings received from the server ──────────────────────────

class VoiceAudioConfig {
  final int maxBitrateBps;
  final bool noiseSuppression;
  final bool echoCancellation;
  final bool autoGainControl;
  final bool stereo;
  final String quality;

  const VoiceAudioConfig({
    this.maxBitrateBps = 64000,
    this.noiseSuppression = true,
    this.echoCancellation = true,
    this.autoGainControl = true,
    this.stereo = false,
    this.quality = 'medium',
  });

  factory VoiceAudioConfig.fromJson(Map<String, dynamic> json) {
    return VoiceAudioConfig(
      maxBitrateBps: (json['max_bitrate_bps'] as num?)?.toInt() ?? 64000,
      noiseSuppression: json['noise_suppression'] as bool? ?? true,
      echoCancellation: json['echo_cancellation'] as bool? ?? true,
      autoGainControl: json['auto_gain_control'] as bool? ?? true,
      stereo: json['stereo'] as bool? ?? false,
      quality: json['quality'] as String? ?? 'medium',
    );
  }

  Map<String, dynamic> get mediaConstraints => {
        'echoCancellation': echoCancellation,
        'noiseSuppression': noiseSuppression,
        'autoGainControl': autoGainControl,
        'googEchoCancellation': echoCancellation,
        'googEchoCancellation2': echoCancellation,
        'googNoiseSuppression': noiseSuppression,
        'googNoiseSuppression2': noiseSuppression,
        'googAutoGainControl': autoGainControl,
        'googAutoGainControl2': autoGainControl,
        'googHighpassFilter': noiseSuppression,
        'googTypingNoiseDetection': noiseSuppression,
        'sampleRate': 48000,
        'sampleSize': 16,
        'channelCount': stereo ? 2 : 1,
      };

  /// Inject Opus bitrate and stereo params into an SDP string.
  /// Uses both b=AS (widely supported) and maxaveragebitrate fmtp (Opus-specific).
  String applyToSdp(String sdp) {
    final lines = sdp.split('\r\n');
    final kbps = maxBitrateBps ~/ 1000;
    final stereoVal = stereo ? 1 : 0;
    final newFmtp =
        'minptime=10;useinbandfec=1;maxaveragebitrate=$maxBitrateBps;maxplaybackrate=48000;stereo=$stereoVal;sprop-stereo=$stereoVal';

    // Find the Opus payload type (e.g. "a=rtpmap:111 opus/48000/2")
    int? opusPt;
    for (final line in lines) {
      final m = RegExp(r'^a=rtpmap:(\d+) opus').firstMatch(line);
      if (m != null) {
        opusPt = int.parse(m.group(1)!);
        break;
      }
    }
    if (opusPt == null) return sdp;

    final fmtpPrefix = 'a=fmtp:$opusPt ';
    final result = <String>[];
    bool fmtpFound = false;
    bool inAudioSection = false;
    bool bLineInserted = false;

    for (final line in lines) {
      if (line.startsWith('m=audio')) {
        inAudioSection = true;
        bLineInserted = false;
        result.add(line);
        continue;
      } else if (line.startsWith('m=')) {
        inAudioSection = false;
      }

      // Insert/replace b=AS in the audio section before the first a= attribute
      if (inAudioSection && !bLineInserted) {
        if (line.startsWith('b=AS:') || line.startsWith('b=TIAS:')) {
          result.add('b=AS:$kbps');
          bLineInserted = true;
          continue;
        } else if (line.startsWith('a=')) {
          result.add('b=AS:$kbps');
          bLineInserted = true;
        }
      }

      if (line.startsWith(fmtpPrefix)) {
        result.add('$fmtpPrefix$newFmtp');
        fmtpFound = true;
      } else {
        result.add(line);
        if (!fmtpFound && line.startsWith('a=rtpmap:$opusPt ')) {
          result.add('$fmtpPrefix$newFmtp');
          fmtpFound = true;
        }
      }
    }

    return result.join('\r\n');
  }
}


// ── Manager ───────────────────────────────────────────────────────────────────

class VoiceChannelManager {
  static final VoiceChannelManager instance = VoiceChannelManager._();

  VoiceChannelManager._() {
    ExternalServerManager.connectedServerIds.addListener(_onServerConnectionChanged);
  }

  String? _serverId;
  String? _channelId;
  VoiceAudioConfig _audioConfig = const VoiceAudioConfig();

  MediaStream? _localStream;
  final Map<String, RTCPeerConnection> _peerConnections = {};
  final Map<String, MediaStream> _remoteStreams = {};
  final Map<String, List<Map<String, dynamic>>> _pendingIce = {};
  final Set<String> _remoteDescSet = {};

  RTCPeerConnection? _loopbackSender;
  RTCPeerConnection? _loopbackReceiver;

  AudioRecorder? _vadRecorder;
  StreamSubscription<List<int>>? _vadSub;

  // Direct monitor (mode 2) — dart:io HTTP server + media_kit Player (libmpv)
  HttpServer? _directServer;
  StreamController<List<int>>? _directPcmCtrl;
  mk.Player? _mkPlayer;

  // ── Observable state ────────────────────────────────────────────────────────

  final ValueNotifier<bool> isInChannel = ValueNotifier(false);
  final ValueNotifier<bool> isMuted = ValueNotifier(false);
  /// 0 = off  1 = WebRTC loopback (Opus, ~80 ms delay, simulates server path)
  /// 2 = direct PCM passthrough (raw audio, ~150 ms buffer latency)
  final ValueNotifier<int> selfMonitorMode = ValueNotifier(0);
  /// Normalised 0.0–1.0 mic input level for the VU-meter indicator.
  final ValueNotifier<double> audioLevel = ValueNotifier(0.0);
  final ValueNotifier<String?> currentChannelId = ValueNotifier(null);
  final ValueNotifier<String?> currentServerId = ValueNotifier(null);
  final ValueNotifier<List<String>> channelUsers = ValueNotifier([]);
  final ValueNotifier<Map<String, Map<String, List<String>>>> allChannels =
      ValueNotifier({});

  // ── ICE config ──────────────────────────────────────────────────────────────

  static const _iceConfig = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun.cloudflare.com:3478'},
    ],
    'iceTransportPolicy': 'all',
  };

  // ── Public API ──────────────────────────────────────────────────────────────

  Future<void> joinChannel(String serverId, String channelId) async {
    if (isInChannel.value) await leaveChannel();

    if (kIsWeb || !Platform.isMacOS) {
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        debugPrint('[voice] microphone permission denied');
        _showVoiceError(
          'Нет доступа к микрофону',
          'Разреши доступ к микрофону в настройках устройства:\n\n'
          'Настройки → Приложения → Onyx → Разрешения → Микрофон.',
        );
        return;
      }
    }

    // Fetch server's audio quality config (cached by ExternalServerManager).
    _audioConfig = VoiceAudioConfig.fromJson(
        await ExternalServerManager.getVoiceConfig(serverId));
    debugPrint('[voice] audio config: quality=${_audioConfig.quality} '
        'bitrate=${_audioConfig.maxBitrateBps}bps '
        'ns=${_audioConfig.noiseSuppression} '
        'ec=${_audioConfig.echoCancellation}');

    _serverId = serverId;
    _channelId = channelId;

    final inputDeviceId = SettingsManager.audioInputDeviceId.value;
    if (inputDeviceId.isNotEmpty) {
      try {
        await Helper.selectAudioInput(inputDeviceId);
      } catch (e) {
        debugPrint('[voice] selectAudioInput error: $e');
      }
    }

    _localStream = await _getUserMediaWithFallback();
    if (_localStream == null || _localStream!.getAudioTracks().isEmpty) {
      debugPrint('[voice] no audio tracks — aborting join');
      _serverId = null;
      _channelId = null;
      return;
    }

    try {
      final session = await AudioSession.instance;
      final bool useProcessing = _audioConfig.echoCancellation ||
          _audioConfig.noiseSuppression ||
          _audioConfig.autoGainControl;
      // speech() sets MODE_IN_COMMUNICATION on Android which forces hardware-level
      // EC/NS/AGC on both input and output regardless of getUserMedia constraints.
      // When server disables all processing, use music() to get MODE_NORMAL instead.
      await session.configure(useProcessing
          ? const AudioSessionConfiguration.speech()
          : AudioSessionConfiguration(
              avAudioSessionCategory:
                  AVAudioSessionCategory.playAndRecord,
              avAudioSessionCategoryOptions:
                  AVAudioSessionCategoryOptions.allowBluetooth |
                      AVAudioSessionCategoryOptions.defaultToSpeaker,
              avAudioSessionMode: AVAudioSessionMode.defaultMode,
              androidAudioAttributes: const AndroidAudioAttributes(
                contentType: AndroidAudioContentType.music,
                usage: AndroidAudioUsage.media,
                flags: AndroidAudioFlags.none,
              ),
              androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
              androidWillPauseWhenDucked: false,
            ));
      await session.setActive(true);
    } catch (e) {
      debugPrint('[voice] audio session error: $e');
    }

    final outputDeviceId = SettingsManager.audioOutputDeviceId.value;
    if (outputDeviceId.isNotEmpty) {
      try {
        await Helper.selectAudioOutput(outputDeviceId);
      } catch (e) {
        debugPrint('[voice] selectAudioOutput error: $e');
      }
    }

    isInChannel.value = true;
    currentChannelId.value = channelId;
    currentServerId.value = serverId;
    await _startVad();

    ExternalServerManager.sendVoiceSignal(serverId, {
      'type': 'voice_join',
      'channel_id': channelId,
    });
    debugPrint('[voice] sent voice_join for channel $channelId on $serverId');
  }

  Future<void> leaveChannel() async {
    if (!isInChannel.value) return;
    final srv = _serverId;
    final ch = _channelId;
    if (srv != null && ch != null) {
      ExternalServerManager.sendVoiceSignal(srv, {
        'type': 'voice_leave',
        'channel_id': ch,
      });
    }
    await _cleanup();
    debugPrint('[voice] left channel $ch');
  }

  void toggleMute() {
    final muted = !isMuted.value;
    _localStream?.getAudioTracks().forEach((t) => t.enabled = !muted);
    isMuted.value = muted;
  }

  Future<void> handleMessage(
      Map<String, dynamic> msg, String myUsername, String serverId) async {
    final type = msg['type'] as String?;
    debugPrint('[voice] handleMessage type=$type serverId=$serverId');

    switch (type) {
      case 'voice_channel_state':
        final channelId = msg['channel_id'] as String;
        final users = List<String>.from(msg['users'] as List);
        _updateRegistry(serverId, channelId, users);

        if (isInChannel.value &&
            _serverId == serverId &&
            _channelId == channelId) {
          channelUsers.value = List<String>.from(users)..remove(myUsername);
          for (final peer in users) {
            if (peer != myUsername) {
              await _initiateOffer(peer);
            }
          }
        }
        break;

      case 'voice_user_joined':
        final channelId = msg['channel_id'] as String;
        final username = msg['username'] as String;
        final current = Map<String, List<String>>.from(
            allChannels.value[serverId] ?? {});
        final users = List<String>.from(current[channelId] ?? []);
        if (!users.contains(username)) users.add(username);
        _updateRegistry(serverId, channelId, users);

        if (isInChannel.value &&
            _serverId == serverId &&
            _channelId == channelId &&
            username != myUsername) {
          final us = List<String>.from(channelUsers.value);
          if (!us.contains(username)) channelUsers.value = [...us, username];
        }
        break;

      case 'voice_user_left':
        final channelId = msg['channel_id'] as String;
        final username = msg['username'] as String;
        final current = Map<String, List<String>>.from(
            allChannels.value[serverId] ?? {});
        final users = List<String>.from(current[channelId] ?? [])
          ..remove(username);
        _updateRegistry(serverId, channelId, users);

        if (isInChannel.value &&
            _serverId == serverId &&
            _channelId == channelId) {
          channelUsers.value =
              channelUsers.value.where((u) => u != username).toList();
          await _closePeer(username);
        }
        break;

      case 'voice_offer':
        if (!isInChannel.value) break;
        final from = msg['from'] as String;
        final sdp = msg['sdp'] as String;
        final channelId = msg['channel_id'] as String;
        if (_serverId == serverId && _channelId == channelId) {
          await _handleOffer(from, sdp);
        }
        break;

      case 'voice_answer':
        if (!isInChannel.value) break;
        final from = msg['from'] as String;
        final sdp = msg['sdp'] as String;
        final channelId = msg['channel_id'] as String;
        if (_serverId == serverId && _channelId == channelId) {
          final pc = _peerConnections[from];
          if (pc != null) {
            await pc.setRemoteDescription(RTCSessionDescription(sdp, 'answer'));
            _remoteDescSet.add(from);
            await _flushPendingIce(from, pc);
          }
        }
        break;

      case 'voice_ice':
        if (!isInChannel.value) break;
        final from = msg['from'] as String;
        final candidate = msg['candidate'] as Map<String, dynamic>;
        final channelId = msg['channel_id'] as String;
        if (_serverId == serverId && _channelId == channelId) {
          final pc = _peerConnections[from];
          if (pc != null && _remoteDescSet.contains(from)) {
            try {
              await pc.addCandidate(RTCIceCandidate(
                candidate['candidate'] as String,
                candidate['sdpMid'] as String?,
                (candidate['sdpMLineIndex'] as num?)?.toInt(),
              ));
            } catch (e) {
              debugPrint('[voice] addCandidate error: $e');
            }
          } else {
            _pendingIce.putIfAbsent(from, () => []).add(candidate);
          }
        }
        break;
    }
  }

  // ── Private helpers ──────────────────────────────────────────────────────────

  void _onServerConnectionChanged() {
    final serverId = _serverId;
    if (serverId == null || !isInChannel.value) return;
    if (!ExternalServerManager.connectedServerIds.value.contains(serverId)) {
      debugPrint('[voice] server $serverId disconnected — clearing voice state');
      _cleanup();
    }
  }

  Future<void> _initiateOffer(String peerUsername) async {
    final pc = await _makePeerConnection(peerUsername);
    // No offerToReceiveAudio — addTrack already created a sendrecv transceiver.
    // Passing offerToReceiveAudio:1 on top creates a second recvonly transceiver
    // which breaks negotiation with the answerer.
    final offer = await pc.createOffer({});

    final modifiedSdp = _audioConfig.applyToSdp(offer.sdp ?? '');
    await pc.setLocalDescription(RTCSessionDescription(modifiedSdp, 'offer'));
    await _applyBitrateToSenders(pc);

    ExternalServerManager.sendVoiceSignal(_serverId!, {
      'type': 'voice_offer',
      'channel_id': _channelId,
      'target': peerUsername,
      'sdp': modifiedSdp,
    });
    debugPrint('[voice] sent offer to $peerUsername '
        '(${_audioConfig.maxBitrateBps ~/ 1000}kbps)');
  }

  Future<void> _handleOffer(String peerUsername, String sdp) async {
    // Always start fresh — a new offer supersedes any previous negotiation.
    // Reusing a stale PC (failed/closed state) causes setRemoteDescription to
    // throw, the answer is never sent, and audio is silently one-directional.
    if (_peerConnections.containsKey(peerUsername)) {
      await _closePeer(peerUsername);
    }
    final pc = await _makePeerConnection(peerUsername);
    await pc.setRemoteDescription(RTCSessionDescription(sdp, 'offer'));
    _remoteDescSet.add(peerUsername);
    await _flushPendingIce(peerUsername, pc);

    final answer = await pc.createAnswer();
    final modifiedSdp = _audioConfig.applyToSdp(answer.sdp ?? '');
    await pc.setLocalDescription(RTCSessionDescription(modifiedSdp, 'answer'));
    await _applyBitrateToSenders(pc);

    ExternalServerManager.sendVoiceSignal(_serverId!, {
      'type': 'voice_answer',
      'channel_id': _channelId,
      'target': peerUsername,
      'sdp': modifiedSdp,
    });
    debugPrint('[voice] sent answer to $peerUsername');
  }

  Future<void> _applyBitrateToSenders(RTCPeerConnection pc) async {
    try {
      final senders = await pc.getSenders();
      for (final sender in senders) {
        if (sender.track?.kind == 'audio') {
          final params = sender.parameters;
          final encodings = params.encodings;
          if (encodings != null && encodings.isNotEmpty) {
            encodings[0].maxBitrate = _audioConfig.maxBitrateBps;
            await sender.setParameters(params);
          } else {
            // mobile may return empty encodings — create one explicitly
            await sender.setParameters(RTCRtpParameters(
              transactionId: params.transactionId,
              encodings: [RTCRtpEncoding(maxBitrate: _audioConfig.maxBitrateBps)],
            ));
          }
          debugPrint('[voice] sender maxBitrate=${_audioConfig.maxBitrateBps}bps applied');
        }
      }
    } catch (e) {
      debugPrint('[voice] setParameters: $e');
    }
  }

  Future<RTCPeerConnection> _makePeerConnection(String peer) async {
    if (_peerConnections.containsKey(peer)) return _peerConnections[peer]!;

    final pc = await createPeerConnection(_iceConfig);
    _peerConnections[peer] = pc;

    if (_localStream != null) {
      for (final track in _localStream!.getAudioTracks()) {
        await pc.addTrack(track, _localStream!);
      }
    }

    pc.onTrack = (RTCTrackEvent event) {
      debugPrint('[voice] onTrack from $peer: ${event.track.kind}');
      if (event.streams.isNotEmpty) {
        _remoteStreams[peer] = event.streams[0];
      }
    };

    pc.onIceCandidate = (candidate) {
      if (_serverId == null) return;
      ExternalServerManager.sendVoiceSignal(_serverId!, {
        'type': 'voice_ice',
        'channel_id': _channelId,
        'target': peer,
        'candidate': {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        },
      });
    };

    pc.onConnectionState = (state) {
      debugPrint('[voice] $peer connection state: $state');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        _showVoiceError(
          'Соединение с $peer не установлено',
          'WebRTC не смог установить P2P соединение.\n\n'
          'Возможные причины:\n'
          '• Один из пользователей за строгим NAT или файрволом\n'
          '• Провайдер блокирует UDP трафик\n\n'
          'Попробуй: переключиться на мобильный интернет, '
          'или добавить TURN сервер в конфиг сервера.',
        );
        _closePeer(peer);
      } else if (state ==
          RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        _closePeer(peer);
      }
    };

    return pc;
  }

  Future<void> _flushPendingIce(String peer, RTCPeerConnection pc) async {
    final pending = _pendingIce.remove(peer) ?? [];
    for (final c in pending) {
      try {
        await pc.addCandidate(RTCIceCandidate(
          c['candidate'] as String,
          c['sdpMid'] as String?,
          (c['sdpMLineIndex'] as num?)?.toInt(),
        ));
      } catch (e) {
        debugPrint('[voice] flush ICE error: $e');
      }
    }
  }

  Future<void> _closePeer(String peer) async {
    final pc = _peerConnections.remove(peer);
    await pc?.close();
    _pendingIce.remove(peer);
    _remoteDescSet.remove(peer);
    final stream = _remoteStreams.remove(peer);
    stream?.getTracks().forEach((t) => t.stop());
  }

  void _updateRegistry(String serverId, String channelId, List<String> users) {
    final map = Map<String, Map<String, List<String>>>.from(allChannels.value);
    final serverMap = Map<String, List<String>>.from(map[serverId] ?? {});
    if (users.isEmpty) {
      serverMap.remove(channelId);
    } else {
      serverMap[channelId] = users;
    }
    map[serverId] = serverMap;
    allChannels.value = map;
  }

  void _showVoiceError(String title, String body) {
    final ctx = navigatorKey.currentState?.overlay?.context;
    if (ctx == null) return;
    final scheme = Theme.of(ctx).colorScheme;
    showDialog<void>(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: scheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(Icons.mic_off_rounded, color: scheme.error, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(title,
                style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
          ),
        ]),
        content: Text(body,
            style: TextStyle(
                color: scheme.onSurface.withValues(alpha: 0.75), fontSize: 14)),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            style: FilledButton.styleFrom(backgroundColor: scheme.primary),
            child: const Text('Понятно'),
          ),
        ],
      ),
    );
  }

  static String _describeGetUserMediaError(Object e) {
    final s = e.toString().toLowerCase();
    if (s.contains('notallowederror') || s.contains('permission') || s.contains('denied')) {
      return 'Приложение не имеет доступа к микрофону.\n\nОткрой настройки устройства → Приложения → Onyx → Разрешения → включи Микрофон.';
    }
    if (s.contains('notfounderror') || s.contains('devicenotfound') || s.contains('no device')) {
      return 'Микрофон не найден.\n\nПроверь что наушники/микрофон подключены и не заняты другим приложением.';
    }
    if (s.contains('notreadableerror') || s.contains('could not start')) {
      return 'Микрофон занят другим приложением.\n\nЗакрой программы которые могут использовать микрофон (Discord, Zoom, Teams и т.д.) и попробуй снова.';
    }
    if (s.contains('overconstrained') || s.contains('constraint')) {
      return 'Устройство не поддерживает запрошенные параметры аудио.\n\nПопробуй переключиться на другое устройство ввода в настройках.';
    }
    return 'Не удалось захватить аудио.\n\nДетали: $e';
  }

  Future<MediaStream?> _getUserMediaWithFallback() async {
    // 1st attempt — full quality constraints.
    Object? lastError;
    try {
      final stream = await navigator.mediaDevices.getUserMedia({
        'audio': _audioConfig.mediaConstraints,
        'video': false,
      });
      if (stream.getAudioTracks().isNotEmpty) {
        debugPrint('[voice] getUserMedia ok (full constraints)');
        return stream;
      }
      debugPrint('[voice] getUserMedia returned empty tracks');
    } catch (e) {
      lastError = e;
      debugPrint('[voice] getUserMedia full constraints failed: $e');
    }

    // 2nd attempt — plain audio:true, no custom constraints.
    try {
      final stream = await navigator.mediaDevices
          .getUserMedia({'audio': true, 'video': false});
      if (stream.getAudioTracks().isNotEmpty) {
        debugPrint('[voice] getUserMedia ok (fallback: audio:true)');
        return stream;
      }
    } catch (e) {
      lastError = e;
      debugPrint('[voice] getUserMedia fallback failed: $e');
    }

    _showVoiceError(
      'Не удалось захватить аудио',
      lastError != null
          ? _describeGetUserMediaError(lastError)
          : 'Микрофон не вернул ни одного аудио трека.\n\n'
              'Проверь что наушники/микрофон подключены и не заняты другим приложением.',
    );
    return null;
  }

  // ── VAD (speaking indicator) ─────────────────────────────────────────────────

  Future<void> _startVad() async {
    try {
      _vadRecorder = AudioRecorder();
      final stream = await _vadRecorder!.startStream(const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
        autoGain: false,
        echoCancel: false,
        noiseSuppress: false,
      ));
      _vadSub = stream.listen(_onVadPcm);
      debugPrint('[vad] PCM stream started');
    } catch (e) {
      debugPrint('[vad] startStream failed: $e');
      await _vadRecorder?.dispose();
      _vadRecorder = null;
    }
  }

  void _onVadPcm(List<int> data) {
    if (isMuted.value || data.length < 2) {
      if (audioLevel.value != 0.0) audioLevel.value = 0.0;
      return;
    }
    double sum = 0;
    int count = 0;
    for (int i = 0; i + 1 < data.length; i += 2) {
      int s = data[i] | (data[i + 1] << 8);
      if (s > 32767) s -= 65536;
      sum += s * s;
      count++;
    }
    if (count == 0) return;
    final level = (sqrt(sum / count) / 32768.0).clamp(0.0, 1.0);
    if ((audioLevel.value - level).abs() > 0.005) audioLevel.value = level;
    if (selfMonitorMode.value == 2) _directPcmCtrl?.add(data);
  }

  Future<void> _stopVad() async {
    await _vadSub?.cancel();
    _vadSub = null;
    await _vadRecorder?.stop();
    await _vadRecorder?.dispose();
    _vadRecorder = null;
    if (audioLevel.value != 0.0) audioLevel.value = 0.0;
  }

  /// Cycles: 0 (off) → 1 (WebRTC loopback) → 2 (direct PCM) → 0
  Future<void> toggleSelfMonitor() async {
    switch (selfMonitorMode.value) {
      case 0:
        await _startWebRtcMonitor();
      case 1:
        await _stopWebRtcMonitor();
        await _startDirectMonitor();
      default:
        await _stopDirectMonitor();
    }
  }

  // ── Mode 1 — WebRTC loopback (Opus codec, ~80 ms delay) ─────────────────────

  Future<void> _startWebRtcMonitor() async {
    if (_localStream == null) return;

    _loopbackSender = await createPeerConnection({'iceServers': []});
    _loopbackReceiver = await createPeerConnection({'iceServers': []});

    for (final track in _localStream!.getAudioTracks()) {
      await _loopbackSender!.addTrack(track, _localStream!);
    }

    _loopbackSender!.onIceCandidate = (c) async {
      try { await _loopbackReceiver?.addCandidate(c); } catch (_) {}
    };
    _loopbackReceiver!.onIceCandidate = (c) async {
      try { await _loopbackSender?.addCandidate(c); } catch (_) {}
    };

    final offer = await _loopbackSender!.createOffer({'offerToReceiveAudio': 0});
    await _loopbackSender!.setLocalDescription(offer);
    await _loopbackReceiver!.setRemoteDescription(offer);

    final answer = await _loopbackReceiver!.createAnswer();
    await _loopbackReceiver!.setLocalDescription(answer);
    await _loopbackSender!.setRemoteDescription(answer);

    selfMonitorMode.value = 1;
    debugPrint('[voice] self-monitor: WebRTC loopback started');
  }

  Future<void> _stopWebRtcMonitor() async {
    await _loopbackSender?.close();
    await _loopbackReceiver?.close();
    _loopbackSender = null;
    _loopbackReceiver = null;
    if (selfMonitorMode.value == 1) selfMonitorMode.value = 0;
    debugPrint('[voice] self-monitor: WebRTC loopback stopped');
  }

  // ── Mode 2 — direct PCM passthrough via dart:io HttpServer + libmpv ──────────

  static Uint8List _pcmWavHeader({int sr = 16000, int ch = 1}) {
    final d = ByteData(44);
    d.setUint32(0, 0x52494646, Endian.big);       // RIFF
    d.setUint32(4, 0x7FFFFFFF, Endian.little);    // chunk size (streaming)
    d.setUint32(8, 0x57415645, Endian.big);       // WAVE
    d.setUint32(12, 0x666D7420, Endian.big);      // fmt
    d.setUint32(16, 16, Endian.little);
    d.setUint16(20, 1, Endian.little);            // PCM
    d.setUint16(22, ch, Endian.little);
    d.setUint32(24, sr, Endian.little);
    d.setUint32(28, sr * ch * 2, Endian.little);
    d.setUint16(32, ch * 2, Endian.little);
    d.setUint16(34, 16, Endian.little);
    d.setUint32(36, 0x64617461, Endian.big);      // data
    d.setUint32(40, 0x7FFFFFFF, Endian.little);   // data size (streaming)
    return d.buffer.asUint8List();
  }

  Future<void> _startDirectMonitor() async {
    try {
      // Broadcast so HEAD probe + GET stream can both subscribe without error.
      _directPcmCtrl = StreamController<List<int>>.broadcast();
      _directServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final port = _directServer!.port;

      _directServer!.listen((req) async {
        req.response.headers.set(HttpHeaders.contentTypeHeader, 'audio/wav');
        req.response.headers.set('Accept-Ranges', 'none');
        req.response.bufferOutput = false;

        // libmpv probes with HEAD first — return headers only, no body or
        // stream subscription (avoids claiming the single-sub stream slot).
        if (req.method == 'HEAD') {
          await req.response.close();
          return;
        }

        req.response.add(_pcmWavHeader());
        await req.response.flush();
        try {
          await for (final chunk in _directPcmCtrl!.stream) {
            req.response.add(Uint8List.fromList(chunk));
            await req.response.flush();
          }
        } catch (_) {}
        try { await req.response.close(); } catch (_) {}
      });

      // 64 KB ≈ 2 s at 16 kHz/mono/16-bit — small enough to start quickly.
      _mkPlayer = mk.Player(
        configuration: const mk.PlayerConfiguration(bufferSize: 64 * 1024),
      );
      selfMonitorMode.value = 2; // set before open so _onVadPcm feeds data
      await _mkPlayer!.open(mk.Media('http://127.0.0.1:$port'));
      await _mkPlayer!.play();
      debugPrint('[voice] self-monitor: direct PCM via libmpv on port $port');
    } catch (e, s) {
      debugPrint('[voice] direct monitor start failed: $e\n$s');
      selfMonitorMode.value = 0;
      await _stopDirectMonitor();
    }
  }

  Future<void> _stopDirectMonitor() async {
    await _directPcmCtrl?.close();
    _directPcmCtrl = null;
    try { await _directServer?.close(force: true); } catch (_) {}
    _directServer = null;
    await _mkPlayer?.dispose();
    _mkPlayer = null;
    if (selfMonitorMode.value == 2) selfMonitorMode.value = 0;
    debugPrint('[voice] self-monitor: direct PCM stopped');
  }

  Future<void> _cleanup() async {
    await _stopVad();
    await _stopWebRtcMonitor();
    await _stopDirectMonitor();
    isInChannel.value = false;
    isMuted.value = false;
    currentChannelId.value = null;
    currentServerId.value = null;
    channelUsers.value = [];
    _serverId = null;
    _channelId = null;
    _audioConfig = const VoiceAudioConfig();

    for (final pc in _peerConnections.values) {
      await pc.close();
    }
    _peerConnections.clear();
    _pendingIce.clear();
    _remoteDescSet.clear();

    for (final stream in _remoteStreams.values) {
      stream.getTracks().forEach((t) => t.stop());
    }
    _remoteStreams.clear();

    _localStream?.getTracks().forEach((t) => t.stop());
    _localStream?.dispose();
    _localStream = null;

    try {
      final session = await AudioSession.instance;
      await session.setActive(false);
    } catch (_) {}
  }
}