import 'package:flutter/material.dart';

import '../models/participant.dart';

class ParticipantTile extends StatelessWidget {
  final Participant participant;

  const ParticipantTile({super.key, required this.participant});

  @override
  Widget build(BuildContext context) {
    final initials = participant.name.isNotEmpty ? participant.name.substring(0, 1).toUpperCase() : '?';
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: participant.isTalking ? Colors.green : Colors.grey.shade400,
        child: Text(initials, style: const TextStyle(color: Colors.white)),
      ),
      title: Text(participant.name),
      trailing: participant.isTalking ? const Icon(Icons.volume_up, color: Colors.green) : null,
    );
  }
}
