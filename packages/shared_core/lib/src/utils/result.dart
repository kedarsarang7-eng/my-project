sealed class Result<T> {
  const Result();
}

final class Success<T> extends Result<T> {
  final T value;
  const Success(this.value);
}

final class Failure<T> extends Result<T> {
  final Object error;
  final StackTrace? stackTrace;
  const Failure(this.error, [this.stackTrace]);
}

extension ResultX<T> on Result<T> {
  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Failure<T>;

  T? get valueOrNull => switch (this) {
        Success(:final value) => value,
        Failure() => null,
      };

  Object? get errorOrNull => switch (this) {
        Success() => null,
        Failure(:final error) => error,
      };

  R when<R>({
    required R Function(T value) success,
    required R Function(Object error) failure,
  }) =>
      switch (this) {
        Success(:final value) => success(value),
        Failure(:final error) => failure(error),
      };
}
