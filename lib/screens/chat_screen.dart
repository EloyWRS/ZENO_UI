import 'package:flutter/material.dart';
import 'package:zeno_ui/services/audio_service.dart';
import '../models/message.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widgets/message_bubble.dart';
import 'package:intl/intl.dart';
import '../widgets/speech_input_button.dart';
import 'login_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<Message> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();
  final String _threadId = 'c1229810-ef50-46e1-b76b-1b9dde63b61e'; // Substituir com valor real
  
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _loadCurrentUser();
  }

  void _loadMessages() async {
    final history = await _apiService.fetchMessages(_threadId);
    history.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    setState(() {
      _messages.addAll(history);
    });
  }

  void _loadCurrentUser() async {
    final user = await _authService.getCurrentUser();
    setState(() {
      _currentUser = user;
    });
  }

  Future<void> _logout() async {
    final result = await _authService.logout();
    
    if (result.success) {
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.error ?? 'Logout failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(Message(id: text, role: 'user', content: text, createdAt: DateTime.now()));
      _controller.clear();
    });

    final response = await _apiService.sendMessage(_threadId, text);
    if (response != null) {
      final msg = response;

      setState(() {
        _messages.add(msg);
      });

      if (msg.role == 'assistant') {
        final audioService = AudioService();
        await audioService.playMessageAudio(msg.id);
      }
    }
  }

  List<Widget> _buildGroupedMessages() {
    final Map<String, List<Message>> grouped = {};

    for (var msg in _messages) {
      final now = DateTime.now();
      final messageDate = DateTime(msg.createdAt.year, msg.createdAt.month, msg.createdAt.day);
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));

      String dateKey;
      if (messageDate == today) {
        dateKey = 'Today';
      } else if (messageDate == yesterday) {
        dateKey = 'Yesterday';
      } else {
        dateKey = DateFormat('dd/MM/yyyy').format(msg.createdAt);
      }

      grouped.putIfAbsent(dateKey, () => []).add(msg);
    }
    
    final List<Widget> widgets = [];
    grouped.forEach((date, messages) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Center(
            child: Text(
              '─── $date ───',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
        ),
      );
      widgets.addAll(messages.map((msg) => MessageBubble(message: msg)));
    });

    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ZENO'),
        actions: [
          // User info and logout
          PopupMenuButton<String>(
            icon: CircleAvatar(
              backgroundColor: Colors.blue,
              child: Text(
                _currentUser?.name.substring(0, 1).toUpperCase() ?? 'U',
                style: const TextStyle(color: Colors.white),
              ),
            ),
            onSelected: (value) {
              if (value == 'logout') {
                _logout();
              }
            },
            itemBuilder: (context) => [
              // User info
              PopupMenuItem(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currentUser?.name ?? 'User',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      _currentUser?.email ?? '',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Text(
                      'Credits: ${_currentUser?.credits ?? 0}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              // Logout option
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Logout', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(8),
              children: _buildGroupedMessages(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(hintText: 'Escreve aqui...'),
                  ),
                ),

                /// 🎤 Botão de input por voz
                SpeechInputButton(
                  threadId: _threadId,
                  onMessageGenerated: (msg) async {
                    setState(() {
                      _messages.add(msg);
                    });

                    final response = await _apiService.sendMessage(_threadId, msg.content);
                    if (response != null) {
                      setState(() {
                        _messages.add(response);
                      });
                    }
                  },
                ),

                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
