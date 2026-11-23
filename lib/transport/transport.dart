import 'dart:typed_data';

import '../models/participant.dart';

enum TransportMode { wifi, bluetooth, internet }

/// Something a transport can report to the rest of the app. Kept as a tiny
/// sealed-style hierarchy rather than a callback per concern, so a new
/// transport only has to produce these four kinds of event.
sealed class ChannelEvent {}

class ParticipantsChanged extends ChannelEvent {
  final List<Participant> participants;
  ParticipantsChanged(this.participants);
}

class AudioReceived extends ChannelEvent {
  final String senderId;
  final Uint8List pcm16;
  AudioReceived(this.senderId, this.pcm16);
}

class TalkStateChanged extends ChannelEvent {
  final String senderId;
  final bool isTalking;
  TalkStateChanged(this.senderId, this.isTalking);
}

class TransportStatus extends ChannelEvent {
  final String message;
  TransportStatus(this.message);
}

/// A way to reach the other phones on a channel. There are two
/// implementations — [WifiTransport] (local-network UDP multicast) and
/// [BluetoothTransport] (Bluetooth Classic RFCOMM) — and the rest of the
/// app (see PttController) talks to whichever one is active only through
/// this interface.
abstract class Transport {
  TransportMode get mode;
  Stream<ChannelEvent> get events;

  /// Joins (or creates) a channel.
  ///
  /// [connectTo] is only meaningful for Bluetooth: leave it null to host
  /// the channel (others connect to this phone), or pass the host's
  /// Bluetooth address to join an existing one. WiFi ignores it — every
  /// phone on the same channel name is simply a peer.
  Future<void> start({
    required String channelName,
    required String displayName,
    required String selfId,
    String? connectTo,
  });

  void sendAudioChunk(Uint8List pcm16);
  void sendTalkStart();
  void sendTalkEnd();
  Future<void> stop();
}
