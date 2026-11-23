import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_classic_bluetooth/flutter_classic_bluetooth.dart';

import '../models/participant.dart';
import '../protocol/packet.dart';
import 'transport.dart';

/// Talks to other phones over Bluetooth Classic (RFCOMM/SPP).
///
/// Bluetooth has no equivalent of WiFi multicast — a connection is always
/// one-to-one — so one phone becomes the "host": every other phone opens
/// its own RFCOMM connection to it, and the host relays whatever it
/// receives from one client on to every other client (and plays it
/// locally), so the group behaves like a shared channel. A plain
/// two-phone walkie-talkie is just this same star with a single client.
///
/// Only Android exposes a Bluetooth Classic *server* socket to third-party
/// apps, so hosting (and therefore joining another phone) only works
/// between two Android phones — see the README for why iOS can't do this.
class BluetoothTransport implements Transport {
  static const String serviceName = 'WalkieTalkieChannel';
  // A fixed, app-specific UUID so this app's RFCOMM service doesn't get
  // confused with unrelated SPP devices (printers, OBD readers, etc.)
  // during discovery.
  static const String serviceUuid = '7a2f6b2e-9b36-4b7a-8e9a-3f0e8e1d2c4a';

  @override
  TransportMode get mode => TransportMode.bluetooth;

  final _eventsController = StreamController<ChannelEvent>.broadcast();
  @override
  Stream<ChannelEvent> get events => _eventsController.stream;

  final FlutterClassicBluetooth _bt = FlutterClassicBluetooth();

  dynamic _server; // BtcServer, once started as host
  dynamic _clientConnection; // BtcConnection, once connected as a client
  final Map<String, dynamic> _hostConnections = {}; // bluetooth address -> connection
  final Map<String, StreamSubscription<Uint8List>> _inputSubs = {};
  final Map<String, List<int>> _rxBuffers = {};
  final Map<String, String> _addressToSenderId = {};

  late int _channelTag;
  late String _displayName;
  late String _selfId;
  bool _isHost = false;

  final Map<String, Participant> _participants = {};

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

