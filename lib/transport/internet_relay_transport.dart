import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/participant.dart';
import '../protocol/packet.dart';
import 'transport.dart';

/// Talks to other phones over the internet via a small relay server (see
/// `relay_server/`), instead of a local WiFi or Bluetooth link. This is
/// what gives Intercom mode real range: every phone just needs mobile
/// data, not to be anywhere near each other.
///
/// The relay has no idea what a channel or a participant is — it only
/// groups connections by the channel tag it reads out of each packet's
/// header and forwards bytes between them (see relay_server/server.js).
/// All of the presence/participant logic here is the same
/// periodic-HELLO-plus-timeout design as [WifiTransport], just carried
/// over a WebSocket instead of UDP multicast — which is also why joining
/// an internet channel needs no special "discovery" step: you're just
/// another phone making the same noise on the same channel tag.
///
/// Two things it adds on top of that:
/// - **Whisper.** [whisperTo] can be set to one participant's id so every
///   *subsequent* send (until cleared) is delivered only to them, for a
///   quick private aside without leaving the group channel.
/// - **Auto-reconnect.** Mobile connections drop for all sorts of
///   mundane reasons (a tunnel, a cell handoff, a free relay host cycling
///   idle connections) — see the README for why this app assumes the
///   relay connection *will* drop sometimes and reconnects on its own
///   rather than treating a drop as fatal.
class InternetRelayTransport implements Transport {
  final Uri relayUrl;

  InternetRelayTransport({required this.relayUrl});

  static const Duration helloInterval = Duration(seconds: 3);
  static const Duration participantTimeout = Duration(seconds: 9);
  static const Duration qualityFairAfter = Duration(seconds: 4);
  static const Duration qualityPoorAfter = Duration(seconds: 7);

  @override
  TransportMode get mode => TransportMode.internet;

  final _eventsController = StreamController<ChannelEvent>.broadcast();
  @override
  Stream<ChannelEvent> get events => _eventsController.stream;

  WebSocketChannel? _channel;
  StreamSubscription? _channelSub;
  Timer? _helloTimer;
  Timer? _pruneTimer;
  Timer? _reconnectTimer;
  int _reconnectAttempt = 0;
  bool _stopped = false;

  late int _channelTag;
  late String _displayName;
  late String _selfId;

  /// When set, every subsequent send goes only to this participant id
  /// instead of the whole channel. See the class doc.
  String? whisperTo;

  final Map<String, Participant> _participants = {};
  final Map<String, DateTime> _lastSeen = {};

  @override
  Future<void> start({
    required String channelName,
    required String displayName,
    required String selfId,
    String? connectTo,
  }) async {
    _channelTag = Packet.hashChannel(channelName);
    _displayName = displayName;
    _selfId = selfId;
    _stopped = false;
    _participants.clear();
    _lastSeen.clear();
    await _connect();
  }

