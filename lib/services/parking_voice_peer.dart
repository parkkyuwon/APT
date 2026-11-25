import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

typedef VoiceSignalCallback = void Function(
    String type, Map<String, dynamic> payload);
typedef VoicePeerFactory = VoicePeer Function();

/// Native media is isolated from session/signaling logic for deterministic tests.
abstract class VoicePeer {
  Future<void> open(Map<String, dynamic> configuration,
      {required VoiceSignalCallback onSignal,
      required void Function(bool) onConnection,
      required VoidCallback onFailure});
  Future<void> offer();
  Future<void> receive(String type, Map<String, dynamic> payload);
  void mute(bool value);
  Future<void> speaker(bool value);

  /// Must disable audio synchronously, including when native opening is pending.
  void close();
}

class WebRtcVoicePeer implements VoicePeer {
  RTCPeerConnection? _connection;
  MediaStream? _stream;
  final List<RTCIceCandidate> _remoteCandidates = [];
  final List<MediaStreamTrack> _remoteTracks = [];
  VoiceSignalCallback? _onSignal;
  bool _remoteDescriptionSet = false;
  int _generation = 0;

  bool _current(int generation) => generation == _generation;

  @override
  Future<void> open(Map<String, dynamic> configuration,
      {required VoiceSignalCallback onSignal,
      required void Function(bool) onConnection,
      required VoidCallback onFailure}) async {
    final generation = ++_generation;
    _onSignal = onSignal;
    final connection = await createPeerConnection({
      'iceServers': configuration['iceServers'],
      'iceTransportPolicy': 'relay',
      'sdpSemantics': 'unified-plan',
    });
    if (!_current(generation)) {
      await connection.close();
      await connection.dispose();
      return;
    }
    _connection = connection;
    connection.onTrack = (event) {
      final track = event.track;
      if (!_current(generation) || track.kind != 'audio') {
        track.enabled = false;
        unawaited(track.stop().catchError((Object _) {}));
        return;
      }
      // Native WebRTC plays received audio through its audio device module.
      // A video renderer is unnecessary for an audio-only native connection.
      track.enabled = true;
      _remoteTracks.add(track);
    };
    connection.onIceCandidate = (candidate) {
      if (!_current(generation) ||
          candidate.candidate == null ||
          candidate.candidate!.isEmpty) {
        return;
      }
      onSignal('ice', {
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      });
    };
    connection.onConnectionState = (state) {
      if (!_current(generation)) return;
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        onConnection(true);
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        onFailure();
      } else if (state ==
          RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        onConnection(false);
      }
    };
    // Controller calls open only after both parties have accepted. No camera.
    final stream = await navigator.mediaDevices
        .getUserMedia({'audio': true, 'video': false});
    if (!_current(generation)) {
      await _releaseStream(stream);
      return;
    }
    _stream = stream;
    for (final track in stream.getAudioTracks()) {
      if (!_current(generation)) return;
      await connection.addTrack(track, stream);
    }
    if (_current(generation)) await Helper.setSpeakerphoneOn(false);
  }

  @override
  Future<void> offer() async {
    final generation = _generation;
    final connection = _connection;
    if (connection == null) return;
    final description = await connection.createOffer(
        {'offerToReceiveAudio': true, 'offerToReceiveVideo': false});
    if (!_current(generation)) return;
    await connection.setLocalDescription(description);
    if (_current(generation)) {
      _onSignal?.call('offer', {'sdp': description.sdp});
    }
  }

  @override
  Future<void> receive(String type, Map<String, dynamic> payload) async {
    final connection = _connection;
    if (connection == null) return;
    final generation = _generation;
    if (type == 'ice') {
      final candidate = RTCIceCandidate(payload['candidate'] as String?,
          payload['sdpMid'] as String?, payload['sdpMLineIndex'] as int?);
      if (!_remoteDescriptionSet) {
        if (_remoteCandidates.length >= 256) {
          throw StateError('Too many candidates');
        }
        _remoteCandidates.add(candidate);
      } else {
        await connection.addCandidate(candidate);
      }
      return;
    }
    if (type != 'offer' && type != 'answer') throw StateError('Invalid signal');
    final sdp = payload['sdp'];
    if (sdp is! String || sdp.isEmpty) throw StateError('Missing description');
    await connection.setRemoteDescription(RTCSessionDescription(sdp, type));
    if (!_current(generation)) return;
    _remoteDescriptionSet = true;
    while (_remoteCandidates.isNotEmpty) {
      await connection.addCandidate(_remoteCandidates.removeAt(0));
      if (!_current(generation)) return;
    }
    if (type == 'offer') {
      final description =
          await connection.createAnswer({'offerToReceiveAudio': true});
      if (!_current(generation)) return;
      await connection.setLocalDescription(description);
      if (_current(generation)) {
        _onSignal?.call('answer', {'sdp': description.sdp});
      }
    }
  }

  @override
  void mute(bool value) {
    for (final track in _stream?.getAudioTracks() ?? <MediaStreamTrack>[]) {
      track.enabled = !value;
    }
  }

  @override
  Future<void> speaker(bool value) => Helper.setSpeakerphoneOn(value);

  static Future<void> _releaseStream(MediaStream stream) async {
    for (final track in stream.getTracks()) {
      track.enabled = false;
    }
    for (final track in stream.getTracks()) {
      await track.stop();
    }
    await stream.dispose();
  }

  @override
  void close() {
    _generation++;
    mute(true);
    for (final track in _remoteTracks) {
      track.enabled = false;
      unawaited(track.stop().catchError((Object _) {}));
    }
    _remoteTracks.clear();
    final stream = _stream;
    final connection = _connection;
    _stream = null;
    _connection = null;
    _onSignal = null;
    _remoteCandidates.clear();
    _remoteDescriptionSet = false;
    if (stream != null) {
      unawaited(_releaseStream(stream).catchError((Object _) {}));
    }
    if (connection != null) {
      unawaited(() async {
        await connection.close();
        await connection.dispose();
      }()
          .catchError((Object _) {}));
    }
  }
}
