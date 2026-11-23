import 'dart:math';
import 'dart:typed_data';

/// Decides, from the mic audio alone, whether someone is currently
/// speaking — this is what makes Intercom mode hands-free: the rider never
/// touches a button, they just talk.
///
/// This is also where Intercom mode's battery/data saving actually comes
/// from. The microphone itself has to keep sampling continuously either
/// way (that's unavoidable if you want to detect when someone starts
/// talking) — but sampling the mic is cheap. What's expensive is the
/// radio: sending audio over WiFi or, especially, cellular data. VOX
/// means that radio only turns on for the fraction of a ride someone is
/// actually mid-sentence, instead of the whole ride.
///
/// The algorithm is the classic simple one: track a slowly-adapting noise
/// floor from quiet periods, flag a chunk as "loud" if its energy clears
/// that floor by a sensitivity-controlled margin, and keep transmitting
/// for a short hangover period after the last loud chunk so words don't
/// get clipped at the end of a sentence.
class VoiceActivityDetector {
  /// 0.0 (least sensitive — needs a raised voice) to 1.0 (most sensitive —
  /// picks up a whisper, but more prone to false triggers from wind/engine
  /// noise).
  final double sensitivity;
  final Duration hangover;

  /// Below this RMS, audio is always treated as silence regardless of
  /// sensitivity — otherwise, in a dead-quiet room, the adapted noise
  /// floor could approach zero and make the detector trigger on hiss.
  static const double _absoluteFloor = 150;

  double _noiseFloor = 300;
  bool _isActive = false;
  DateTime? _lastLoud;

  VoiceActivityDetector({this.sensitivity = 0.5, this.hangover = const Duration(milliseconds: 600)});

  /// Feed one PCM16LE chunk; returns whether voice is considered active
  /// right now (including the hangover tail after the last loud moment).
  bool process(Uint8List pcm16Bytes) {
    final rms = _rms(pcm16Bytes);

    if (!_isActive) {
      // Only adapt the floor while quiet, so a sustained shout doesn't
      // drag the floor up and make the detector deafen itself mid-sentence.
      _noiseFloor = _noiseFloor * 0.98 + rms * 0.02;
    }

    // sensitivity 0 -> need ~3.5x the noise floor; sensitivity 1 -> ~1x.
    final threshold = max(_noiseFloor * (3.5 - sensitivity * 2.5), _absoluteFloor);
    final loudNow = rms > threshold;

    final now = DateTime.now();
    if (loudNow) {
      _lastLoud = now;
      _isActive = true;
    } else if (_isActive && _lastLoud != null && now.difference(_lastLoud!) > hangover) {
      _isActive = false;
    }
    return _isActive;
  }

  double _rms(Uint8List pcm16Bytes) {
    final evenLength = pcm16Bytes.length - (pcm16Bytes.length % 2);
    if (evenLength <= 0) return 0;
    final samples = pcm16Bytes.buffer.asInt16List(pcm16Bytes.offsetInBytes, evenLength ~/ 2);
    if (samples.isEmpty) return 0;
    var sumSquares = 0.0;
    for (final s in samples) {
      sumSquares += s * s;
    }
    return sqrt(sumSquares / samples.length);
  }
}
