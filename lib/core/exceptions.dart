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