class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class UnauthorizedException extends ApiException {
  UnauthorizedException(
      [String message = 'Session expired. Please log in again.'])
      : super(message, statusCode: 401);
}

class ServerException extends ApiException {
  ServerException(String message, int statusCode)
      : super(message, statusCode: statusCode);
}

class NetworkException extends ApiException {
  NetworkException([String message = 'No internet connection.'])
      : super(message);
}


/// The device's API base URL is missing, so no request can even be addressed.
///
/// Raised instead of firing a hostless '/9009' at http and letting the
/// ArgumentError fall into a generic catch — that path showed the user an
/// empty screen with no explanation.
class MissingApiUrlException extends ApiException {
  MissingApiUrlException([
    String message =
        'App configuration was lost. Please log in again.',
  ]) : super(message);
}
