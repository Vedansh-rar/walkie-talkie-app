import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_classic_bluetooth/flutter_classic_bluetooth.dart';

import '../models/start_mode.dart';
import '../transport/bluetooth_transport.dart';
import 'talk_screen.dart';

/// Lets the user either host a Bluetooth channel (and wait for others to
/// connect) or scan for and join someone else's. See [BluetoothTransport]
/// for why this only works between two Android phones.
class BluetoothSetupScreen extends StatefulWidget {
  final String displayName;
  final String channelName;

  const BluetoothSetupScreen({super.key, required this.displayName, required this.channelName});

  @override
  State<BluetoothSetupScreen> createState() => _BluetoothSetupScreenState();
}

class _BluetoothSetupScreenState extends State<BluetoothSetupScreen> {
  final FlutterClassicBluetooth _bt = FlutterClassicBluetooth();
  StreamSubscription<BtcDevice>? _discoverySub;
  final Map<String, BtcDevice> _devices = {};
  bool _scanning = false;
  String? _error;

  @override
  void dispose() {
    _discoverySub?.cancel();
    _bt.stopDiscovery();
    super.dispose();
  }

  Future<void> _startScan() async {
    setState(() {
      _error = null;
      _devices.clear();
    });
    final ok = await BluetoothTransport.ensurePermissions();
    if (!ok) {
      setState(() => _error = 'Bluetooth permission was not granted.');
      return;
    }
    for (final device in await _bt.getPairedDevices()) {
      _devices[device.address] = device;
    }
    _discoverySub = _bt.discoveryResults.listen((device) {
      setState(() => _devices[device.address] = device);
    });
    setState(() => _scanning = true);
    await _bt.startDiscovery();
  }

  Future<void> _stopScan() async {
    await _bt.stopDiscovery();
    await _discoverySub?.cancel();
    if (mounted) setState(() => _scanning = false);
  }

  Future<void> _hostChannel() async {
    final ok = await BluetoothTransport.ensurePermissions();
    if (!ok) {
      setState(() => _error = 'Bluetooth permission was not granted.');
      return;
    }
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => TalkScreen(
        displayName: widget.displayName,
        channelName: widget.channelName,
        mode: StartMode.bluetoothHost,
      ),
    ));
  }

  void _joinDevice(BtcDevice device) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => TalkScreen(
        displayName: widget.displayName,
        channelName: widget.channelName,
        mode: StartMode.bluetoothClient,
        bluetoothHostAddress: device.address,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bluetooth channel')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            FilledButton.icon(
              onPressed: _hostChannel,
              icon: const Icon(Icons.wifi_tethering),
              label: const Text('Host this channel (others connect to you)'),
            ),
            const SizedBox(height: 8),
            const Text(
              'One phone hosts; everyone else scans below and taps this phone once it shows up. '
              'Both phones need Bluetooth turned on, and the host should stay on this screen or '
              'the talk screen so it keeps accepting connections.',
              style: TextStyle(color: Colors.grey),
            ),
            const Divider(height: 32),
            Row(
              children: [
                Expanded(child: Text('Nearby devices', style: Theme.of(context).textTheme.titleMedium)),
                _scanning
                    ? TextButton(onPressed: _stopScan, child: const Text('Stop'))
                    : TextButton(onPressed: _startScan, child: const Text('Scan')),
              ],
            ),
            Expanded(
              child: _devices.isEmpty
                  ? const Center(child: Text('No devices found yet.'))
                  : ListView(
                      children: _devices.values
                          .map((d) => ListTile(
                                leading: const Icon(Icons.phone_android),
                                title: Text(d.displayName),
                                subtitle: Text(d.address),
                                onTap: () => _joinDevice(d),
                              ))
                          .toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
