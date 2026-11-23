import 'package:cloud_firestore/cloud_firestore.dart';

/// Which comms feature a shared ride plan says the group will use.
enum RideCommsMode { walkieTalkie, intercom }

extension RideCommsModeLabel on RideCommsMode {
  String get label => switch (this) {
        RideCommsMode.walkieTalkie => 'Walkie Talkie',
        RideCommsMode.intercom => 'Intercom',
      };
}

/// A bike ride (or other group outing) someone has shared, so nearby riders
/// can see it and join using the stated comms mode.
class RidePlan {
  const RidePlan({
    required this.id,
    required this.hostName,
    required this.hostPhotoUrl,
    required this.title,
    required this.description,
    required this.meetingPoint,
    required this.rideTime,
    required this.mode,
    required this.createdAt,
  });

  final String id;
  final String hostName;
  final String? hostPhotoUrl;
  final String title;
  final String description;
  final String meetingPoint;
  final DateTime rideTime;
  final RideCommsMode mode;
  final DateTime createdAt;

  Map<String, dynamic> toMap() => {
        'hostName': hostName,
        'hostPhotoUrl': hostPhotoUrl,
        'title': title,
        'description': description,
        'meetingPoint': meetingPoint,
        'rideTime': Timestamp.fromDate(rideTime),
        'mode': mode.name,
        'createdAt': FieldValue.serverTimestamp(),
      };

  factory RidePlan.fromMap(String id, Map<String, dynamic> data) {
    final rideTimestamp = data['rideTime'];
    final createdTimestamp = data['createdAt'];
    return RidePlan(
      id: id,
      hostName: (data['hostName'] as String?) ?? 'Rider',
      hostPhotoUrl: data['hostPhotoUrl'] as String?,
      title: (data['title'] as String?) ?? 'Untitled ride',
      description: (data['description'] as String?) ?? '',
      meetingPoint: (data['meetingPoint'] as String?) ?? '',
      rideTime: rideTimestamp is Timestamp ? rideTimestamp.toDate() : DateTime.now(),
      mode: RideCommsMode.values.firstWhere(
        (m) => m.name == data['mode'],
        orElse: () => RideCommsMode.walkieTalkie,
      ),
      // Falls back to "now" for the brief window before the server
      // timestamp round-trips back down to a freshly-created doc.
      createdAt: createdTimestamp is Timestamp ? createdTimestamp.toDate() : DateTime.now(),
    );
  }
}
