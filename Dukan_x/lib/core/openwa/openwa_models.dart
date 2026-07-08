// ============================================================================
// OpenWA Data Models — Dart types mirroring OpenWA REST API responses
// ============================================================================
// These models are the Flutter-side representation of OpenWA's TypeScript
// DTOs. They cover Phase-1 endpoints: Session, Message, Template, Contact.
// ============================================================================

/// WhatsApp session status (mirrors OpenWA SessionStatus enum).
enum WASessionStatus {
  created,
  idle,
  initializing,
  connecting,
  qrReady,
  ready,
  disconnected,
  failed;

  static WASessionStatus fromString(String value) {
    switch (value) {
      case 'created':
        return WASessionStatus.created;
      case 'idle':
        return WASessionStatus.idle;
      case 'initializing':
        return WASessionStatus.initializing;
      case 'connecting':
        return WASessionStatus.connecting;
      case 'qr_ready':
        return WASessionStatus.qrReady;
      case 'ready':
        return WASessionStatus.ready;
      case 'disconnected':
        return WASessionStatus.disconnected;
      case 'failed':
        return WASessionStatus.failed;
      default:
        return WASessionStatus.created;
    }
  }

  /// Whether the session is in a connected, usable state.
  bool get isConnected => this == WASessionStatus.ready;

  /// Whether the session needs QR scanning.
  bool get needsQR => this == WASessionStatus.qrReady;

  /// Whether the session is in a terminal/error state.
  bool get isFailed => this == WASessionStatus.failed;

  /// Human-readable label.
  String get label {
    switch (this) {
      case WASessionStatus.created:
        return 'Created';
      case WASessionStatus.idle:
        return 'Idle';
      case WASessionStatus.initializing:
        return 'Initializing...';
      case WASessionStatus.connecting:
        return 'Connecting...';
      case WASessionStatus.qrReady:
        return 'Scan QR Code';
      case WASessionStatus.ready:
        return 'Connected';
      case WASessionStatus.disconnected:
        return 'Disconnected';
      case WASessionStatus.failed:
        return 'Failed';
    }
  }
}

// ── Session ─────────────────────────────────────────────────────────────────

class WASession {
  final String id;
  final String name;
  final WASessionStatus status;
  final String? phone;
  final String? pushName;
  final String? lastActive;
  final String createdAt;
  final String updatedAt;
  final String? lastError;

  const WASession({
    required this.id,
    required this.name,
    required this.status,
    this.phone,
    this.pushName,
    this.lastActive,
    required this.createdAt,
    required this.updatedAt,
    this.lastError,
  });

