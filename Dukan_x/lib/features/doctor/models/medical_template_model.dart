/// Medical Template Model
class MedicalTemplateModel {
  final String id;
  final String userId;
  final String type; // 'DIAGNOSIS', 'PRESCRIPTION', 'ADVICE'
  final String title;
  final String content; // JSON string or plain text
  final DateTime createdAt;
  final DateTime updatedAt;

  MedicalTemplateModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'userId': userId,
    'type': type,
    'title': title,
    'content': content,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory MedicalTemplateModel.fromMap(Map<String, dynamic> map) {
    return MedicalTemplateModel(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      type: map['type'] ?? 'DIAGNOSIS',
      title: map['title'] ?? '',
      content: map['content'] ?? '',
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updatedAt'] ?? '') ?? DateTime.now(),
    );
  }

  MedicalTemplateModel copyWith({
    String? id,
    String? userId,
    String? type,
    String? title,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MedicalTemplateModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
