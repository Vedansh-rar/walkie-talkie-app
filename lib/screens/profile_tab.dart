import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'login_screen.dart';

/// The Profile tab: avatar/name/email pulled straight from the Google
/// account (no manual profile step, per the brief), plus settings.
class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  Future<void> _signOut(BuildContext context) async {
    await AuthService().signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = currentUserOrNull();
    final name = user?.displayName?.trim().isNotEmpty == true ? user!.displayName! : 'Rider';
    final email = user?.email ?? 'Not signed in with Google';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 140),
        children: [
          Center(
            child: Column(
              children: [
                Container(
                  width: 96,
                  height: 96,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: AppColors.cloud,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.mist, width: 1.6),
                  ),
                  child: (user?.photoURL != null && user!.photoURL!.isNotEmpty)
                      ? Image.network(
                          user.photoURL!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _InitialAvatar(initial: initial),
                        )
                      : _InitialAvatar(initial: initial),
                ),
                const SizedBox(height: 16),
                Text(name, style: AppTextStyles.headline),
                const SizedBox(height: 4),
                Text(email, style: AppTextStyles.bodyMuted),
              ],
            ),
          ),
          const SizedBox(height: 32),
          _StatsRow(),
          const SizedBox(height: 32),
          Text('Settings', style: AppTextStyles.title),
          const SizedBox(height: 12),
          _SettingsTile(
            icon: Icons.info_outline_rounded,
            label: 'About Rydio',
            onTap: () => showAboutDialog(
              context: context,
              applicationName: 'Rydio',
              applicationVersion: '1.0.0',
            ),
          ),
          const SizedBox(height: 10),
          _SettingsTile(
            icon: Icons.logout_rounded,
            label: 'Sign out',
            destructive: true,
            onTap: () => _signOut(context),
          ),
        ],
      ),
    );
  }
}

class _InitialAvatar extends StatelessWidget {
  const _InitialAvatar({required this.initial});

  final String initial;

  @override
  Widget build(BuildContext context) {
    return Center(child: Text(initial, style: AppTextStyles.headline));
  }
}

class _StatsRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Expanded(child: _StatCard(label: 'Rides shared', value: '—')),
        SizedBox(width: 14),
        Expanded(child: _StatCard(label: 'Rides joined', value: '—')),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(color: AppColors.cloud, borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          Text(value, style: AppTextStyles.display.copyWith(fontSize: 24)),
          const SizedBox(height: 4),
          Text(label, style: AppTextStyles.bodyMuted),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? AppColors.accent : AppColors.ink;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(color: AppColors.cloud, borderRadius: BorderRadius.circular(18)),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 14),
            Expanded(child: Text(label, style: AppTextStyles.body.copyWith(color: color))),
            const Icon(Icons.chevron_right_rounded, color: AppColors.slate),
          ],
        ),
      ),
    );
  }
}
