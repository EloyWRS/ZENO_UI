import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/message.dart';
import 'auth_service.dart';

// Custom Business Exception for Flutter
class BusinessException implements Exception {
  final String message;
  final String code;
  final int statusCode;

  BusinessException(this.message, this.code, [this.statusCode = 400]);

  @override
  String toString() => 'BusinessException: $message (Code: $code, Status: $statusCode)';
}

class ApiService {
  final String baseUrl = 'http://192.168.1.134:5075/api'; // Atualiza se necessário
  final AuthService _authService = AuthService();

  Future<Map<String, String>> _getAuthHeaders() async {
    final token = await _authService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<Message?> sendMessage(String threadId, String content) async {
    final url = Uri.parse('$baseUrl/threads/$threadId/messages');
    final headers = await _getAuthHeaders();

    try {
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode({
          'threadId': threadId,
          'role': 'user',
          'content': content,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return Message.fromJson(data);
      } else {
        // Handle structured error responses
        final errorData = jsonDecode(response.body);
        if (errorData['error'] != null) {
          final error = errorData['error'];
          throw BusinessException(
            error['message'] ?? 'Erro desconhecido',
            error['code'] ?? 'UNKNOWN_ERROR',
            error['statusCode'] ?? response.statusCode
          );
        } else {
          throw BusinessException(
            'Erro ao enviar mensagem',
            'SEND_MESSAGE_ERROR',
            response.statusCode
          );
        }
      }
    } catch (e) {
      if (e is BusinessException) {
        rethrow;
      }
      throw BusinessException('Erro de rede: $e', 'NETWORK_ERROR');
    }
  }
  
  Future<List<Message>> fetchMessages(String threadId) async {
    final url = Uri.parse('$baseUrl/threads/$threadId/messages');
    final headers = await _getAuthHeaders();

    final response = await http.get(url, headers: headers);

    if (response.statusCode == 200) {
      final List<dynamic> jsonList = jsonDecode(response.body);
      return jsonList.map((e) => Message.fromJson(e)).toList();
    } else {
      print('Erro ao buscar mensagens: ${response.statusCode}');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getUserAssistantAndThread(String userId) async {
    print('🌐 Making API call to getUserAssistantAndThread for user: $userId');
    
    final url = Uri.parse('$baseUrl/users/$userId/assistant/thread');
    print('📡 URL: $url');
    
    final headers = await _getAuthHeaders();
    print('🔑 Headers: $headers');
    
    try {
      final response = await http.get(url, headers: headers);
      print('📥 Response status: ${response.statusCode}');
      print('📥 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ Successfully parsed response data');
        return data;
      } else {
        print('❌ API error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('💥 Network error: $e');
      return null;
    }
  }
}
