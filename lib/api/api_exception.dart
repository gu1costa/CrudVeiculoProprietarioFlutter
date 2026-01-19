class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException(this.message, this.statusCode);

  @override
  String toString() => "ApiException($statusCode): $message";
}
