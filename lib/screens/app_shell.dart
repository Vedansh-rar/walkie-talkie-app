import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/rydio_bottom_nav.dart';
import 'home_tab.dart';
import 'nearby_rides_tab.dart';
import 'profile_tab.dart';
import 'share_ride_plan_screen.dart';

/// The main app frame once signed in: exactly 3 real tabs — Home, Nearby
/// Rides, Profile — per the brief, with the Figma nav's center notch
/// repurposed as a single FAB action ("Share Ride Plan") rather than a
/// 4th tab, since sharing a plan is an action you take, not a place you
/// browse to and stay.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const _tabs = [HomeTab(), NearbyRidesTab(), ProfileTab()];

  void _openShareRidePlan() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ShareRidePlanScreen(), fullscreenDialog: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      extendBody: true,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        child: KeyedSubtree(
          key: ValueKey(_index),
          child: _tabs[_index],
        ),
        transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
      ),
      bottomNavigationBar: RydioBottomNav(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        onFabTap: _openShareRidePlan,
      ),
    );
  }
}
