import 'package:flutter/material.dart';
import 'screens/chat_screen.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zeno Chat',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final AuthService _authService = AuthService();
  bool _isLoading = true;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    print('🔐 Checking authentication status...');
    final isLoggedIn = await _authService.isLoggedIn();
    print('🔐 Is logged in: $isLoggedIn');
    
    if (isLoggedIn) {
      final user = await _authService.getCurrentUser();
      print('👤 Current user: ${user?.name} (${user?.id})');
      
      // If we have a token but can't get user data, the token is invalid
      if (user == null) {
        print('⚠️ Token exists but user data is null - clearing invalid token');
        await _authService.logout();
        setState(() {
          _isLoggedIn = false;
          _isLoading = false;
        });
        return;
      }
    }
    
    setState(() {
      _isLoggedIn = isLoggedIn;
      _isLoading = false;
    });
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

    return _isLoggedIn ? const ChatScreen() : const LoginScreen();
  }
}
