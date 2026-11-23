import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_text_styles.dart';
import '../widgets/greeting_header.dart';
import '../widgets/mode_card.dart';
import 'intercom_setup_screen.dart';
import 'walkie_talkie_setup_screen.dart';

/// The Home tab: a greeting header and the two big mode-choice cards from
/// the Figma "home" frame — kept as the two large, high-contrast options
/// per the brief ("gives user 2 choices: walkie talkie or intercom").
class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final name = user?.displayName?.trim().isNotEmpty == true ? user!.displayName! : 'Rider';

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 140),
        children: [
          GreetingHeader(name: name, photoUrl: user?.photoURL),
          const SizedBox(height: 28),
          Text('Choose your mode', style: AppTextStyles.headline),
          const SizedBox(height: 6),
          Text(
            'Both work hands-free once you\'re moving.',
            style: AppTextStyles.bodyMuted,
          ),
          const SizedBox(height: 20),
          _AnimatedEntrance(
            delay: Duration.zero,
            child: ModeCard(
              title: 'Walkie Talkie\nMode',
              subtitle: 'Push-to-talk over WiFi or Bluetooth — no internet needed.',
              icon: Icons.settings_input_antenna_rounded,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const WalkieTalkieSetupScreen()),
              ),
            ),
          ),
          const SizedBox(height: 18),
          _AnimatedEntrance(
            delay: const Duration(milliseconds: 90),
            child: ModeCard(
              title: 'Inter-Com\nMode',
              subtitle: 'Hands-free over mobile data — just talk, any distance.',
              icon: Icons.hearing_rounded,
              accent: true,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const IntercomSetupScreen()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small fade+slide-up entrance so the two mode cards settle into place
/// instead of just appearing — part of the "motion and fluid movements"
/// pass applied across the redesign.
class _AnimatedEntrance extends StatefulWidget {
  const _AnimatedEntrance({required this.child, required this.delay});

  final Widget child;
  final Duration delay;

  @override
  State<_AnimatedEntrance> createState() => _AnimatedEntranceState();
}

class _AnimatedEntranceState extends State<_AnimatedEntrance> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(curved),
        child: widget.child,
      ),
    );
  }
}
