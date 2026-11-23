import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/ride_plan.dart';
import '../services/ride_plan_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/pill_button.dart';

/// Opened from the bottom nav's center FAB. Lets a rider post a ride plan
/// — a title, what it's about, where/when to meet, and which comms mode
/// the group should use — to the shared Nearby Rides feed.
class ShareRidePlanScreen extends StatefulWidget {
  const ShareRidePlanScreen({super.key});

  @override
  State<ShareRidePlanScreen> createState() => _ShareRidePlanScreenState();
}

class _ShareRidePlanScreenState extends State<ShareRidePlanScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _meetingPointController = TextEditingController();
  final _service = RidePlanService();

  DateTime _rideTime = DateTime.now().add(const Duration(hours: 2));
  RideCommsMode _mode = RideCommsMode.walkieTalkie;
  bool _sharing = false;
  bool _shared = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _meetingPointController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _rideTime,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_rideTime),
    );
    if (time == null) return;
    setState(() {
      _rideTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _share() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _sharing = true);
    final user = FirebaseAuth.instance.currentUser;
    try {
      await _service.share(
        hostName: user?.displayName?.trim().isNotEmpty == true ? user!.displayName! : 'Rider',
        hostPhotoUrl: user?.photoURL,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        meetingPoint: _meetingPointController.text.trim(),
        rideTime: _rideTime,
        mode: _mode,
      );
      if (!mounted) return;
      setState(() {
        _sharing = false;
        _shared = true;
      });
      await Future.delayed(const Duration(milliseconds: 900));
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() => _sharing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Couldn\'t share this ride: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_shared) {
      return Scaffold(
        body: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 420),
            curve: Curves.elasticOut,
            builder: (context, value, child) => Transform.scale(scale: value, child: child),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
                  child: const Icon(Icons.check_rounded, color: Colors.white, size: 44),
                ),
                const SizedBox(height: 20),
                Text('Ride shared!', style: AppTextStyles.headline),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Share a Ride Plan')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Ride title'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Give your ride a title' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Route, pace, what to bring…',
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _meetingPointController,
              decoration: const InputDecoration(labelText: 'Meeting point'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Where should people meet?' : null,
            ),
            const SizedBox(height: 14),
            _DateTimeTile(rideTime: _rideTime, onTap: _pickDateTime),
            const SizedBox(height: 20),
            Text('Comms mode for this ride', style: AppTextStyles.title),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _ModeChip(
                    label: 'Walkie Talkie',
                    icon: Icons.settings_input_antenna_rounded,
                    selected: _mode == RideCommsMode.walkieTalkie,
                    onTap: () => setState(() => _mode = RideCommsMode.walkieTalkie),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ModeChip(
                    label: 'Intercom',
                    icon: Icons.hearing_rounded,
                    selected: _mode == RideCommsMode.intercom,
                    onTap: () => setState(() => _mode = RideCommsMode.intercom),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            PillButton(
              label: 'Share with nearby riders',
              loading: _sharing,
              onPressed: _share,
            ),
          ],
        ),
      ),
    );
  }
}

class _DateTimeTile extends StatelessWidget {
  const _DateTimeTile({required this.rideTime, required this.onTap});

  final DateTime rideTime;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(color: AppColors.cloud, borderRadius: BorderRadius.circular(18)),
        child: Row(
          children: [
            const Icon(Icons.event_rounded, color: AppColors.ink),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                DateFormat('EEE, MMM d · h:mm a').format(rideTime),
                style: AppTextStyles.body,
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.slate),
          ],
        ),
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: selected ? AppColors.ink : AppColors.cloud,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? AppColors.paper : AppColors.ink),
            const SizedBox(height: 6),
            Text(
              label,
              style: AppTextStyles.title.copyWith(
                fontSize: 14,
                color: selected ? AppColors.paper : AppColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
