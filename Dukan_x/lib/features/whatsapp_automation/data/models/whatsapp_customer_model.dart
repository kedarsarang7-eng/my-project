// ============================================================================
// WhatsAppCustomer Model — Customer profile with consent and messaging prefs
// ============================================================================
// E.164 validated phone, consent state, messaging preferences.
// Mirrors backend entity: CustomerProfile (entities.ts)
// ============================================================================

/// Consent state for WhatsApp messaging.
enum ConsentState {
  optedIn('opted_in'),
  optedOut('opted_out'),
  pending('pending');

  const ConsentState(this.value);
  final String value;

  static ConsentState fromString(String s) {
    return ConsentState.values.firstWhere(
      (e) => e.value == s,
      orElse: () => ConsentState.pending,
    );
  }
}

/// Messaging preferences (quiet hours, preferred time).
class MessagingPreferences {
  final String? quietHoursStart;
  final String? quietHoursEnd;
  final String? preferredTime;

  const MessagingPreferences({
    this.quietHoursStart,
    this.quietHoursEnd,
    this.preferredTime,
  });

  factory MessagingPreferences.fromJson(Map<String, dynamic> json) {
    return MessagingPreferences(
      quietHoursStart: json['quietHoursStart'] as String?,
      quietHoursEnd: json['quietHoursEnd'] as String?,
      preferredTime: json['preferredTime'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    if (quietHoursStart != null) 'quietHoursStart': quietHoursStart,
    if (quietHoursEnd != null) 'quietHoursEnd': quietHoursEnd,
    if (preferredTime != null) 'preferredTime': preferredTime,
  };
}

/// WhatsAppCustomer — a customer's WhatsApp profile for messaging.
class WhatsAppCustomer {
  final String id;
  final String businessId;
  final String tenantId;
  final String whatsappNumber;
  final ConsentState consentState;
  final String locale;
  final MessagingPreferences? messagingPreferences;
  final bool eligible;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  WhatsAppCustomer({
    required this.id,
    required this.businessId,
    required this.tenantId,
    required this.whatsappNumber,
    required this.consentState,
    required this.locale,
    this.messagingPreferences,
    required this.eligible,
    this.isDeleted = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory WhatsAppCustomer.fromJson(Map<String, dynamic> json) {
    return WhatsAppCustomer(
      id: json['id'] as String,
      businessId: json['businessId'] as String,
      tenantId: json['tenantId'] as String,
      whatsappNumber: json['whatsappNumber'] as String,
      consentState: ConsentState.fromString(
        json['consentState'] as String? ?? 'pending',
      ),
      locale: json['locale'] as String? ?? 'en',
      messagingPreferences: json['messagingPreferences'] != null
          ? MessagingPreferences.fromJson(
              json['messagingPreferences'] as Map<String, dynamic>,
            )
          : null,
      eligible: json['eligible'] as bool? ?? false,
      isDeleted: json['isDeleted'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'businessId': businessId,
    'tenantId': tenantId,
    'whatsappNumber': whatsappNumber,
    'consentState': consentState.value,
    'locale': locale,
    if (messagingPreferences != null)
      'messagingPreferences': messagingPreferences!.toJson(),
    'eligible': eligible,
    'isDeleted': isDeleted,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };
}
