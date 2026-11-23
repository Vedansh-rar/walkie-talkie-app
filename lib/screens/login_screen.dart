import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/pill_button.dart';
import 'app_shell.dart';

/// The Google Sign-In screen — "black and white theme and walkie talkie
/// and biking illustrations" per the designer's own comment on the
/// moodboard onboarding layout, adapted here to Rydio's own copy and the
/// biker illustration already pulled from the Figma splash frame.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _authService = AuthService();
  late final AnimationController _controller;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideUp;
  bool _signingIn = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideUp = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _continueWithGoogle() async {
    setState(() => _signingIn = true);
    try {
      final user = await _authService.signInWithGoogle();
      if (!mounted) return;
      if (user == null) {
        setState(() => _signingIn = false);
        return;
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AppShell()),
      );
    } on GoogleSignInNotConfigured {
      if (!mounted) return;
      setState(() => _signingIn = false);
      _showNotConfiguredSheet();
    } catch (error) {
      if (!mounted) return;
      setState(() => _signingIn = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sign-in failed: $error')),
      );
    }
  }

  void _showNotConfiguredSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(28, 28, 28, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Google Sign-In isn\'t set up yet', style: AppTextStyles.headline),
            const SizedBox(height: 12),
            Text(
              'This build doesn\'t have a Firebase project wired up, so there\'s no real '
              'Google account to sign in with. See the README\'s "Google Sign-In setup" '
              'section for the few steps needed, or skip sign-in for now.',
              style: AppTextStyles.bodyMuted,
            ),
            const SizedBox(height: 24),
            PillButton(
              label: 'Skip for now',
              style: PillButtonStyle.outline,
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const AppShell()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 20, 28, 28),
          child: FadeTransition(
            opacity: _fadeIn,
            child: SlideTransition(
              position: _slideUp,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('RYDIO', style: AppTextStyles.wordmark(size: 28)),
                  const Spacer(),
                  Center(
                    child: Hero(
                      tag: 'rider-illustration',
                      child: Image.asset(
                        'assets/images/rider.png',
                        width: 280,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(height: 36),
                  Text(
                    'Ride together.\nTalk together.',
                    style: AppTextStyles.display.copyWith(color: AppColors.paper),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Sign in to sync your profile, share ride plans, and jump straight '
                    'into Walkie Talkie or Intercom mode.',
                    style: AppTextStyles.body.copyWith(color: AppColors.slateLight),
                  ),
                  const SizedBox(height: 32),
                  PillButton(
                    label: 'Continue with Google',
                    style: PillButtonStyle.light,
                    icon: const Icon(Icons.login_rounded, color: AppColors.ink, size: 20),
                    loading: _signingIn,
                    onPressed: _continueWithGoogle,
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      'By continuing you agree to ride safe and keep the channel clear.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyMuted.copyWith(color: AppColors.slate),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
