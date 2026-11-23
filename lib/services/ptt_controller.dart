import 'dart:async';
import 'dart:typed_data';

import 'package:uuid/uuid.dart';

import '../audio/audio_capture.dart';
import '../audio/audio_player.dart';
import '../audio/voice_activity_detector.dart';
import '../models/participant.dart';
import '../transport/bluetooth_transport.dart';
import '../transport/internet_relay_transport.dart';
import '../transport/transport.dart';
import '../transport/wifi_transport.dart';

/// Wires a [Transport] (WiFi, Bluetooth, or the internet relay) to the
/// microphone and speaker, and exposes the streams the UI needs: who's on
/// the channel, who's currently talking, and free-text status messages.
///
/// Talking can be driven two ways, matching the app's two modes:
/// - **Push-to-talk** ([beginTalking]/[endTalking]) — the button-driven
///   mode used by WiFi/Bluetooth channels.
/// - **Voice-activated** ([enableVoiceActivation]) — Intercom mode's
///   hands-free mode, where a [VoiceActivityDetector] decides when to
///   transmit instead of a button press.
/// A given session only ever uses one of the two.
class PttController {
  final String selfId;
  final String displayName;
  final String channelName;

  Transport? _transport;
  final AudioCapture _capture = AudioCapture();
  final AudioPlayer _player;
  StreamSubscription<ChannelEvent>? _eventSub;

  final _participantsController = StreamController<List<Participant>>.broadcast();
  Stream<List<Participant>> get participants => _participantsController.stream;

  final _statusController = StreamController<String>.broadcast();
  Stream<String> get status => _statusController.stream;

  /// The participant currently heard talking, or null when the channel is
  /// quiet. Only one remote speaker is tracked at a time, same as a real
  /// walkie-talkie channel.
  final _remoteTalkController = StreamController<Participant?>.broadcast();
  Stream<Participant?> get remoteTalker => _remoteTalkController.stream;

  List<Participant> _lastParticipants = [];
  bool _isSelfTalking = false;
  bool get isSelfTalking => _isSelfTalking;
  TransportMode? get mode => _transport?.mode;

  bool _muted = false;
  bool get isMuted => _muted;
  bool _deafened = false;
  bool get isDeafened => _deafened;

  VoiceActivityDetector? _vad;
  bool get isVoiceActivated => _vad != null;

  /// Set to a participant's id to whisper only to them (internet relay
  /// mode only — see [InternetRelayTransport]); set back to null to
  /// return to talking on the whole channel.
  String? get whisperTarget => _transport is InternetRelayTransport
      ? (_transport as InternetRelayTransport).whisperTo
      : null;
  set whisperTarget(String? id) {
    final transport = _transport;
    if (transport is InternetRelayTransport) transport.whisperTo = id;
  }

  PttController({
    required this.displayName,
    required this.channelName,
    String? selfId,
    Duration audioPlayoutDelay = Duration.zero,
  })  : selfId = selfId ?? const Uuid().v4().substring(0, 8),
        _player = AudioPlayer(playoutDelay: audioPlayoutDelay);

  Future<void> startWifi() async {
    final transport = WifiTransport();
    await _attach(transport);
    await transport.start(channelName: channelName, displayName: displayName, selfId: selfId);
  }

  Future<void> startBluetoothAsHost() async {
    final transport = BluetoothTransport();
    await _attach(transport);
    await transport.start(channelName: channelName, displayName: displayName, selfId: selfId);
  }

  Future<void> startBluetoothAsClient(String hostAddress) async {
    final transport = BluetoothTransport();
    await _attach(transport);
    await transport.start(
      channelName: channelName,
      displayName: displayName,
      selfId: selfId,
      connectTo: hostAddress,
    );
  }

  Future<void> startIntercom({required Uri relayUrl}) async {
    final transport = InternetRelayTransport(relayUrl: relayUrl);
    await _attach(transport);
    await transport.start(channelName: channelName, displayName: displayName, selfId: selfId);
  }

  Future<void> _attach(Transport transport) async {
    await _teardownTransport();
    _transport = transport;
    await _player.init();
    _eventSub = transport.events.listen(_onEvent);
  }

