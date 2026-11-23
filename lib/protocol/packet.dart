import 'dart:convert';
import 'dart:typed_data';

/// The kinds of message that can travel over either transport.
enum PacketType { hello, bye, talkStart, talkEnd, audio }

int _typeToByte(PacketType t) => switch (t) {
      PacketType.hello => 1,
      PacketType.bye => 2,
      PacketType.talkStart => 3,
      PacketType.talkEnd => 4,
      PacketType.audio => 5,
    };

PacketType? _byteToType(int b) => switch (b) {
      1 => PacketType.hello,
      2 => PacketType.bye,
      3 => PacketType.talkStart,
      4 => PacketType.talkEnd,
      5 => PacketType.audio,
      _ => null,
    };

/// The single wire format shared by the WiFi and Bluetooth transports, so
/// the rest of the app doesn't need to know which one is in use.
///
/// Layout (little-endian):
/// ```
/// [0]      packet type (one byte)
/// [1..4]   channel tag (uint32) — lets the WiFi transport tell channels
///          apart on the one shared multicast group. Bluetooth connections
///          are already scoped to a single channel, so this is just carried
///          along unused there.
/// [5..12]  sender id — exactly 8 ASCII characters
/// [13..]   payload — the display name for HELLO, raw PCM16LE audio for
///          AUDIO, empty for everything else
/// ```
class Packet {
  static const int headerLength = 13;

  final PacketType type;
  final int channelTag;
  final String senderId;
  final Uint8List payload;

  Packet({
    required this.type,
    required this.channelTag,
    required this.senderId,
    Uint8List? payload,
  }) : payload = payload ?? Uint8List(0);

  Uint8List encode() {
    assert(senderId.length == 8, 'senderId must be exactly 8 ASCII characters, got "$senderId"');
    final out = Uint8List(headerLength + payload.length);
    final bd = ByteData.view(out.buffer);
    bd.setUint8(0, _typeToByte(type));
    bd.setUint32(1, channelTag, Endian.little);
    out.setRange(5, 13, ascii.encode(senderId));
    out.setRange(13, out.length, payload);
    return out;
  }

  static Packet? decode(Uint8List bytes) {
    if (bytes.length < headerLength) return null;
    final type = _byteToType(bytes[0]);
    if (type == null) return null;
    final bd = ByteData.view(bytes.buffer, bytes.offsetInBytes);
    final channelTag = bd.getUint32(1, Endian.little);
    final senderId = ascii.decode(bytes.sublist(5, 13));
    final payload = bytes.sublist(headerLength);
    return Packet(type: type, channelTag: channelTag, senderId: senderId, payload: payload);
  }

  /// A simple FNV-1a 32-bit hash, just used to tell channel names apart —
  /// it never needs to be reversed, so collisions between unrelated channel
  /// names are an acceptable (and very unlikely) cosmetic bug, not a
  /// security concern.
  static int hashChannel(String channelName) {
    var hash = 0x811c9dc5;
    for (final byte in utf8.encode(channelName.trim().toLowerCase())) {
      hash ^= byte;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash;
  }
}
