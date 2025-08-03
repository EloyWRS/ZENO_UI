class Message {
  final String id;
  final String role; // 'user' ou 'assistant'
  final String content;
  final DateTime createdAt;

  Message({required this.id, required this.role, required this.content, required this.createdAt});

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'],
      role: json['role'],
      content: json['content'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'role': role,
      'content': content,
      'createdAt': createdAt
    };
  }
}