  void _onEvent(ChannelEvent event) {
    switch (event) {
      case ParticipantsChanged(participants: final list):
        _lastParticipants = list;
        _participantsController.add(list);
      case AudioReceived(pcm16: final bytes):
        if (!_deafened) _player.play(bytes);
      case TalkStateChanged(senderId: final id, isTalking: final talking):
        if (!talking) {
          _remoteTalkController.add(null);
        } else {
          final p = _lastParticipants.firstWhere(
            (p) => p.id == id,
            orElse: () => Participant(id: id, name: id),
          );
          _remoteTalkController.add(p);
        }
      case TransportStatus(message: final message):
        _statusController.add(message);
    }
  }

  // ---- Push-to-talk driving (WiFi / Bluetooth) ----------------------------

  Future<void> beginTalking() async {
    if (_isSelfTalking || _transport == null || _muted) return;
    final hasPermission = await _capture.hasPermission();
    if (!hasPermission) {
      _statusController.add('Microphone permission is needed to talk.');
      return;
    }
    _isSelfTalking = true;
    _transport!.sendTalkStart();
    await _capture.start((chunk) => _transport?.sendAudioChunk(chunk));
  }

  Future<void> endTalking() async {
    if (!_isSelfTalking) return;
    _isSelfTalking = false;
    await _capture.stop();
    _transport?.sendTalkEnd();
  }

  // ---- Voice-activated driving (Intercom mode) ----------------------------

  /// Starts continuously monitoring the mic and automatically opening /
  /// closing transmission based on voice activity — see
  /// [VoiceActivityDetector] for why this is also what saves battery and
  /// mobile data in Intercom mode.
  Future<void> enableVoiceActivation({double sensitivity = 0.5}) async {
    if (_vad != null || _transport == null) return;
    final hasPermission = await _capture.hasPermission();
    if (!hasPermission) {
      _statusController.add('Microphone permission is needed for Intercom mode.');
      return;
    }
    _vad = VoiceActivityDetector(sensitivity: sensitivity);
    await _capture.start(_onVoxChunk);
  }

  /// Changes how easily Intercom mode picks up your voice, without
  /// restarting the mic. 0.0 = needs a raised voice, 1.0 = picks up a
  /// whisper (but is more prone to false triggers from wind/engine noise).
  void setVoxSensitivity(double sensitivity) {
    _vad = VoiceActivityDetector(sensitivity: sensitivity);
  }

  Future<void> disableVoiceActivation() async {
    if (_vad == null) return;
    _vad = null;
    await _capture.stop();
    if (_isSelfTalking) {
      _isSelfTalking = false;
      _transport?.sendTalkEnd();
    }
  }

  void _onVoxChunk(Uint8List chunk) {
    final vad = _vad;
    if (vad == null) return;
    final active = !_muted && vad.process(chunk);
    if (active && !_isSelfTalking) {
      _isSelfTalking = true;
      _transport?.sendTalkStart();
    } else if (!active && _isSelfTalking) {
      _isSelfTalking = false;
      _transport?.sendTalkEnd();
    }
    if (active) _transport?.sendAudioChunk(chunk);
  }

  // ---- Mute / deafen -------------------------------------------------------

  /// Stops transmitting your voice regardless of the button or VOX —
  /// instant and total, for "don't repeat that" moments.
  void setMuted(bool muted) {
    _muted = muted;
    if (muted && _isSelfTalking) {
      _isSelfTalking = false;
      _transport?.sendTalkEnd();
    }
  }

  /// Stops playing everyone else's audio, without announcing it the way
  /// leaving the channel would.
  void setDeafened(bool deafened) {
    _deafened = deafened;
    if (deafened) _player.clear();
  }

  Future<void> _teardownTransport() async {
    await _eventSub?.cancel();
    _eventSub = null;
    _vad = null;
    await _capture.stop();
    await _transport?.stop();
    _transport = null;
  }

  Future<void> dispose() async {
    await endTalking();
    await _teardownTransport();
    await _capture.dispose();
    await _player.dispose();
    await _participantsController.close();
    await _statusController.close();
    await _remoteTalkController.close();
  }
}
