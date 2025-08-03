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
  String? _threadId; // Will be set dynamically
  
  User? _currentUser;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    await _loadCurrentUser();
    if (_currentUser != null) {
      await _loadUserAssistantAndThread();
    } else {
      // User is null, redirect to login
      print('⚠️ User is null, redirecting to login');
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  Future<void> _loadUserAssistantAndThread() async {
    try {
      print('🔍 Starting to load user assistant and thread...');
      print('👤 Current user ID: ${_currentUser?.id}');
      
      final result = await _apiService.getUserAssistantAndThread(_currentUser!.id);
      
      print('📡 API response received: $result');
      
      if (result != null) {
        print('✅ Successfully got assistant and thread data');
        setState(() {
          _threadId = result['thread']['id'];
          _isLoading = false;
        });
        
        print('🔄 Loading messages for thread: $_threadId');
        // Load messages for this thread
        await _loadMessages();
      } else {
        print('❌ API returned null result');
        setState(() {
          _isLoading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erro ao carregar conversa'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('💥 Error loading assistant and thread: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadMessages() async {
    if (_threadId == null) return;
    
    final history = await _apiService.fetchMessages(_threadId!);
    history.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    setState(() {
      _messages.addAll(history);
    });
  }

  Future<void> _loadCurrentUser() async {
    print('👤 Loading current user...');
    final user = await _authService.getCurrentUser();
    print('👤 User loaded: ${user?.name} (${user?.id})');
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
    if (_threadId == null) return;
    
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(Message(id: text, role: 'user', content: text, createdAt: DateTime.now()));
      _controller.clear();
    });

    try {
      final response = await _apiService.sendMessage(_threadId!, text);
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
    } catch (e) {
      print('💥 Error in _sendMessage: $e');
      
      // Remove the user message since it failed
      setState(() {
        _messages.removeLast();
      });
      
      // Show user-friendly error message
      if (mounted) {
        String errorMessage = 'Erro ao enviar mensagem';
        
        if (e is BusinessException) {
          switch (e.code) {
            case 'INSUFFICIENT_CREDITS':
              errorMessage = 'Créditos insuficientes. Por favor, adicione mais créditos para continuar a conversar.';
              break;
            case 'THREAD_NOT_FOUND':
              errorMessage = 'Conversa não encontrada. Tente recarregar a aplicação.';
              break;
            case 'ASSISTANT_NOT_FOUND':
              errorMessage = 'Assistente não encontrado. Tente recarregar a aplicação.';
              break;
            case 'NETWORK_ERROR':
              errorMessage = 'Erro de conexão. Verifique sua internet e tente novamente.';
              break;
            default:
              errorMessage = e.message;
          }
        } else if (e.toString().contains('401')) {
          errorMessage = 'Sessão expirada. Por favor, faça login novamente.';
        }
        
        final scaffoldMessenger = ScaffoldMessenger.of(context);
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {
                scaffoldMessenger.hideCurrentSnackBar();
              },
            ),
          ),
        );
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
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_threadId == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('ZENO'),
          actions: [
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
        body: const Center(
          child: Text('Erro ao carregar conversa'),
        ),
      );
    }

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
                  threadId: _threadId!,
                  onMessageGenerated: (msg) async {
                    setState(() {
                      _messages.add(msg);
                    });

                    // Capture context before async gap
                    final scaffoldMessenger = ScaffoldMessenger.of(context);

                    try {
                      final response = await _apiService.sendMessage(_threadId!, msg.content);
                      if (response != null) {
                        setState(() {
                          _messages.add(response);
                        });

                        if (response.role == 'assistant') {
                          final audioService = AudioService();
                          await audioService.playMessageAudio(response.id);
                        }
                      }
                    } catch (e) {
                      print('💥 Error in _sendAudioMessage: $e');

                      // Remove the user message since it failed
                      setState(() {
                        _messages.removeLast();
                      });

                      // Show user-friendly error message
                      if (mounted) {
                        String errorMessage = 'Erro ao enviar mensagem';

                        if (e is BusinessException) {
                          switch (e.code) {
                            case 'INSUFFICIENT_CREDITS':
                              errorMessage = 'Créditos insuficientes. Por favor, adicione mais créditos para continuar a conversar.';
                              break;
                            case 'THREAD_NOT_FOUND':
                              errorMessage = 'Conversa não encontrada. Tente recarregar a aplicação.';
                              break;
                            case 'ASSISTANT_NOT_FOUND':
                              errorMessage = 'Assistente não encontrado. Tente recarregar a aplicação.';
                              break;
                            case 'NETWORK_ERROR':
                              errorMessage = 'Erro de conexão. Verifique sua internet e tente novamente.';
                              break;
                            default:
                              errorMessage = e.message;
                          }
                        } else if (e.toString().contains('401')) {
                          errorMessage = 'Sessão expirada. Por favor, faça login novamente.';
                        }

                        scaffoldMessenger.showSnackBar(
                          SnackBar(
                            content: Text(errorMessage),
                            backgroundColor: Colors.red,
                            duration: const Duration(seconds: 5),
                            action: SnackBarAction(
                              label: 'OK',
                              textColor: Colors.white,
                              onPressed: () {
                                scaffoldMessenger.hideCurrentSnackBar();
                              },
                            ),
                          ),
                        );
                      }
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
