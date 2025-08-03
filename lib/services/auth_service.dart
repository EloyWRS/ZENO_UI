import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';

class AuthService {
  final String baseUrl = 'http://192.168.1.134:5075/api';
  
  // Keys for storing auth data
  static const String _tokenKey = 'auth_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userKey = 'user_data';

  // Get stored token
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  // Get stored user data
  Future<User?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(_userKey);
    if (userJson != null) {
      return User.fromJson(jsonDecode(userJson));
    }
    return null;
  }

  // Check if user is logged in
  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null;
  }

  // Register new user
  Future<AuthResult> register({
    required String name,
    required String email,
    required String password,
    required String confirmPassword,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'email': email,
          'password': password,
          'confirmPassword': confirmPassword,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await _saveAuthData(data);
        return AuthResult.success(User.fromJson(data['user']));
      } else {
        final error = jsonDecode(response.body);
        return AuthResult.failure(error['message'] ?? 'Registration failed');
      }
    } catch (e) {
      return AuthResult.failure('Network error: $e');
    }
  }

  // Login user
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await _saveAuthData(data);
        return AuthResult.success(User.fromJson(data['user']));
      } else {
        final error = jsonDecode(response.body);
        return AuthResult.failure(error['message'] ?? 'Login failed');
      }
    } catch (e) {
      return AuthResult.failure('Network error: $e');
    }
  }

  // Logout user
  Future<AuthResult> logout() async {
    try {
      final token = await getToken();
      if (token == null) {
        await _clearAuthData();
        return AuthResult.success(null);
      }

      final response = await http.post(
        Uri.parse('$baseUrl/auth/logout'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'token': token}),
      );

      await _clearAuthData();
      
      if (response.statusCode == 200) {
        return AuthResult.success(null);
      } else {
        return AuthResult.failure('Logout failed');
      }
    } catch (e) {
      await _clearAuthData();
      return AuthResult.failure('Network error: $e');
    }
  }

  // Get current user info
  Future<User?> getCurrentUser() async {
    try {
      print('🔍 getCurrentUser() called');
      final token = await getToken();
      print('🔑 Token: ${token != null ? "exists" : "null"}');
      if (token == null) return null;

      final response = await http.get(
        Uri.parse('$baseUrl/user/me'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('📡 Response status: ${response.statusCode}');
      print('📡 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ Successfully parsed user data');
        return User.fromJson(data);
      }
      print('❌ Failed to get user data');
      return null;
    } catch (e) {
      print('💥 Error in getCurrentUser: $e');
      return null;
    }
  }

  // Save authentication data
  Future<void> _saveAuthData(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, data['token']);
    await prefs.setString(_refreshTokenKey, data['refreshToken']);
    await prefs.setString(_userKey, jsonEncode(data['user']));
  }

  // Clear authentication data
  Future<void> _clearAuthData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_refreshTokenKey);
    await prefs.remove(_userKey);
  }
}

// Auth result class
class AuthResult {
  final bool success;
  final User? user;
  final String? error;

  AuthResult.success(this.user) : success = true, error = null;
  AuthResult.failure(this.error) : success = false, user = null;
} 