class NotificationModel {
  final String id;
  final String title;
  final String body;
  final String targetUserId; // empty or null means broadcast
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.targetUserId,
    required this.createdAt,
  });

  factory NotificationModel.fromMap(String id, Map<String, dynamic> map) {
    return NotificationModel(
      id: id,
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
      targetUserId: map['targetUserId'] as String? ?? '',
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'body': body,
      'targetUserId': targetUserId,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
