class CacheException implements Exception {}

class ConnectionException implements Exception {}

/// Thrown when the WebSocket cannot be opened or is not open when sending.
class SocketException implements Exception {
  final String message;

  SocketException(this.message);

  @override
  String toString() => 'SocketException{message: $message}';
}
