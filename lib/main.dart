import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (error) {
    // Falls through to the placeholder credentials in firebase_options.dart
    // (no real Firebase project configured yet) — the login screen handles
    // this gracefully rather than the app refusing to start. See the
    // README's Firebase setup section.
    debugPrint('Firebase did not initialize (placeholder config?): $error');
  }
  runApp(const WalkieTalkieApp());
}
