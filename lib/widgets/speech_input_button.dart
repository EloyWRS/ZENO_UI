
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../models/message.dart';

class SpeechInputButton extends StatefulWidget {
  final String threadId;
  final Function(Message) onMessageGenerated;

  const SpeechInputButton({
    super.key,
    required this.threadId,
    required this.onMessageGenerated,
  });

  @override
  State<SpeechInputButton> createState() => _SpeechInputButtonState();
}

class _SpeechInputButtonState extends State<SpeechInputButton> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;

  Future<void> _startListening() async {
    bool available = await _speech.initialize();
    if (available) {
      setState(() => _isListening = true);
      _speech.listen(
        localeId: 'pt_PT', // Portuguese locale
        onResult: (result) async {
          if (result.finalResult && result.recognizedWords.isNotEmpty) {
            _speech.stop();
            setState(() => _isListening = false);

            final userMessage = Message(
              id: '',
              role: 'user',
              content: result.recognizedWords,
              createdAt: DateTime.now(),
            );

            widget.onMessageGenerated(userMessage);
          }
        },
      );
    } else {
      print('Speech recognition not available');
    }
  }

  void _stopListening() {
    _speech.stop();
    setState(() => _isListening = false);
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(_isListening ? Icons.hearing : Icons.mic),
      color: _isListening ? Colors.red : Colors.black,
      onPressed: _isListening ? _stopListening : _startListening,
      tooltip: _isListening ? 'A ouvir...' : 'Falar com o ZENO',
    );
  }
}