    if (connectTo == null) {
      await _startHost();
    } else {
      await _startClient(connectTo);
    }
  }

  Future<void> _startHost() async {
    _isHost = true;
    _eventsController.add(TransportStatus(
      'Waiting for others to connect over Bluetooth… make sure this phone stays discoverable.',
    ));
    _server = await _bt.startServer(serviceName: serviceName, uuid: serviceUuid, secure: false);
    _server.connections.listen((client) {
      final address = client.address as String;
      _hostConnections[address] = client;
      _inputSubs[address] = (client.input as Stream<Uint8List>).listen(
        (data) => _handleIncoming(data, relayFrom: address),
        onDone: () => _dropHostConnection(address),
        onError: (_) => _dropHostConnection(address),
      );
      // Only clients send an unprompted HELLO (see _startClient), so the
      // host has to announce itself whenever someone new connects —
      // otherwise a joining phone would never learn the host's name.
      _sendHello();
    });
  }

  Future<void> _startClient(String hostAddress) async {
    _isHost = false;
    _eventsController.add(TransportStatus('Connecting to $hostAddress over Bluetooth…'));
    final connection = await _bt.connect(address: hostAddress, uuid: serviceUuid, secure: false);
    _clientConnection = connection;
    (connection.input as Stream<Uint8List>).listen(
      (data) => _handleIncoming(data, relayFrom: null),
      onDone: () => _onHostDisconnected(),
      onError: (_) => _onHostDisconnected(),
    );
    _sendHello();
  }

  void _onHostDisconnected() {
    _participants.clear();
    _emitParticipants();
    _eventsController.add(TransportStatus('Disconnected from the host.'));
  }

  void _dropHostConnection(String address) {
    _hostConnections.remove(address);
    _inputSubs.remove(address)?.cancel();
    _rxBuffers.remove(address);
    final senderId = _addressToSenderId.remove(address);
    if (senderId != null) _removeParticipant(senderId);
  }

  /// RFCOMM is just a byte stream, so one read can contain part of a
  /// packet, exactly one packet, or several — we length-prefix every
  /// packet (a 4-byte little-endian length, then that many bytes) so we
  /// can split them back out reliably. UDP doesn't need this because each
  /// datagram already is exactly one packet.
  void _handleIncoming(Uint8List chunk, {String? relayFrom}) {
    final bufferKey = relayFrom ?? 'client';
    final buffer = _rxBuffers.putIfAbsent(bufferKey, () => <int>[]);
    buffer.addAll(chunk);

    while (true) {
      if (buffer.length < 4) break;
      final length = buffer[0] | (buffer[1] << 8) | (buffer[2] << 16) | (buffer[3] << 24);
      if (buffer.length < 4 + length) break;
      final frame = Uint8List.fromList(buffer.sublist(4, 4 + length));
      buffer.removeRange(0, 4 + length);
      _onPacketBytes(frame, relayFrom: relayFrom);
    }
  }

  void _onPacketBytes(Uint8List bytes, {String? relayFrom}) {
    final packet = Packet.decode(bytes);
    if (packet != null && packet.senderId != _selfId) {
      switch (packet.type) {
        case PacketType.hello:
          if (relayFrom != null) _addressToSenderId[relayFrom] = packet.senderId;
          _upsertParticipant(packet.senderId, utf8.decode(packet.payload, allowMalformed: true));
          break;
        case PacketType.bye:
          _removeParticipant(packet.senderId);
          break;
        case PacketType.talkStart:
          _setTalking(packet.senderId, true);
          break;
        case PacketType.talkEnd:
          _setTalking(packet.senderId, false);
          break;
        case PacketType.audio:
          _eventsController.add(AudioReceived(packet.senderId, packet.payload));
          break;
      }
    }

    // The host relays every packet it receives from one client on to every
    // *other* client, so the group behaves like one shared channel.
    if (_isHost && relayFrom != null) {
      for (final entry in _hostConnections.entries) {
        if (entry.key == relayFrom) continue;
        _writeFramed(entry.value, bytes);
      }
    }
  }

  void _upsertParticipant(String id, String name) {
    final existing = _participants[id];
    final isNew = existing == null;
    _participants[id] = Participant(id: id, name: name.isEmpty ? id : name, isTalking: existing?.isTalking ?? false);
    if (isNew) _emitParticipants();
  }

  void _removeParticipant(String id) {
    if (_participants.remove(id) != null) _emitParticipants();
  }

  void _setTalking(String id, bool talking) {
    final p = _participants[id];
    if (p == null) return;
    p.isTalking = talking;
    _eventsController.add(TalkStateChanged(id, talking));
    _emitParticipants();
  }

  void _emitParticipants() {
    _eventsController.add(ParticipantsChanged(_participants.values.toList()));
  }

  void _writeFramed(dynamic connection, Uint8List packetBytes) {
    final length = packetBytes.length;
    final framed = Uint8List(4 + length);
    framed[0] = length & 0xFF;
    framed[1] = (length >> 8) & 0xFF;
    framed[2] = (length >> 16) & 0xFF;
    framed[3] = (length >> 24) & 0xFF;
    framed.setRange(4, framed.length, packetBytes);
    connection.output.add(framed);
  }

  void _broadcast(Packet packet) {
    final bytes = packet.encode();
    if (_isHost) {
      for (final conn in _hostConnections.values) {
        _writeFramed(conn, bytes);
      }
    } else if (_clientConnection != null) {
      _writeFramed(_clientConnection, bytes);
    }
  }

  void _sendHello() {
    _broadcast(Packet(
      type: PacketType.hello,
      channelTag: _channelTag,
      senderId: _selfId,
      payload: Uint8List.fromList(utf8.encode(_displayName)),
    ));
  }

  @override
  void sendAudioChunk(Uint8List pcm16) {
    _broadcast(Packet(type: PacketType.audio, channelTag: _channelTag, senderId: _selfId, payload: pcm16));
  }

  @override
  void sendTalkStart() {
    _broadcast(Packet(type: PacketType.talkStart, channelTag: _channelTag, senderId: _selfId));
  }

  @override
  void sendTalkEnd() {
    _broadcast(Packet(type: PacketType.talkEnd, channelTag: _channelTag, senderId: _selfId));
  }

  @override
  Future<void> stop() async {
    try {
      _broadcast(Packet(type: PacketType.bye, channelTag: _channelTag, senderId: _selfId));
    } catch (_) {}
    for (final sub in _inputSubs.values) {
      await sub.cancel();
    }
    _inputSubs.clear();
    for (final conn in _hostConnections.values) {
      try {
        await conn.close();
      } catch (_) {}
    }
    _hostConnections.clear();
    try {
      await _server?.close();
    } catch (_) {}
    _server = null;
    try {
      await _clientConnection?.close();
    } catch (_) {}
    _clientConnection = null;
    await _eventsController.close();
  }

  /// Used by the Bluetooth setup screen before any transport exists, to
  /// check/request permission ahead of scanning or hosting.
  static Future<bool> ensurePermissions() async {
    final bt = FlutterClassicBluetooth();
    var status = await bt.checkPermissions();
    if (status == BtcPermissionStatus.denied) {
      status = await bt.requestPermissions();
    }
    return status == BtcPermissionStatus.granted || status == BtcPermissionStatus.notRequired;
  }
}
