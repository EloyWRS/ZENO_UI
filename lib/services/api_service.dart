import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/message.dart';

class ApiService {
  final String baseUrl = 'http://192.168.1.134:5075/api'; // Atualiza se necessário

  Future<Message?> sendMessage(String threadId, String content) async {
    final url = Uri.parse('$baseUrl/threads/$threadId/messages');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
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
      print('Erro ${response.statusCode}: ${response.body}');
      return null;
    }
  }
  Future<List<Message>> fetchMessages(String threadId) async {
    final url = Uri.parse('$baseUrl/threads/$threadId/messages');

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final List<dynamic> jsonList = jsonDecode(response.body);
      return jsonList.map((e) => Message.fromJson(e)).toList();
    } else {
      print('Erro ao buscar mensagens: ${response.statusCode}');
      return [];
    }
  }
}
