import 'package:dartz/dartz.dart' show Either;
import 'package:flutter/foundation.dart';
import 'package:nusa_chat/src/config/nusa_chat_config.dart';
import 'package:nusa_chat/src/core/error/failure.dart';
import 'package:nusa_chat/src/core/use_cases/use_case.dart';
import 'package:nusa_chat/src/features/domain/entities/chat_session.dart';
import 'package:nusa_chat/src/features/domain/repositories/chat/chat_repository.dart';
import 'package:nusa_chat/src/features/domain/use_cases/start_chat_session/start_chat_session.dart';
import 'package:nusa_chat/src/injection_container.dart';

/// Talks to the bridge outside `NusaChatPage`, for the host app's own views
/// (e.g. a "continue chat" entry). Nothing here opens the socket.
///
/// ```dart
/// final client = NusaChatClient(config);
/// final session = await client.getActiveSession();
/// await client.dispose();
/// ```
///
/// Methods throw [NusaChatException] when the request fails.
class NusaChatClient {
  final ChatRepository Function() _repository;
  final Future<void> Function()? _onDispose;

  // Resolved on first use, so creating a client costs nothing.
  late final _startChatSession = StartChatSession(repository: _repository());

  NusaChatClient._(this._repository, this._onDispose);

  factory NusaChatClient(NusaChatConfig config) {
    final injector = NusaChatInjector.init(config);
    return NusaChatClient._(() => injector.sl(), injector.dispose);
  }

  @visibleForTesting
  factory NusaChatClient.withRepository(ChatRepository repository) => NusaChatClient._(() => repository, null);

  /// The visitor's open conversation, from the server (`POST .../sessions`,
  /// the same bootstrap the chat screen does — it also sends
  /// [NusaChatConfig.fcmToken]). When none is open, e.g. the last one was
  /// closed after 24h idle, the server opens a new one.
  Future<ChatSession> getActiveSession() async => _unwrap(await _startChatSession(NoParams()));

  Future<void> dispose() async => _onDispose?.call();

  static T _unwrap<T>(Either<Failure, T> result) {
    return result.fold(
      (failure) => throw NusaChatException(
        failure.message,
        statusCode: failure is ServerFailure ? failure.dataApiFailure.statusCode : null,
      ),
      (value) => value,
    );
  }
}

/// A [NusaChatClient] request failed; [message] can be shown to the user.
class NusaChatException implements Exception {
  final String message;

  /// HTTP status of a server error; null for connection and parsing errors.
  final int? statusCode;

  const NusaChatException(this.message, {this.statusCode});

  @override
  String toString() => 'NusaChatException{message: $message, statusCode: $statusCode}';
}
