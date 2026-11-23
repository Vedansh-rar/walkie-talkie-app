import 'dart:async';

import 'package:flutter/material.dart';

import '../models/participant.dart';
import '../models/start_mode.dart';
import '../services/ptt_controller.dart';
import '../widgets/participant_tile.dart';
import '../widgets/ptt_button.dart';
import 'bluetooth_setup_screen.dart';

/// The main screen: shows who's on the channel and provides the big
/// hold-to-talk button. Which transport it uses is decided entirely by
/// [mode] (and [bluetoothHostAddress] when joining over Bluetooth) —
/// everything else about this screen is the same regardless.
class TalkScreen extends StatefulWidget {
  final String displayName;
  final String channelName;
  final StartMode mode;
  final String? bluetoothHostAddress;

  const TalkScreen({
    super.key,
    required this.displayName,
    required this.channelName,
    required this.mode,
    this.bluetoothHostAddress,
  });

  @override
  State<TalkScreen> createState() => _TalkScreenState();
}

class _TalkScreenState extends State<TalkScreen> {
  late final PttController _controller;
  List<Participant> _participants = [];
  Participant? _remoteTalker;
  String _status = 'Connecting…';
  bool _isTalking = false;
  bool _showBluetoothHint = false;
  Timer? _fallbackHintTimer;

  @override
  void initState() {
    super.initState();
    _controller = PttController(displayName: widget.displayName, channelName: widget.channelName);
    _controller.participants.listen((p) {
      setState(() => _participants = p);
      if (p.isNotEmpty) _fallbackHintTimer?.cancel();
    });
    _controller.remoteTalker.listen((p) => setState(() => _remoteTalker = p));
    _controller.status.listen((s) => setState(() => _status = s));
    _connect();
  }

  Future<void> _connect() async {
    switch (widget.mode) {
      case StartMode.wifi:
        await _controller.startWifi();
        _fallbackHintTimer = Timer(const Duration(seconds: 8), () {
          if (mounted && _participants.isEmpty) setState(() => _showBluetoothHint = true);
        });
        break;
      case StartMode.bluetoothHost:
        await _controller.startBluetoothAsHost();
        break;
      case StartMode.bluetoothClient:
        await _controller.startBluetoothAsClient(widget.bluetoothHostAddress!);
        break;
    }
  }

  @override
  void dispose() {
    _fallbackHintTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  String get _modeLabel => switch (widget.mode) {
        StartMode.wifi => 'WiFi',
        StartMode.bluetoothHost => 'Bluetooth (host)',
        StartMode.bluetoothClient => 'Bluetooth',
      };

  void _switchToBluetooth() {
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => BluetoothSetupScreen(displayName: widget.displayName, channelName: widget.channelName),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.channelName),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(child: Chip(label: Text(_modeLabel))),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_showBluetoothHint && _participants.isEmpty)
            Container(
              width: double.infinity,
              color: Colors.amber.shade100,
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Expanded(
                    child: Text("No one found on WiFi yet. If you're not on the same network, try Bluetooth."),
                  ),
                  TextButton(onPressed: _switchToBluetooth, child: const Text('Switch')),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              _remoteTalker != null ? '🔊 ${_remoteTalker!.name} is talking' : _status,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
          Expanded(
            child: _participants.isEmpty
                ? const Center(child: Text('Waiting for others to join this channel…'))
                : ListView(
                    children: _participants.map((p) => ParticipantTile(participant: p)).toList(),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: PttButton(
                isTalking: _isTalking,
                onStart: () {
                  setState(() => _isTalking = true);
                  _controller.beginTalking();
                },
                onStop: () {
                  setState(() => _isTalking = false);
                  _controller.endTalking();
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Text(
              _isTalking ? 'Release to stop talking' : 'Hold to talk',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
