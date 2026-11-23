import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'app_shell.dart';
import 'login_screen.dart';

/// The startup screen: the RYDIO wordmark over the black-to-white gradient
/// from the Figma "Splash screen" frame, with the hand-drawn rider
/// illustration riding up into place. Exact Figma tokens: 35px frame
/// corner radius, gradient flat-black until 42.5%, flat-white after 80.8%,
/// wordmark in "Merge One".
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _wordmarkFade;
  late final Animation<Offset> _riderSlide;
  late final Animation<double> _riderFade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _wordmarkFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    );
    _riderFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.25, 0.85, curve: Curves.easeOut),
    );
    _riderSlide = Tween<Offset>(begin: const Offset(0.15, 0), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.25, 0.85, curve: Curves.easeOutCubic)),
    );
    _controller.forward();
    _scheduleNavigation();
  }

  Future<void> _scheduleNavigation() async {
    await Future.delayed(const Duration(milliseconds: 2200));
    if (!mounted) return;
    final loggedIn = FirebaseAuth.instance.currentUser != null;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => loggedIn ? const AppShell() : const LoginScreen(),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ClipRRect(
        borderRadius: BorderRadius.circular(0),
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: AppColors.gradientSplash,
              stops: AppColors.gradientSplashStops,
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 90),
                FadeTransition(
                  opacity: _wordmarkFade,
                  child: Text('RYDIO', style: AppTextStyles.wordmark(size: 64)),
                ),
                const Spacer(),
                FadeTransition(
                  opacity: _riderFade,
                  child: SlideTransition(
                    position: _riderSlide,
                    child: Hero(
                      tag: 'rider-illustration',
                      child: Image.asset(
                        'assets/images/rider.png',
                        width: 340,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 64),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
