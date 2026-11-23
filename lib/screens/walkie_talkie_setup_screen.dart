import 'package:flutter/material.dart';

import '../models/start_mode.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/pill_button.dart';
import 'bluetooth_setup_screen.dart';
import 'talk_screen.dart';

/// Name + channel entry for Walkie Talkie mode, then a choice of transport
/// (WiFi recommended, Bluetooth as the fallback). Carried over from the
/// app's original home screen, restyled to match the new design system.
class WalkieTalkieSetupScreen extends StatefulWidget {
  const WalkieTalkieSetupScreen({super.key});

  @override
  State<WalkieTalkieSetupScreen> createState() => _WalkieTalkieSetupScreenState();
}

class _WalkieTalkieSetupScreenState extends State<WalkieTalkieSetupScreen> {
  final _nameController = TextEditingController();
  final _channelController = TextEditingController(text: 'Family');

  @override
  void dispose() {
    _nameController.dispose();
    _channelController.dispose();
    super.dispose();
  }

  bool _validate() {
    if (_nameController.text.trim().isEmpty || _channelController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your name and a channel name first.')),
      );
      return false;
    }
    return true;
  }

  void _goWifi() {
    if (!_validate()) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => TalkScreen(
        displayName: _nameController.text.trim(),
        channelName: _channelController.text.trim(),
        mode: StartMode.wifi,
      ),
    ));
  }

  void _goBluetooth() {
    if (!_validate()) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => BluetoothSetupScreen(
        displayName: _nameController.text.trim(),
        channelName: _channelController.text.trim(),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Walkie Talkie')),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 84,
              height: 84,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.ink,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.settings_input_antenna_rounded,
                  size: 40, color: AppColors.paper),
            ),
            const SizedBox(height: 24),
            Text('Set up your channel', style: AppTextStyles.headline),
            const SizedBox(height: 6),
            Text(
              'Everyone who enters the same channel name hears each other.',
              style: AppTextStyles.bodyMuted,
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Your name'),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _channelController,
              decoration: const InputDecoration(labelText: 'Channel name'),
            ),
            const SizedBox(height: 28),
            PillButton(
              label: 'Start over WiFi (recommended)',
              icon: const Icon(Icons.wifi_rounded, color: AppColors.paper, size: 20),
              onPressed: _goWifi,
            ),
            const SizedBox(height: 12),
            PillButton(
              label: 'No WiFi? Use Bluetooth instead',
              style: PillButtonStyle.outline,
              icon: const Icon(Icons.bluetooth_rounded, color: AppColors.ink, size: 20),
              onPressed: _goBluetooth,
            ),
            const SizedBox(height: 20),
            Text(
              'WiFi needs every phone on the same network or hotspot, but then works for '
              'any number of phones. Bluetooth needs no network, but today only works '
              'between two Android phones, and one of them has to "host" the channel.',
              style: AppTextStyles.bodyMuted,
            ),
          ],
        ),
      ),
    );
  }
}
