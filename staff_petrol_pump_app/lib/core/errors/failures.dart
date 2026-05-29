abstract class Failure {
  final String message;
  
  Failure({required this.message});
}

class ServerFailure extends Failure {
  ServerFailure({required String message}) : super(message: message);
}

class NetworkFailure extends Failure {
  NetworkFailure({required String message}) : super(message: message);
}

class AuthFailure extends Failure {
  AuthFailure({required String message}) : super(message: message);
}

class BiometricFailure extends Failure {
  BiometricFailure({required String message}) : super(message: message);
}