  Future<void> _connect() async {
    _eventsController.add(TransportStatus('Connecting to the relay…'));
    try {
      final channel = WebSocketChannel.connect(relayUrl);
      await channel.ready;
      _channel = channel;
      _reconnectAttempt = 0;
      _channelSub = channel.stream.listen(
        _onMessage,
        onDone: _scheduleReconnect,
        onError: (_) => _scheduleReconnect(),
      );
      _sendHello();
      _helloTimer?.cancel();
      _helloTimer = Timer.periodic(helloInterval, (_) => _sendHello());
      _pruneTimer?.cancel();
      _pruneTimer = Timer.periodic(const Duration(seconds: 2), (_) => _pruneAndRefreshQuality());
      _eventsController.add(TransportStatus('Connected.'));
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_stopped) return;
    _channelSub?.cancel();
    _channel = null;
    _reconnectAttempt++;
    final delay = Duration(seconds: _reconnectAttempt.clamp(1, 10));
    _eventsController.add(TransportStatus('Connection lost — reconnecting in ${delay.inSeconds}s…'));
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, _connect);
  }

  void _onMessage(dynamic message) {
    if (message is! List<int>) return;
    final packet = Packet.decode(Uint8List.fromList(message));
    if (packet == null) return;
    if (packet.channelTag != _channelTag) return;
    if (packet.senderId == _selfId) return;

    switch (packet.type) {
      case PacketType.hello:
        _upsertParticipant(packet.senderId, utf8.decode(packet.payload, allowMalformed: true));
        break;
      case PacketType.bye:
        _removeParticipant(packet.senderId);
        break;
      case PacketType.talkStart:
        _lastSeen[packet.senderId] = DateTime.now();
        _setTalking(packet.senderId, true);
        break;
      case PacketType.talkEnd:
        _lastSeen[packet.senderId] = DateTime.now();
        _setTalking(packet.senderId, false);
        break;
      case PacketType.audio:
        _lastSeen[packet.senderId] = DateTime.now();
        _eventsController.add(AudioReceived(packet.senderId, packet.payload));
        break;
    }
  }

  void _upsertParticipant(String id, String name) {
    final existing = _participants[id];
    final isNew = existing == null;
    _participants[id] = Participant(
      id: id,
      name: name.isEmpty ? id : name,
      isTalking: existing?.isTalking ?? false,
      quality: ConnectionQuality.good,
    );
    _lastSeen[id] = DateTime.now();
    if (isNew) _emitParticipants();
  }

  void _removeParticipant(String id) {
    _lastSeen.remove(id);
    if (_participants.remove(id) != null) _emitParticipants();
  }

  void _setTalking(String id, bool talking) {
    final p = _participants[id];
    if (p == null) return;
    p.isTalking = talking;
    _eventsController.add(TalkStateChanged(id, talking));
    _emitParticipants();
  }

  void _pruneAndRefreshQuality() {
    final now = DateTime.now();
    final stale = _lastSeen.entries
        .where((e) => now.difference(e.value) > participantTimeout)
        .map((e) => e.key)
        .toList();
    for (final id in stale) {
      _participants.remove(id);
      _lastSeen.remove(id);
    }

    var changed = stale.isNotEmpty;
    for (final entry in _participants.entries) {
      final lastSeen = _lastSeen[entry.key];
      final age = lastSeen == null ? Duration.zero : now.difference(lastSeen);
      final quality = age > qualityPoorAfter
          ? ConnectionQuality.poor
          : age > qualityFairAfter
              ? ConnectionQuality.fair
              : ConnectionQuality.good;
      if (entry.value.quality != quality) {
        entry.value.quality = quality;
        changed = true;
      }
    }
    if (changed) _emitParticipants();
  }

  void _emitParticipants() {
    _eventsController.add(ParticipantsChanged(_participants.values.toList()));
  }

  void _sendHello() {
    _send(Packet(
      type: PacketType.hello,
      channelTag: _channelTag,
      senderId: _selfId,
      payload: Uint8List.fromList(utf8.encode(_displayName)),
    ));
  }

  void _send(Packet packet) {
    final channel = _channel;
    if (channel == null) return;
    final packetBytes = packet.encode();
    final target = whisperTo;
    Uint8List envelope;
    if (target == null) {
      envelope = Uint8List(1 + packetBytes.length);
      envelope[0] = 0x00;
      envelope.setRange(1, envelope.length, packetBytes);
    } else {
      envelope = Uint8List(9 + packetBytes.length);
      envelope[0] = 0x01;
      envelope.setRange(1, 9, ascii.encode(target));
      envelope.setRange(9, envelope.length, packetBytes);
    }
    try {
      channel.sink.add(envelope);
    } catch (_) {
      // A send that races a drop just gets dropped; the reconnect loop
      // (and the next periodic HELLO) will recover the session.
    }
  }

  @override
  void sendAudioChunk(Uint8List pcm16) {
    _send(Packet(type: PacketType.audio, channelTag: _channelTag, senderId: _selfId, payload: pcm16));
  }

  @override
  void sendTalkStart() {
    _send(Packet(type: PacketType.talkStart, channelTag: _channelTag, senderId: _selfId));
  }

  @override
  void sendTalkEnd() {
    _send(Packet(type: PacketType.talkEnd, channelTag: _channelTag, senderId: _selfId));
  }

  @override
  Future<void> stop() async {
    _stopped = true;
    _helloTimer?.cancel();
    _pruneTimer?.cancel();
    _reconnectTimer?.cancel();
    try {
      _send(Packet(type: PacketType.bye, channelTag: _channelTag, senderId: _selfId));
    } catch (_) {}
    await _channelSub?.cancel();
    try {
      await _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    await _eventsController.close();
  }
}
