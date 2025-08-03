class User {
  final String id;
  final String name;
  final String email;
  final String language;
  final int credits;
  final DateTime createdAt;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.language,
    required this.credits,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      language: json['language'] ?? 'pt-PT',
      credits: json['credits'] ?? 0,
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'language': language,
      'credits': credits,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  User copyWith({
    String? id,
    String? name,
    String? email,
    String? language,
    int? credits,
    DateTime? createdAt,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      language: language ?? this.language,
      credits: credits ?? this.credits,
      createdAt: createdAt ?? this.createdAt,
    );
  }
} 