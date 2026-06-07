/// Base exception class
class AppException implements Exception {
  final String message;
  final int? statusCode;

  AppException(this.message, [this.statusCode]);

  @override
  String toString() => message;
}

/// Server exception
class ServerException extends AppException {
  ServerException([super.message = 'Server error occurred', super.statusCode]);
}

/// Cache exception
class CacheException extends AppException {
  CacheException([super.message = 'Cache error occurred']);
}

/// Network exception
class NetworkException extends AppException {
  NetworkException([super.message = 'No internet connection']);
}

/// Unauthorized exception
class UnauthorizedException extends AppException {
  UnauthorizedException([String message = 'Unauthorized access'])
      : super(message, 401);
}

/// Not found exception
class NotFoundException extends AppException {
  NotFoundException([String message = 'Resource not found'])
      : super(message, 404);
}

/// Validation exception
class ValidationException extends AppException {
  ValidationException([String message = 'Validation error'])
      : super(message, 400);
}

/// Conflict exception
class ConflictException extends AppException {
  ConflictException([String message = 'Resource already exists'])
      : super(message, 409);
}
