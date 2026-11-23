import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'services/firebase_boot.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // In release builds a build-time exception otherwise paints a blank
  // screen; show the message instead so problems are diagnosable on-device.
  ErrorWidget.builder = (details) => Material(
        color: Colors.white,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Text(
                'Something went wrong:\n${details.exceptionAsString()}',
                style: const TextStyle(color: Colors.black, fontSize: 13),
              ),
            ),
          ),
        ),
      );

  // Show the first frame right away; Firebase starts in the background so a
  // slow or failing init can never leave the app stuck on a blank screen.
  runApp(const WalkieTalkieApp());
  unawaited(ensureFirebaseInitialized());
}