  factory WASession.fromJson(Map<String, dynamic> json) {
    return WASession(
      id: json['id'] as String,
      name: json['name'] as String,
      status: WASessionStatus.fromString(json['status'] as String? ?? 'created'),
      phone: json['phone'] as String?,
      pushName: json['pushName'] as String?,
      lastActive: json['lastActive'] as String?,
      createdAt: json['createdAt'] as String? ?? '',
      updatedAt: json['updatedAt'] as String? ?? '',
      lastError: json['lastError'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'status': status.name,
        'phone': phone,
        'pushName': pushName,
        'lastActive': lastActive,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'lastError': lastError,
      };
}

// ── QR Code ─────────────────────────────────────────────────────────────────

class WAQRCode {
  final String qrCode;
  final String status;

  const WAQRCode({required this.qrCode, required this.status});

  factory WAQRCode.fromJson(Map<String, dynamic> json) {
    return WAQRCode(
      qrCode: json['qrCode'] as String? ?? '',
      status: json['status'] as String? ?? '',
    );
  }
}

// ── Pairing Code ────────────────────────────────────────────────────────────

class WAPairingCode {
  final String code;

  const WAPairingCode({required this.code});

  factory WAPairingCode.fromJson(Map<String, dynamic> json) {
    return WAPairingCode(
      code: json['code'] as String? ?? '',
    );
  }
}

// ── Session Stats ───────────────────────────────────────────────────────────

class WASessionStats {
  final int total;
  final int active;
  final int ready;
  final int disconnected;
  final Map<String, int> byStatus;

  const WASessionStats({
    required this.total,
    required this.active,
    required this.ready,
    required this.disconnected,
    required this.byStatus,
  });

  factory WASessionStats.fromJson(Map<String, dynamic> json) {
    return WASessionStats(
      total: json['total'] as int? ?? 0,
      active: json['active'] as int? ?? 0,
      ready: json['ready'] as int? ?? 0,
      disconnected: json['disconnected'] as int? ?? 0,
      byStatus: (json['byStatus'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, v as int)) ??
          {},
    );
  }
}

// ── Chat ────────────────────────────────────────────────────────────────────

class WAChat {
  final String id;
  final String name;
  final bool isGroup;
  final int unreadCount;
  final int timestamp;
  final String? lastMessage;

  const WAChat({
    required this.id,
    required this.name,
    required this.isGroup,
    required this.unreadCount,
    required this.timestamp,
    this.lastMessage,
  });

  factory WAChat.fromJson(Map<String, dynamic> json) {
    return WAChat(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      isGroup: json['isGroup'] as bool? ?? false,
      unreadCount: json['unreadCount'] as int? ?? 0,
      timestamp: json['timestamp'] as int? ?? 0,
      lastMessage: json['lastMessage'] as String?,
    );
  }
}

// ── Message ─────────────────────────────────────────────────────────────────

enum WAMessageType {
  text,
  image,
  video,
  audio,
  voice,
  document,
  sticker,
  location,
  contact,
  revoked,
  unknown;

  static WAMessageType fromString(String value) {
    switch (value) {
      case 'text':
        return WAMessageType.text;
      case 'image':
        return WAMessageType.image;
      case 'video':
        return WAMessageType.video;
      case 'audio':
        return WAMessageType.audio;
      case 'voice':
        return WAMessageType.voice;
      case 'document':
        return WAMessageType.document;
      case 'sticker':
        return WAMessageType.sticker;
      case 'location':
        return WAMessageType.location;
      case 'contact':
        return WAMessageType.contact;
      case 'revoked':
        return WAMessageType.revoked;
      default:
        return WAMessageType.unknown;
    }
  }
}

enum WAMessageDirection { incoming, outgoing }

enum WAMessageStatus { pending, sent, delivered, read, failed }

class WAMessage {
  final String id;
  final String? waMessageId;
  final String chatId;
  final String from;
  final String to;
  final String body;
  final WAMessageType type;
  final WAMessageDirection direction;
  final WAMessageStatus status;
  final int? timestamp;
  final String createdAt;
  final Map<String, dynamic>? metadata;

  const WAMessage({
    required this.id,
    this.waMessageId,
    required this.chatId,
    required this.from,
    required this.to,
    required this.body,
    required this.type,
    required this.direction,
    required this.status,
    this.timestamp,
    required this.createdAt,
    this.metadata,
  });

  factory WAMessage.fromJson(Map<String, dynamic> json) {
    return WAMessage(
      id: json['id'] as String? ?? '',
      waMessageId: json['waMessageId'] as String?,
      chatId: json['chatId'] as String? ?? '',
      from: json['from'] as String? ?? '',
      to: json['to'] as String? ?? '',
      body: json['body'] as String? ?? '',
      type: WAMessageType.fromString(json['type'] as String? ?? 'unknown'),
      direction: json['direction'] == 'outgoing'
          ? WAMessageDirection.outgoing
          : WAMessageDirection.incoming,
      status: _parseStatus(json['status'] as String?),
      timestamp: json['timestamp'] as int?,
      createdAt: json['createdAt'] as String? ?? '',
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  static WAMessageStatus _parseStatus(String? value) {
    switch (value) {
      case 'pending':
        return WAMessageStatus.pending;
      case 'sent':
        return WAMessageStatus.sent;
      case 'delivered':
        return WAMessageStatus.delivered;
      case 'read':
        return WAMessageStatus.read;
      case 'failed':
        return WAMessageStatus.failed;
      default:
        return WAMessageStatus.pending;
    }
  }
}

class WAMessageResponse {
  final String messageId;
  final int timestamp;

  const WAMessageResponse({required this.messageId, required this.timestamp});

  factory WAMessageResponse.fromJson(Map<String, dynamic> json) {
    return WAMessageResponse(
      messageId: json['messageId'] as String? ?? '',
      timestamp: json['timestamp'] as int? ?? 0,
    );
  }
}

class WAMessageList {
  final List<WAMessage> messages;
  final int total;

  const WAMessageList({required this.messages, required this.total});

  factory WAMessageList.fromJson(Map<String, dynamic> json) {
    return WAMessageList(
      messages: (json['messages'] as List<dynamic>?)
              ?.map((e) => WAMessage.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      total: json['total'] as int? ?? 0,
    );
  }
}

// ── Template ────────────────────────────────────────────────────────────────

class WATemplate {
  final String id;
  final String sessionId;
  final String name;
  final String body;
  final String? header;
  final String? footer;
  final String createdAt;
  final String updatedAt;

  const WATemplate({
    required this.id,
    required this.sessionId,
    required this.name,
    required this.body,
    this.header,
    this.footer,
    required this.createdAt,
    required this.updatedAt,
  });

  factory WATemplate.fromJson(Map<String, dynamic> json) {
    return WATemplate(
      id: json['id'] as String? ?? '',
      sessionId: json['sessionId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      body: json['body'] as String? ?? '',
      header: json['header'] as String?,
      footer: json['footer'] as String?,
      createdAt: json['createdAt'] as String? ?? '',
      updatedAt: json['updatedAt'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'sessionId': sessionId,
        'name': name,
        'body': body,
        'header': header,
        'footer': footer,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };
}

// ── Contact Check ───────────────────────────────────────────────────────────

class WACheckNumber {
  final String number;
  final bool exists;
  final String? whatsappId;

  const WACheckNumber({
    required this.number,
    required this.exists,
    this.whatsappId,
  });

  factory WACheckNumber.fromJson(Map<String, dynamic> json) {
    return WACheckNumber(
      number: json['number'] as String? ?? '',
      exists: json['exists'] as bool? ?? false,
      whatsappId: json['whatsappId'] as String?,
    );
  }
}

// ── Health ───────────────────────────────────────────────────────────────────

class WAHealthStatus {
  final String status;
  final String? version;
  final String? timestamp;

  const WAHealthStatus({
    required this.status,
    this.version,
    this.timestamp,
  });

  factory WAHealthStatus.fromJson(Map<String, dynamic> json) {
    return WAHealthStatus(
      status: json['status'] as String? ?? 'unknown',
      version: json['version'] as String?,
      timestamp: json['timestamp'] as String?,
    );
  }

  bool get isHealthy => status == 'ok';
}

// ── Tenant Config ───────────────────────────────────────────────────────────

/// Per-business OpenWA configuration stored in Firestore/DynamoDB.
class WABusinessConfig {
  final String businessId;
  final String? sessionId;
  final String? sessionName;
  final String? apiKeyId;
  final String? encryptedApiKey;
  final WASessionStatus? lastKnownStatus;
  final DateTime? connectedAt;
  final DateTime? updatedAt;

  const WABusinessConfig({
    required this.businessId,
    this.sessionId,
    this.sessionName,
    this.apiKeyId,
    this.encryptedApiKey,
    this.lastKnownStatus,
    this.connectedAt,
    this.updatedAt,
  });

  factory WABusinessConfig.fromJson(Map<String, dynamic> json) {
    return WABusinessConfig(
      businessId: json['businessId'] as String? ?? '',
      sessionId: json['sessionId'] as String?,
      sessionName: json['sessionName'] as String?,
      apiKeyId: json['apiKeyId'] as String?,
      encryptedApiKey: json['encryptedApiKey'] as String?,
      lastKnownStatus: json['lastKnownStatus'] != null
          ? WASessionStatus.fromString(json['lastKnownStatus'] as String)
          : null,
      connectedAt: json['connectedAt'] != null
          ? DateTime.tryParse(json['connectedAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'businessId': businessId,
        'sessionId': sessionId,
        'sessionName': sessionName,
        'apiKeyId': apiKeyId,
        'encryptedApiKey': encryptedApiKey,
        'lastKnownStatus': lastKnownStatus?.name,
        'connectedAt': connectedAt?.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
      };

  bool get isProvisioned => sessionId != null && encryptedApiKey != null;
  bool get isConnected => lastKnownStatus == WASessionStatus.ready;

  WABusinessConfig copyWith({
    String? sessionId,
    String? sessionName,
    String? apiKeyId,
    String? encryptedApiKey,
    WASessionStatus? lastKnownStatus,
    DateTime? connectedAt,
    DateTime? updatedAt,
  }) {
    return WABusinessConfig(
      businessId: businessId,
      sessionId: sessionId ?? this.sessionId,
      sessionName: sessionName ?? this.sessionName,
      apiKeyId: apiKeyId ?? this.apiKeyId,
      encryptedApiKey: encryptedApiKey ?? this.encryptedApiKey,
      lastKnownStatus: lastKnownStatus ?? this.lastKnownStatus,
      connectedAt: connectedAt ?? this.connectedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
