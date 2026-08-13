abstract class Failure {
  final String message;
  final String? code;

  const Failure(this.message, {this.code});

  @override
  String toString() => message;
}

class NetworkFailure extends Failure {
  const NetworkFailure([
    super.message =
        'No internet connection or server timeout. Please try again.',
  ]);
}

class AuthFailure extends Failure {
  const AuthFailure(super.message, {super.code});
}

class RateLimitFailure extends Failure {
  const RateLimitFailure([
    super.message =
        'You have 3 active unresolved booking requests. Please wait for an existing request to resolve before submitting a new one.',
  ]);
}

class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

class ServerFailure extends Failure {
  const ServerFailure([
    super.message = 'A server error occurred. Please try again later.',
    String? code,
  ]) : super(code: code);
}
