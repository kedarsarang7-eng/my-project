// ============================================================================
// AI Responder Settings Model
// ============================================================================
// Represents the AI responder configuration for a business.
// Only populated when WA_AI_RESPONDER feature is enabled (Enterprise tier).
// ============================================================================

/// AI Responder settings returned from GET /whatsapp/ai-responder/settings.
class AiResponderSettings {
  /// Whether AI auto-reply is currently active (toggled by user).
  final bool autoReplyEnabled;

  /// Maximum response length configured for AI replies.
  final int? maxResponseLength;

  /// The AI provider/model identifier (e.g. 'openai/gpt-4o-mini').
  final String? provider;

  /// Timeout in seconds for AI response generation (default 30s).
  final int timeoutSeconds;

  /// Custom system prompt / instructions for the AI.
  final String? systemPrompt;

  const AiResponderSettings({
    this.autoReplyEnabled = false,
    this.maxResponseLength,
    this.provider,
    this.timeoutSeconds = 30,
    this.systemPrompt,
  });

  factory AiResponderSettings.fromJson(Map<String, dynamic> json) {
    return AiResponderSettings(
      autoReplyEnabled: json['autoReplyEnabled'] as bool? ?? false,
      maxResponseLength: json['maxResponseLength'] as int?,
      provider: json['provider'] as String?,
      timeoutSeconds: json['timeoutSeconds'] as int? ?? 30,
      systemPrompt: json['systemPrompt'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'autoReplyEnabled': autoReplyEnabled,
    if (maxResponseLength != null) 'maxResponseLength': maxResponseLength,
    if (provider != null) 'provider': provider,
    'timeoutSeconds': timeoutSeconds,
    if (systemPrompt != null) 'systemPrompt': systemPrompt,
  };
}
