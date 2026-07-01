import '../../../core/di/service_locator.dart';
import '../../../core/session/session_manager.dart';
import '../../../core/repository/bills_repository.dart';

enum VoiceIntentType { navigateToBill, navigateToReports, querySales, unknown }

class VoiceIntent {
  final VoiceIntentType type;
  final String? responseText;
  final Map<String, dynamic>? params;

  VoiceIntent({required this.type, this.responseText, this.params});
}

class VoiceIntentService {
  Future<VoiceIntent> parseCommand(String text) async {
    final command = text.toLowerCase();

    // 1. Navigation Intents
    if (command.contains('bill') ||
        command.contains('invoice') ||
        command.contains('sale')) {
      return VoiceIntent(
        type: VoiceIntentType.navigateToBill,
        responseText: "Opening Bill Creation...",
      );
    }

    if (command.contains('report') ||
        command.contains('profit') ||
        command.contains('loss')) {
      return VoiceIntent(
        type: VoiceIntentType.navigateToReports,
        responseText: "Opening Reports...",
      );
    }

    // 2. Query Intents
    if (command.contains('sales') && command.contains('today')) {
      try {
        final session = sl<SessionManager>();
        final repo = sl<BillsRepository>();
        final userId = session.ownerId;

        if (userId != null) {
          final result = await repo.getAll(userId: userId);
          if (result.isSuccess) {
            final now = DateTime.now();
            final todayBills = result.data!.where(
              (b) =>
                  b.date.year == now.year &&
                  b.date.month == now.month &&
                  b.date.day == now.day,
            );

            final total = todayBills.fold(0.0, (sum, b) => sum + b.grandTotal);
            return VoiceIntent(
              type: VoiceIntentType.querySales,
              responseText:
                  "Total sales today: ₹${total.toStringAsFixed(2)} across ${todayBills.length} bills.",
            );
          }
        }

        return VoiceIntent(
          type: VoiceIntentType.querySales,
          responseText: "Could not fetch sales data at the moment.",
        );
      } catch (e) {
        return VoiceIntent(
          type: VoiceIntentType.querySales,
          responseText: "Error checking sales.",
        );
      }
    }

    // 3. Fallback
    return VoiceIntent(
      type: VoiceIntentType.unknown,
      responseText:
          "I didn't quite catch that. Try saying 'Create a bill' or 'Show reports'.",
    );
  }
}
