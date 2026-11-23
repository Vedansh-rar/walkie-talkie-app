import 'dart:async';
import 'dart:typed_data';

import 'package:record/record.dart';

/// Captures the microphone as a stream of raw 16-bit PCM chunks, already
/// split so each chunk is small enough to fit in one UDP packet / one
/// Bluetooth frame without the caller having to think about it.
class AudioCapture {
  static const int sampleRate = 16000;
  static const int numChannels = 1;

  /// Keep each chunk comfortably under a typical ~1500 byte network MTU
  /// once our own 13-byte packet header is added.
  static const int maxChunkBytes = 960;

  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _sub;

  bool get isRecording => _sub != null;

  Future<bool> hasPermission() => _recorder.hasPermission();

  /// Starts streaming mic audio; [onChunk] is called with PCM16LE chunks of
  /// at most [maxChunkBytes] bytes, each an even number of bytes so a
  /// 16-bit sample is never split across two chunks.
  Future<void> start(void Function(Uint8List chunk) onChunk) async {
    if (_sub != null) return;
    final stream = await _recorder.startStream(const RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: sampleRate,
      numChannels: numChannels,
      echoCancel: true,
      noiseSuppress: true,
    ));
    _sub = stream.listen((data) {
      for (final piece in _chunk(data, maxChunkBytes)) {
        onChunk(piece);
      }
    });
  }

  Future<void> stop() async {
    if (_sub == null) return;
    await _sub?.cancel();
    _sub = null;
    await _recorder.stop();
  }

  Future<void> dispose() async {
    await stop();
    await _recorder.dispose();
  }

  static Iterable<Uint8List> _chunk(Uint8List data, int maxBytes) sync* {
    final evenMax = maxBytes - (maxBytes % 2);
    var offset = 0;
    while (offset < data.length) {
      final end = (offset + evenMax < data.length) ? offset + evenMax : data.length;
      yield data.sublist(offset, end);
      offset = end;
    }
  }
}
