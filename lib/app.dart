import 'package:flutter/material.dart';

import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';

class WalkieTalkieApp extends StatelessWidget {
  const WalkieTalkieApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rydio',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const SplashScreen(),
    );
  }
}
