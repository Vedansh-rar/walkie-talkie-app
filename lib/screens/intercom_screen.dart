import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/participant.dart';
import '../services/ptt_controller.dart';

/// Intercom mode's hands-free screen: no push-to-talk button — a
/// voice-activity detector decides when you're transmitting (see
/// [PttController.enableVoiceActivation]) — just status, who's on the
/// ride, and the controls a rider actually needs with gloves on: mute,
/// deafen, and a private whisper to one other rider.
class IntercomScreen extends StatefulWidget {
  final String displayName;
  final String channelName;
  final Uri relayUrl;

  const IntercomScreen({
    super.key,
    required this.displayName,
    required this.channelName,
    required this.relayUrl,
  });

  @override
  State<IntercomScreen> createState() => _IntercomScreenState();
}

class _IntercomScreenState extends State<IntercomScreen> {
  late final PttController _controller;
  List<Participant> _participants = [];
  Participant? _remoteTalker;
  String _status = 'Connecting…';
  bool _selfTalking = false;
  bool _muted = false;
  bool _deafened = false;
  double _sensitivity = 0.5;
  String? _whisperTargetId;
  bool _keepScreenOn = true;

  @override
  void initState() {
    super.initState();
    // A ~200ms playout buffer smooths out the extra arrival jitter of a
    // cellular link — see AudioPlayer's doc comment. WiFi/Bluetooth PTT
    // mode doesn't need this (hence it isn't the default there).
    _controller = PttController(
      displayName: widget.displayName,
      channelName: widget.channelName,
      audioPlayoutDelay: const Duration(milliseconds: 200),
    );
    _controller.participants.listen((p) => setState(() => _participants = p));
    _controller.remoteTalker.listen((p) => setState(() => _remoteTalker = p));
    _controller.status.listen((s) => setState(() => _status = s));
    _connect();
    WakelockPlus.enable();
  }

  Future<void> _connect() async {
    await _controller.startIntercom(relayUrl: widget.relayUrl);
    await _controller.enableVoiceActivation(sensitivity: _sensitivity);
    // Poll isSelfTalking since it's driven by the VAD on every audio
    // chunk (tens of times a second) rather than by a UI event — a timer
    // is simpler here than a dedicated stream for something this chatty.
    _pollTalkingState();
  }

  void _pollTalkingState() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 150));
      if (!mounted) return false;
      if (_controller.isSelfTalking != _selfTalking) {
        setState(() => _selfTalking = _controller.isSelfTalking);
      }
      return mounted;
    });
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _controller.dispose();
    super.dispose();
  }

  void _toggleMute() {
    setState(() => _muted = !_muted);
    _controller.setMuted(_muted);
  }

  void _toggleDeafen() {
    setState(() => _deafened = !_deafened);
    _controller.setDeafened(_deafened);
  }

  void _toggleWhisper(Participant p) {
    setState(() {
      if (_whisperTargetId == p.id) {
        _whisperTargetId = null;
        _controller.whisperTarget = null;
      } else {
        _whisperTargetId = p.id;
        _controller.whisperTarget = p.id;
      }
    });
  }

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Intercom settings', style: Theme.of(sheetContext).textTheme.titleMedium),
              const SizedBox(height: 16),
              Text('Voice sensitivity: ${(_sensitivity * 100).round()}%'),
              Slider(
                value: _sensitivity,
                onChanged: (v) {
                  setSheetState(() => _sensitivity = v);
                  setState(() => _sensitivity = v);
                  _controller.setVoxSensitivity(v);
                },
              ),
              const Text(
                'Higher picks up a softer voice, but is more easily set off by wind or engine noise.',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Keep screen on'),
                subtitle: const Text('Recommended while mounted and riding'),
                value: _keepScreenOn,
                onChanged: (v) {
                  setSheetState(() => _keepScreenOn = v);
                  setState(() => _keepScreenOn = v);
                  if (v) {
                    WakelockPlus.enable();
                  } else {
                    WakelockPlus.disable();
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _qualityColor(ConnectionQuality? q) => switch (q) {
        ConnectionQuality.good => Colors.green,
        ConnectionQuality.fair => Colors.orange,
        ConnectionQuality.poor => Colors.red,
        null => Colors.grey,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.channelName),
        actions: [
          IconButton(onPressed: _showSettings, icon: const Icon(Icons.tune)),
        ],
      ),
      body: Column(
        children: [
          if (_whisperTargetId != null)
            Container(
              width: double.infinity,
              color: Colors.indigo.shade50,
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Expanded(child: Text('Whispering privately — everyone else can\'t hear you right now.')),
                  TextButton(
                    onPressed: () => setState(() {
                      _whisperTargetId = null;
                      _controller.whisperTarget = null;
                    }),
                    child: const Text('Back to everyone'),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: _StatusRing(
              talking: _selfTalking,
              remoteTalkerName: _remoteTalker?.name,
              statusText: _status,
            ),
          ),
          Expanded(
            child: _participants.isEmpty
                ? const Center(child: Text('Waiting for the rest of the ride to join…'))
                : ListView(
                    children: _participants
                        .map((p) => ListTile(
                              leading: CircleAvatar(
                                backgroundColor: p.isTalking ? Colors.green : Colors.grey.shade400,
                                child: Text(
                                  p.name.isNotEmpty ? p.name.substring(0, 1).toUpperCase() : '?',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                              title: Text(p.name),
                              subtitle: Text(_whisperTargetId == p.id ? 'Whispering to this rider' : 'On the ride'),
                              trailing: Icon(Icons.circle, size: 12, color: _qualityColor(p.quality)),
                              onTap: () => _toggleWhisper(p),
                            ))
                        .toList(),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 32),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _ToggleButton(
                  icon: _muted ? Icons.mic_off : Icons.mic,
                  label: _muted ? 'Muted' : 'Mute',
                  active: _muted,
                  onTap: _toggleMute,
                ),
                _ToggleButton(
                  icon: _deafened ? Icons.hearing_disabled : Icons.hearing,
                  label: _deafened ? 'Deafened' : 'Deafen',
                  active: _deafened,
                  onTap: _toggleDeafen,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusRing extends StatelessWidget {
  final bool talking;
  final String? remoteTalkerName;
  final String statusText;

  const _StatusRing({required this.talking, required this.remoteTalkerName, required this.statusText});

  @override
  Widget build(BuildContext context) {
    final isRemoteTalking = remoteTalkerName != null;
    final color = talking ? Colors.redAccent : (isRemoteTalking ? Colors.green : Colors.grey.shade400);
    final label = talking ? 'Transmitting' : (isRemoteTalking ? '$remoteTalkerName is talking' : statusText);
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 20, spreadRadius: talking ? 6 : 0)],
          ),
          child: Icon(talking ? Icons.mic : Icons.hearing, color: Colors.white, size: 48),
        ),
        const SizedBox(height: 12),
        Text(label, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
      ],
    );
  }
}

class _ToggleButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _ToggleButton({required this.icon, required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        IconButton.filled(
          onPressed: onTap,
          icon: Icon(icon),
          style: IconButton.styleFrom(
            backgroundColor: active ? Colors.redAccent : Theme.of(context).colorScheme.primary,
            minimumSize: const Size(64, 64),
          ),
        ),
        const SizedBox(height: 4),
        Text(label),
      ],
    );
  }
}
