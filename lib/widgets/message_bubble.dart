
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/message.dart';
import '../services/audio_service.dart';

class MessageBubble extends StatelessWidget {
  final Message message;

  const MessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    final formattedDateTime = DateFormat('dd/MM/yyyy HH:mm').format(message.createdAt);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isUser ? Colors.blueAccent : Colors.grey[300],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    message.content,
                    style: TextStyle(
                      color: isUser ? Colors.white : Colors.black,
                    ),
                  ),
                ),
                if (!isUser) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.volume_up),
                    color: Colors.black54,
                    iconSize: 20,
                    tooltip: 'Ouvir áudio',
                    onPressed: () async {
                      final audioService = AudioService();
                      await audioService.playMessageAudio(message.id);
                    },
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(
              formattedDateTime,
              style: TextStyle(
                fontSize: 10,
                color: isUser ? Colors.white70 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
