import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_multicast_lock/flutter_multicast_lock.dart';

import '../models/participant.dart';
import '../protocol/packet.dart';
import 'transport.dart';

/// Talks to every other phone on the same WiFi network (or hotspot) using
/// UDP multicast, on a fixed address/port shared by the whole app.
///
/// There's no server: every phone sends to the multicast group and every
/// phone listens to it, so "the channel" is really just a filter — each
/// packet carries a hash of its channel name, and we drop anything that
/// doesn't match. This is what makes one-to-one and group both "just work"
/// with the same code: a group is simply more than one other phone
/// listening on the same channel name.
class WifiTransport implements Transport {
  static const String multicastAddress = '239.255.43.21';
  static const int port = 45454;
  static const Duration helloInterval = Duration(seconds: 3);
  static const Duration participantTimeout = Duration(seconds: 9);

  @override
  TransportMode get mode => TransportMode.wifi;

  final _eventsController = StreamController<ChannelEvent>.broadcast();
  @override
  Stream<ChannelEvent> get events => _eventsController.stream;

  RawDatagramSocket? _socket;
  Timer? _helloTimer;
  Timer? _pruneTimer;
  final _lock = FlutterMulticastLock();

  late int _channelTag;
  late String _displayName;
  late String _selfId;

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
    _participants.clear();
    _lastSeen.clear();

    try {
      await _lock.acquireMulticastLock();
    } catch (_) {
      // No-op on platforms without a multicast lock (iOS, desktop). On
      // Android, if this genuinely fails, incoming packets just won't
      // arrive — which shows up to the user as "no one found" rather than
      // a crash.
    }

    try {
      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        port,
        reuseAddress: true,
        reusePort: true,
      );
    } catch (_) {
      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        port,
        reuseAddress: true,
      );
    }
    _socket!.broadcastEnabled = true;
    _socket!.multicastHops = 1; // stay on the local network
    _socket!.joinMulticast(InternetAddress(multicastAddress));
    _socket!.listen(_onSocketEvent);

    _sendHello();
    _helloTimer = Timer.periodic(helloInterval, (_) => _sendHello());
    _pruneTimer = Timer.periodic(const Duration(seconds: 2), (_) => _pruneStale());

    _eventsController.add(TransportStatus('Listening on your WiFi network for "$channelName"…'));
  }

  void _onSocketEvent(RawSocketEvent event) {
    if (event != RawSocketEvent.read) return;
    final socket = _socket;
    if (socket == null) return;
    Datagram? datagram;
    while ((datagram = socket.receive()) != null) {
      _handleDatagram(datagram!.data);
    }
  }

  void _handleDatagram(Uint8List data) {
    final packet = Packet.decode(data);
    if (packet == null) return;
    if (packet.channelTag != _channelTag) return; // a different channel
    if (packet.senderId == _selfId) return; // our own packet looping back

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
    _participants[id] = Participant(id: id, name: name.isEmpty ? id : name, isTalking: existing?.isTalking ?? false);
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

  void _pruneStale() {
    final cutoff = DateTime.now().subtract(participantTimeout);
    final stale = _lastSeen.entries.where((e) => e.value.isBefore(cutoff)).map((e) => e.key).toList();
    if (stale.isEmpty) return;
    for (final id in stale) {
      _participants.remove(id);
      _lastSeen.remove(id);
    }
    _emitParticipants();
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
    final socket = _socket;
    if (socket == null) return;
    socket.send(packet.encode(), InternetAddress(multicastAddress), port);
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
    _helloTimer?.cancel();
    _pruneTimer?.cancel();
    try {
      _send(Packet(type: PacketType.bye, channelTag: _channelTag, senderId: _selfId));
    } catch (_) {}
    _socket?.close();
    _socket = null;
    try {
      await _lock.releaseMulticastLock();
    } catch (_) {}
    await _eventsController.close();
  }
}
