import 'package:flutter_riverpod/flutter_riverpod.dart';

class LoginFormState {
  final String staffId;
  final String password;
  final String? staffIdError;
  final String? passwordError;

  const LoginFormState({
    this.staffId = '',
    this.password = '',
    this.staffIdError,
    this.passwordError,
  });

  LoginFormState copyWith({
    String? staffId,
    String? password,
    String? staffIdError,
    String? passwordError,
  }) {
    return LoginFormState(
      staffId: staffId ?? this.staffId,
      password: password ?? this.password,
      staffIdError: staffIdError,
      passwordError: passwordError,
    );
  }

  bool get isValid => staffId.isNotEmpty && password.isNotEmpty && staffIdError == null && passwordError == null;
}

class LoginFormNotifier extends StateNotifier<LoginFormState> {
  LoginFormNotifier() : super(const LoginFormState());

  void updateStaffId(String value) {
    String? error;
    if (value.isEmpty) {
      error = 'Staff ID is required';
    } else if (value.length < 3) {
      error = 'Staff ID must be at least 3 characters';
    }
    state = state.copyWith(staffId: value, staffIdError: error);
  }

  void updatePassword(String value) {
    String? error;
    if (value.isEmpty) {
      error = 'Password is required';
    } else if (value.length < 6) {
      error = 'Password must be at least 6 characters';
    }
    state = state.copyWith(password: value, passwordError: error);
  }

  void clearErrors() {
    state = state.copyWith(staffIdError: null, passwordError: null);
  }
}

final loginFormProvider = StateNotifierProvider<LoginFormNotifier, LoginFormState>((ref) {
  return LoginFormNotifier();
});
