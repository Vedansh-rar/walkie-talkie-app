import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'intercom_screen.dart';

/// Where a rider sets up Intercom mode: their name, the ride's channel
/// (room) code, and the relay server everyone in the group has agreed to
/// use. The three fields are remembered between rides since retyping a
/// relay address before every ride would be tedious — see the README for
/// why there isn't a single relay address built into the app itself.
class IntercomSetupScreen extends StatefulWidget {
  const IntercomSetupScreen({super.key});

  @override
  State<IntercomSetupScreen> createState() => _IntercomSetupScreenState();
}

class _IntercomSetupScreenState extends State<IntercomSetupScreen> {
  static const _prefsName = 'intercom_name';
  static const _prefsChannel = 'intercom_channel';
  static const _prefsRelayUrl = 'intercom_relay_url';

  final _nameController = TextEditingController();
  final _channelController = TextEditingController(text: 'Ride');
  final _relayController = TextEditingController();
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    _nameController.text = prefs.getString(_prefsName) ?? '';
    _channelController.text = prefs.getString(_prefsChannel) ?? 'Ride';
    _relayController.text = prefs.getString(_prefsRelayUrl) ?? '';
    if (mounted) setState(() => _loaded = true);
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsName, _nameController.text.trim());
    await prefs.setString(_prefsChannel, _channelController.text.trim());
    await prefs.setString(_prefsRelayUrl, _relayController.text.trim());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _channelController.dispose();
    _relayController.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final name = _nameController.text.trim();
    final channel = _channelController.text.trim();
    final relayText = _relayController.text.trim();
    if (name.isEmpty || channel.isEmpty || relayText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fill in your name, a channel code, and the relay address.')),
      );
      return;
    }
    final relayUrl = Uri.tryParse(relayText);
    if (relayUrl == null || !(relayUrl.scheme == 'ws' || relayUrl.scheme == 'wss')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Relay address should look like wss://your-relay.onrender.com')),
      );
      return;
    }
    await _save();
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => IntercomScreen(displayName: name, channelName: channel, relayUrl: relayUrl),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Intercom mode')),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.motorcycle, size: 64),
                  const SizedBox(height: 16),
                  const Text(
                    'Hands-free, voice-activated talking over the internet — built for riding '
                    'with friends who are spread out, not just in Bluetooth range.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Your name', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _channelController,
                    decoration: const InputDecoration(
                      labelText: 'Ride / channel code',
                      helperText: 'Share this with your friends — everyone types the same code.',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _relayController,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: 'Relay server address',
                      hintText: 'wss://your-relay.onrender.com',
                      helperText: 'Everyone in the group ride needs the same one — see the README to deploy it.',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    onPressed: _start,
                    icon: const Icon(Icons.podcasts),
                    label: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('Go live'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
