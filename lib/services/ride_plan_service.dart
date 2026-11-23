import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/ride_plan.dart';

/// Thin wrapper around the `ride_plans` Firestore collection so the UI
/// never touches Firestore APIs directly.
class RidePlanService {
  RidePlanService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _db.collection('ride_plans');

  /// Newest-first live feed of every shared ride plan.
  Stream<List<RidePlan>> watchRidePlans() {
    return _collection
        .orderBy('rideTime', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RidePlan.fromMap(doc.id, doc.data()))
            .toList());
  }

  Future<void> share({
    required String hostName,
    String? hostPhotoUrl,
    required String title,
    required String description,
    required String meetingPoint,
    required DateTime rideTime,
    required RideCommsMode mode,
  }) {
    final plan = RidePlan(
      id: '',
      hostName: hostName,
      hostPhotoUrl: hostPhotoUrl,
      title: title,
      description: description,
      meetingPoint: meetingPoint,
      rideTime: rideTime,
      mode: mode,
      createdAt: DateTime.now(),
    );
    return _collection.add(plan.toMap());
  }
}
