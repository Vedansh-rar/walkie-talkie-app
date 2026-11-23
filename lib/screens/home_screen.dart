import 'package:flutter/material.dart';

import '../models/start_mode.dart';
import 'bluetooth_setup_screen.dart';
import 'intercom_setup_screen.dart';
import 'talk_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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

  void _goIntercom() {
    // Intercom mode has its own setup screen (it needs a relay server
    // address too, and remembers your details between rides), so it
    // doesn't reuse the name/channel fields above.
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const IntercomSetupScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Walkie-Talkie')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            const Icon(Icons.settings_input_antenna, size: 72),
            const SizedBox(height: 24),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Your name', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _channelController,
              decoration: const InputDecoration(
                labelText: 'Channel name',
                helperText: 'Everyone who enters the same channel name hears each other.',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _goWifi,
              icon: const Icon(Icons.wifi),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Start over WiFi (recommended)'),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _goBluetooth,
              icon: const Icon(Icons.bluetooth),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('No WiFi? Use Bluetooth instead'),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'WiFi needs every phone on the same network or hotspot, but then works for any '
              'number of phones. Bluetooth needs no network, but today only works between two '
              'Android phones, and one of them has to "host" the channel.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 28),
            const Divider(),
            const SizedBox(height: 12),
            Text('Riding with friends?', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _goIntercom,
              style: FilledButton.styleFrom(backgroundColor: Colors.indigo),
              icon: const Icon(Icons.hearing),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Intercom mode — hands-free over mobile data'),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Pair your earphones, start Intercom, and just talk — no button to hold. Works over '
              'mobile data at any distance your signal reaches, not just nearby.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
