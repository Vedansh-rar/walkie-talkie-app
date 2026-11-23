import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import 'package:flutter_pcm_sound/flutter_pcm_sound.dart';

/// Plays incoming PCM16 mono audio as it arrives.
///
/// flutter_pcm_sound is "push" friendly: calling feed() both starts and
/// continues playback. For WiFi and Bluetooth (negligible, steady
/// latency) we feed each chunk the moment it arrives. For the internet
/// relay — where packets can arrive in little bursts a cell network
/// jitter — a non-zero [playoutDelay] instead holds each chunk for a
/// fixed, short delay before feeding it, on a steady clock. That trades a
/// small, constant bit of extra latency for smoothing out the arrival
/// jitter, which matters a lot more than it does on a LAN or a direct
/// Bluetooth link.
class AudioPlayer {
  static const int sampleRate = 16000;

  final Duration playoutDelay;
  bool _ready = false;

  final Queue<_Scheduled> _queue = Queue<_Scheduled>();
  Timer? _drainTimer;

  AudioPlayer({this.playoutDelay = Duration.zero});

  Future<void> init() async {
    if (_ready) return;
    await FlutterPcmSound.setup(sampleRate: sampleRate, channelCount: 1);
    await FlutterPcmSound.setFeedThreshold(sampleRate ~/ 10); // ~100ms buffer
    // We never rely on being asked for more data (see above), so this
    // callback only exists to satisfy the plugin's setup — it has nothing
    // to do.
    FlutterPcmSound.setFeedCallback((_) {});
    _ready = true;

    if (playoutDelay > Duration.zero) {
      _drainTimer = Timer.periodic(const Duration(milliseconds: 20), (_) => _drainDue());
    }
  }

  /// Call with the raw PCM16LE bytes from a received audio packet.
  void play(Uint8List pcm16Bytes) {
    if (!_ready) return;
    if (playoutDelay == Duration.zero) {
      _feed(pcm16Bytes);
      return;
    }
    _queue.add(_Scheduled(DateTime.now().add(playoutDelay), pcm16Bytes));
  }

  void _drainDue() {
    final now = DateTime.now();
    while (_queue.isNotEmpty && !_queue.first.releaseAt.isAfter(now)) {
      _feed(_queue.removeFirst().bytes);
    }
  }

  void _feed(Uint8List pcm16Bytes) {
    final evenLength = pcm16Bytes.length - (pcm16Bytes.length % 2);
    if (evenLength <= 0) return;
    final samples = pcm16Bytes.buffer.asInt16List(pcm16Bytes.offsetInBytes, evenLength ~/ 2).toList();
    FlutterPcmSound.feed(PcmArrayInt16.fromList(samples));
  }

  /// Drops anything queued but not yet handed to the native player
  /// (used for deafen — see [PttController.setDeafened]). There's no
  /// "flush what's already playing" call in this plugin's API, so the
  /// last ~100ms already fed before this is called will still be heard;
  /// this only stops anything after that point.
  void clear() {
    _queue.clear();
  }

  Future<void> dispose() async {
    _drainTimer?.cancel();
    _drainTimer = null;
    _queue.clear();
    if (_ready) {
      await FlutterPcmSound.release();
      _ready = false;
    }
  }
}

class _Scheduled {
  final DateTime releaseAt;
  final Uint8List bytes;
  _Scheduled(this.releaseAt, this.bytes);
}
