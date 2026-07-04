/// Task model for Universal Staff Management module.
///
/// Maps to the backend Task entity (SK: TASK#{id}).
class StaffTaskModel {
  final String id;
  final String businessId;
  final String title;
  final String assigneeId;
  final String priority;
  final String status;
  final List<String>? dependsOn;
  final Map<String, dynamic>? recurrence;
  final TaskEscalation? escalation;
  final List<Map<String, dynamic>>? attachments;
  final List<Map<String, dynamic>>? comments;
  final List<ChecklistItem>? checklist;
  final DateTime createdAt;
  final DateTime updatedAt;

  const StaffTaskModel({
    required this.id,
    required this.businessId,
    required this.title,
    required this.assigneeId,
    this.priority = 'medium',
    this.status = 'open',
    this.dependsOn,
    this.recurrence,
    this.escalation,
    this.attachments,
    this.comments,
    this.checklist,
    required this.createdAt,
    required this.updatedAt,
  });

  factory StaffTaskModel.fromJson(Map<String, dynamic> json) {
    return StaffTaskModel(
      id: json['id'] as String? ?? '',
      businessId: json['businessId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      assigneeId: json['assigneeId'] as String? ?? '',
      priority: json['priority'] as String? ?? 'medium',
      status: json['status'] as String? ?? 'open',
      dependsOn: (json['dependsOn'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      recurrence: json['recurrence'] as Map<String, dynamic>?,
      escalation: json['escalation'] != null
          ? TaskEscalation.fromJson(json['escalation'] as Map<String, dynamic>)
          : null,
      attachments: (json['attachments'] as List<dynamic>?)
          ?.map((e) => e as Map<String, dynamic>)
          .toList(),
      comments: (json['comments'] as List<dynamic>?)
          ?.map((e) => e as Map<String, dynamic>)
          .toList(),
      checklist: (json['checklist'] as List<dynamic>?)
          ?.map((e) => ChecklistItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'businessId': businessId,
    'title': title,
    'assigneeId': assigneeId,
    'priority': priority,
    'status': status,
    'dependsOn': dependsOn,
    'recurrence': recurrence,
    'escalation': escalation?.toJson(),
    'attachments': attachments,
    'comments': comments,
    'checklist': checklist?.map((c) => c.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };
}

/// Escalation config for a task.
class TaskEscalation {
  final int thresholdHours;
  final String action;

  const TaskEscalation({required this.thresholdHours, required this.action});

  factory TaskEscalation.fromJson(Map<String, dynamic> json) {
    return TaskEscalation(
      thresholdHours: (json['thresholdHours'] as num?)?.toInt() ?? 0,
      action: json['action'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'thresholdHours': thresholdHours,
    'action': action,
  };
}

/// A checklist item within a task.
class ChecklistItem {
  final String text;
  final bool done;

  const ChecklistItem({required this.text, this.done = false});

  factory ChecklistItem.fromJson(Map<String, dynamic> json) {
    return ChecklistItem(
      text: json['text'] as String? ?? '',
      done: json['done'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {'text': text, 'done': done};
}
