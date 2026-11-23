import 'package:flutter/material.dart';

import '../models/ride_plan.dart';
import '../services/ride_plan_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/ride_plan_card.dart';

/// Live feed of shared ride plans — "people can share their bike riding
/// plans or other plans in which they can use the intercom or walkie
/// talkie feature". Reachable from the bottom nav; new plans come in from
/// the Share Ride Plan screen opened via the nav's center FAB.
class NearbyRidesTab extends StatefulWidget {
  const NearbyRidesTab({super.key});

  @override
  State<NearbyRidesTab> createState() => _NearbyRidesTabState();
}

class _NearbyRidesTabState extends State<NearbyRidesTab> {
  final _service = RidePlanService();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
            child: Text('Nearby Rides', style: AppTextStyles.headline),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(
              'Ride plans shared by the community.',
              style: AppTextStyles.bodyMuted,
            ),
          ),
          Expanded(
            child: StreamBuilder<List<RidePlan>>(
              stream: _service.watchRidePlans(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _EmptyState(
                    icon: Icons.cloud_off_rounded,
                    title: 'Can\'t load rides right now',
                    subtitle: 'Check your connection and the Firebase setup in the README.',
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.ink));
                }
                final plans = snapshot.data!;
                if (plans.isEmpty) {
                  return const _EmptyState(
                    icon: Icons.directions_bike_rounded,
                    title: 'No rides shared yet',
                    subtitle: 'Tap the + button below to plan the first one.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 140),
                  itemCount: plans.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, index) => RidePlanCard(plan: plans[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.title, required this.subtitle});

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: AppColors.slateLight),
            const SizedBox(height: 16),
            Text(title, style: AppTextStyles.title, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(subtitle, style: AppTextStyles.bodyMuted, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
