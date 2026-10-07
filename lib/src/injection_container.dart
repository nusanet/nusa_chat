import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:nusa_chat/src/config/nusa_chat_config.dart';
import 'package:nusa_chat/src/core/service/network_info.dart';
import 'package:nusa_chat/src/features/data/data_sources/chat_local_data_source.dart';
import 'package:nusa_chat/src/features/data/data_sources/chat_remote_data_source.dart';
import 'package:nusa_chat/src/features/data/data_sources/chat_socket_data_source.dart';
import 'package:nusa_chat/src/features/data/repositories/chat_repository_impl.dart';
import 'package:nusa_chat/src/features/domain/repositories/chat/chat_repository.dart';
import 'package:nusa_chat/src/features/domain/use_cases/connect_chat_socket/connect_chat_socket.dart';
import 'package:nusa_chat/src/features/domain/use_cases/disconnect_chat_socket/disconnect_chat_socket.dart';
import 'package:nusa_chat/src/features/domain/use_cases/get_chat_history/get_chat_history.dart';
import 'package:nusa_chat/src/features/domain/use_cases/send_chat_location/send_chat_location.dart';
import 'package:nusa_chat/src/features/domain/use_cases/send_chat_media/send_chat_media.dart';
import 'package:nusa_chat/src/features/domain/use_cases/send_chat_text/send_chat_text.dart';
import 'package:nusa_chat/src/features/domain/use_cases/start_chat_session/start_chat_session.dart';
import 'package:nusa_chat/src/features/presentation/bloc/chat/bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Builds the dependency graph of one chat screen.
///
/// The plugin uses its own [GetIt] instance (never `GetIt.instance`) so its
/// registrations cannot collide with the host app's. One container per
/// [NusaChatConfig]; [dispose] it with the screen.
class NusaChatInjector {
  final GetIt sl;

  NusaChatInjector._(this.sl);

  factory NusaChatInjector.init(NusaChatConfig config, {Dio? dio, NetworkInfo? networkInfo}) {
    final sl = GetIt.asNewInstance();

    // Config
    sl.registerSingleton<NusaChatConfig>(config);

    // Bloc
    sl.registerFactory(
      () => ChatBloc(
        startChatSession: sl(),
        getChatHistory: sl(),
        connectChatSocket: sl(),
        sendChatText: sl(),
        sendChatMedia: sl(),
        sendChatLocation: sl(),
        disconnectChatSocket: sl(),
      ),
    );

    // Use Case
    sl.registerLazySingleton(() => StartChatSession(repository: sl()));
    sl.registerLazySingleton(() => GetChatHistory(repository: sl()));
    sl.registerLazySingleton(() => ConnectChatSocket(repository: sl()));
    sl.registerLazySingleton(() => SendChatText(repository: sl()));
    sl.registerLazySingleton(() => SendChatMedia(repository: sl()));
    sl.registerLazySingleton(() => SendChatLocation(repository: sl()));
    sl.registerLazySingleton(() => DisconnectChatSocket(repository: sl()));

    // Repository
    sl.registerLazySingleton<ChatRepository>(
      () => ChatRepositoryImpl(
        remoteDataSource: sl(),
        socketDataSource: sl(),
        localDataSource: sl(),
        networkInfo: sl(),
        config: sl(),
      ),
    );

    // Data Source
    sl.registerLazySingleton<ChatRemoteDataSource>(() => ChatRemoteDataSourceImpl(dio: sl(), config: sl()));
    sl.registerLazySingleton<ChatSocketDataSource>(() => ChatSocketDataSourceImpl());
    sl.registerLazySingleton<ChatLocalDataSource>(() => ChatLocalDataSourceImpl(preferences: SharedPreferencesAsync()));

    // Core
    sl.registerLazySingleton<NetworkInfo>(() => networkInfo ?? NetworkInfoImpl(Connectivity()));
    sl.registerLazySingleton<Dio>(() => dio ?? _buildDio(config));

    return NusaChatInjector._(sl);
  }

  static Dio _buildDio(NusaChatConfig config) {
    final dio = Dio(
      BaseOptions(
        baseUrl: config.normalizedBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        contentType: Headers.jsonContentType,
        // Mobile has no page origin; the bridge checks it against allowed_origins.
        headers: {'Origin': config.origin},
      ),
    );
    if (config.enableLog && kDebugMode) {
      dio.interceptors.add(
        LogInterceptor(requestBody: true, responseBody: true, logPrint: (object) => debugPrint(object.toString())),
      );
    }
    return dio;
  }

  ChatBloc createChatBloc() => sl<ChatBloc>();

  Future<void> dispose() => sl.reset();
}
