import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';

/// Starts Firebase once. The returned future never throws and completes
/// within ~10s, so callers (the splash screen) can safely await it.
Future<void>? _initFuture;

Future<void> ensureFirebaseInitialized() {
  return _initFuture ??= () async {
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)
          .timeout(const Duration(seconds: 10));
    } catch (error) {
      debugPrint('Firebase did not initialize: $error');
    }
  }();
}
