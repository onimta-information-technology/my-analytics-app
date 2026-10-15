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

/// The member already has an active follow-up (HTTP 409 from
/// `followup_Insert`). Carries the server's message plus who holds the
/// existing follow-up, so the UI can tell the user to unfollow it first.
class AlreadyFollowedException extends ApiException {
  final int? followupId;
  final String? loginBy;
  final String? salesCode;
  final String? memberName;
  final DateTime? insertDate;

  AlreadyFollowedException(
    String message, {
    this.followupId,
    this.loginBy,
    this.salesCode,
    this.memberName,
    this.insertDate,
  }) : super(message, statusCode: 409);

  factory AlreadyFollowedException.fromJson(Map<String, dynamic> json) {
    final existing = json['existing_followup'] as Map<String, dynamic>?;
    return AlreadyFollowedException(
      json['Message'] as String? ??
          'This member already has an active follow-up.',
      followupId: existing?['followup_id'] as int?,
      loginBy: existing?['login_by'] as String?,
     // salesCode: existing?['sales_code'] as String?,
      memberName: existing?['mname'] as String?,
      insertDate: DateTime.tryParse(existing?['insert_date'] as String? ?? ''),
    );
  }
}
