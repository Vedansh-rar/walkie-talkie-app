/// How recently a participant has been heard from, over a transport where
/// that's meaningful to show (currently just the internet relay — local
/// WiFi/Bluetooth links are either connected or not, with nothing useful
/// to grade in between).
enum ConnectionQuality { good, fair, poor }

class Participant {
  final String id;
  final String name;
  bool isTalking;
  ConnectionQuality? quality;

  Participant({required this.id, required this.name, this.isTalking = false, this.quality});
}
