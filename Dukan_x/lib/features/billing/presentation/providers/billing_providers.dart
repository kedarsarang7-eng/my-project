import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/service_locator.dart';
import '../../data/datasources/speech_service.dart';
import '../../domain/usecases/process_voice_command.dart';
import '../../domain/usecases/parse_voice_intent.dart';
import '../../../../core/repository/products_repository.dart';
import '../../../../core/session/session_manager.dart';

final speechServiceProvider = Provider<SpeechService>((ref) {
  return SpeechService();
});

/// Process voice command use case using new Repositories
final processVoiceCommandProvider = Provider<ProcessVoiceCommand>((ref) {
  return ProcessVoiceCommand(sl<ProductsRepository>(), sl<SessionManager>());
});

final parseVoiceIntentProvider = Provider<ParseVoiceIntent>((ref) {
  return ParseVoiceIntent(sl<ProductsRepository>(), sl<SessionManager>());
});
