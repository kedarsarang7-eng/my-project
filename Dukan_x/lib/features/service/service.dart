/// Service module exports
library;

// Models
export 'models/service_job.dart';
export 'models/imei_serial.dart';
export 'models/exchange.dart';

// Repositories
export 'data/repositories/service_job_repository.dart';
export 'data/repositories/imei_serial_repository.dart';
export 'data/repositories/exchange_repository.dart';

// Services
export 'services/service_job_service.dart';
export 'services/imei_validation_service.dart';
export 'services/exchange_service.dart';

// Screens
export 'presentation/screens/service_job_list_screen.dart';
export 'presentation/screens/create_service_job_screen.dart';
export 'presentation/screens/service_job_detail_screen.dart';
export 'presentation/screens/exchange_list_screen.dart';
export 'presentation/screens/create_exchange_screen.dart';
export 'presentation/screens/exchange_detail_screen.dart';
