/// Template Category
enum TemplateCategory {
  paymentReminder,
  promotion,
  greeting,
  announcement,
  custom,
}

/// Message Template Model
class TemplateModel {
  final String id;
  final String userId;
  final String name;
  final TemplateCategory category;
  final String content; // With placeholders like {{customer_name}}
  final String? imageUrl;
  final String language;
  final int usageCount;
  final bool isActive;
  final bool isSystemTemplate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isSynced;

  const TemplateModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.category,
    required this.content,
    this.imageUrl,
    this.language = 'en',
    this.usageCount = 0,
    this.isActive = true,
    this.isSystemTemplate = false,
    required this.createdAt,
    required this.updatedAt,
    this.isSynced = false,
  });
}

/// Predefined system templates
class SystemTemplates {
  static const List<Map<String, dynamic>> templates = [
    {
      'name': 'Payment Reminder',
      'category': 'paymentReminder',
      'content': '''à¤¨à¤®à¤¸à¥à¤¤à¥‡ {{customer_name}},

à¤†à¤ªà¤•à¥‡ {{shop_name}} à¤¸à¥‡ â‚¹{{amount}} à¤•à¤¾ à¤­à¥à¤—à¤¤à¤¾à¤¨ à¤¬à¤¾à¤•à¥€ à¤¹à¥ˆà¥¤

à¤•à¥ƒà¤ªà¤¯à¤¾ à¤œà¤²à¥à¤¦ à¤¸à¥‡ à¤œà¤²à¥à¤¦ à¤­à¥à¤—à¤¤à¤¾à¤¨ à¤•à¤°à¥‡à¤‚à¥¤

à¤§à¤¨à¥à¤¯à¤µà¤¾à¤¦!''',
      'language': 'hi',
    },
    {
      'name': 'Payment Reminder (English)',
      'category': 'paymentReminder',
      'content': '''Hi {{customer_name}},

This is a reminder that you have an outstanding balance of â‚¹{{amount}} at {{shop_name}}.

Please make the payment at your earliest convenience.

Thank you!''',
      'language': 'en',
    },
    {
      'name': 'Festival Greeting',
      'category': 'greeting',
      'content': '''ðŸŽ‰ à¤¶à¥à¤­à¤•à¤¾à¤®à¤¨à¤¾à¤à¤‚ {{customer_name}}!

{{shop_name}} à¤•à¥€ à¤“à¤° à¤¸à¥‡ à¤†à¤ªà¤•à¥‹ à¤”à¤° à¤†à¤ªà¤•à¥‡ à¤ªà¤°à¤¿à¤µà¤¾à¤° à¤•à¥‹ à¤¢à¥‡à¤° à¤¸à¤¾à¤°à¥€ à¤¶à¥à¤­à¤•à¤¾à¤®à¤¨à¤¾à¤à¤‚!

à¤¹à¤®à¤¾à¤°à¥‡ à¤¸à¤¾à¤¥ à¤œà¥à¤¡à¤¼à¥‡ à¤°à¤¹à¤¨à¥‡ à¤•à¥‡ à¤²à¤¿à¤ à¤§à¤¨à¥à¤¯à¤µà¤¾à¤¦à¥¤''',
      'language': 'hi',
    },
    {
      'name': 'New Arrival',
      'category': 'promotion',
      'content': '''ðŸ†• à¤¨à¤ˆ à¤†à¤µà¤•!

{{customer_name}}, {{shop_name}} à¤®à¥‡à¤‚ à¤¨à¤ à¤ªà¥à¤°à¥‹à¤¡à¤•à¥à¤Ÿà¥à¤¸ à¤† à¤—à¤ à¤¹à¥ˆà¤‚!

à¤…à¤­à¥€ à¤µà¤¿à¤œà¤¼à¤¿à¤Ÿ à¤•à¤°à¥‡à¤‚ à¤”à¤° 10% à¤¡à¤¿à¤¸à¥à¤•à¤¾à¤‰à¤‚à¤Ÿ à¤ªà¤¾à¤à¤‚à¥¤

à¤‘à¤«à¤° à¤¸à¥€à¤®à¤¿à¤¤ à¤¸à¤®à¤¯ à¤•à¥‡ à¤²à¤¿à¤!''',
      'language': 'hi',
    },
    {
      'name': 'Thank You',
      'category': 'custom',
      'content': '''à¤§à¤¨à¥à¤¯à¤µà¤¾à¤¦ {{customer_name}}!

{{shop_name}} à¤¸à¥‡ à¤–à¤°à¥€à¤¦à¤¾à¤°à¥€ à¤•à¥‡ à¤²à¤¿à¤ à¤¶à¥à¤•à¥à¤°à¤¿à¤¯à¤¾à¥¤

à¤†à¤ªà¤•à¤¾ à¤­à¥à¤—à¤¤à¤¾à¤¨ â‚¹{{amount}} à¤ªà¥à¤°à¤¾à¤ªà¥à¤¤ à¤¹à¥‹ à¤—à¤¯à¤¾ à¤¹à¥ˆà¥¤

à¤«à¤¿à¤° à¤®à¤¿à¤²à¤¤à¥‡ à¤¹à¥ˆà¤‚!''',
      'language': 'hi',
    },
  ];
}
