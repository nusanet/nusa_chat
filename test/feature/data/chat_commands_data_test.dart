import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:nusa_chat/src/config/nusa_chat_config.dart';
import 'package:nusa_chat/src/core/error/failure.dart';
import 'package:nusa_chat/src/core/use_cases/use_case.dart';
import 'package:nusa_chat/src/features/data/data_sources/chat_remote_data_source.dart';
import 'package:nusa_chat/src/features/data/models/command/list_command_response.dart';
import 'package:nusa_chat/src/features/data/repositories/chat_repository_impl.dart';
import 'package:nusa_chat/src/features/domain/entities/chat_command.dart';
import 'package:nusa_chat/src/features/domain/use_cases/get_chat_commands/get_chat_commands.dart';

import '../../helper/mock_helper.mocks.dart';

void main() {
  const tStatus = ChatCommand(command: '/status', description: 'Cek status dan paket layanan internet Anda');
  const tHelpdesk = ChatCommand(command: '/chat-helpdesk', description: 'Bicara langsung dengan tim helpdesk');

  group('ChatCommand', () {
    test('pastikan cocok dengan awalan perintah, huruf besar kecil diabaikan', () {
      expect(tStatus.matches('/'), isTrue);
      expect(tStatus.matches('/st'), isTrue);
      expect(tStatus.matches('/ST'), isTrue);
      expect(tStatus.matches('/status'), isTrue);
    });

    test('pastikan tidak cocok tanpa garis miring atau dengan awalan lain', () {
      expect(tStatus.matches(''), isFalse);
      expect(tStatus.matches('status'), isFalse);
      expect(tStatus.matches('/up'), isFalse);
      expect(tStatus.matches('/statusx'), isFalse);
    });

    test('pastikan kesetaraan dan toString', () {
      expect(tStatus, const ChatCommand(command: '/status', description: 'Cek status dan paket layanan internet Anda'));
      expect(const ChatCommand(command: '/x').description, '');
      expect(tStatus.toString(), contains('/status'));
    });
  });

  group('ListCommandResponse', () {
    test('pastikan respons bridge diurai sesuai urutan', () {
      final response = ListCommandResponse.fromJson({
        'data': [
          {'command': '/status', 'description': 'Cek status dan paket layanan internet Anda'},
          {'command': '/chat-helpdesk', 'description': 'Bicara langsung dengan tim helpdesk'},
        ],
      });
      expect(response.toEntity(), [tStatus, tHelpdesk]);
    });

    test('pastikan baris tidak valid dan duplikat dibuang', () {
      final response = ListCommandResponse.fromJson({
        'data': [
          {'command': null, 'description': 'tanpa command'},
          {'command': 'status', 'description': 'tanpa garis miring'},
          {'command': '/', 'description': 'tanpa nama'},
          {'command': '/dua kata', 'description': 'ada spasi'},
          {'command': ' /status ', 'description': ' Cek status dan paket layanan internet Anda '},
          {'command': '/STATUS', 'description': 'duplikat'},
          {'command': '/login'},
        ],
      });
      expect(response.toEntity(), [tStatus, const ChatCommand(command: '/login')]);
    });

    test('pastikan data null jadi daftar kosong', () {
      expect(ListCommandResponse.fromJson(const {}).toEntity(), isEmpty);
    });

    test('pastikan toJson, kesetaraan dan toString', () {
      const row = CommandResponse(command: '/status', description: 'Cek');
      const response = ListCommandResponse(data: [row]);
      expect(response.toJson(), {
        'data': [
          {'command': '/status', 'description': 'Cek'},
        ],
      });
      expect(ListCommandResponse.fromJson(response.toJson()), response);
      expect(response.toString(), contains('/status'));
      expect(row.toString(), contains('Cek'));
    });
  });

  group('ChatRemoteDataSource.getCommands', () {
    late MockDio mockDio;
    late ChatRemoteDataSourceImpl dataSource;

    void stubGet(int status, Object? data) {
      when(mockDio.get(any)).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: status,
          data: data,
        ),
      );
    }

    setUp(() {
      mockDio = MockDio();
      dataSource = ChatRemoteDataSourceImpl(
        dio: mockDio,
        config: const NusaChatConfig(baseUrl: 'https://x', websiteId: 'web 1', origin: 'o'),
      );
    });

    test('pastikan path benar dan respons diurai', () async {
      stubGet(200, {
        'data': [
          {'command': '/status', 'description': 'Cek'},
        ],
      });

      final response = await dataSource.getCommands();

      expect(response.data!.single.command, '/status');
      verify(mockDio.get('/v1/widget/web%201/commands'));
    });

    test('pastikan DioException kalau status bukan 200', () {
      stubGet(204, null);
      expect(dataSource.getCommands(), throwsA(isA<DioException>()));
    });
  });

  group('ChatRepositoryImpl.getCommands', () {
    late MockChatRemoteDataSource mockRemote;
    late MockNetworkInfo mockNetworkInfo;
    late ChatRepositoryImpl repository;

    setUp(() {
      mockRemote = MockChatRemoteDataSource();
      mockNetworkInfo = MockNetworkInfo();
      repository = ChatRepositoryImpl(
        remoteDataSource: mockRemote,
        socketDataSource: MockChatSocketDataSource(),
        localDataSource: MockChatLocalDataSource(),
        networkInfo: mockNetworkInfo,
        config: const NusaChatConfig(baseUrl: 'https://x', websiteId: 'w', origin: 'o'),
      );
      when(mockNetworkInfo.isConnected).thenAnswer((_) async => true);
    });

    test('pastikan perintah dari bridge dikembalikan', () async {
      when(mockRemote.getCommands()).thenAnswer(
        (_) async => const ListCommandResponse(
          data: [CommandResponse(command: '/status', description: 'Cek')],
        ),
      );

      final result = await repository.getCommands();

      expect(result.getOrElse(() => const []), [const ChatCommand(command: '/status', description: 'Cek')]);
    });

    test('pastikan ConnectionFailure kalau offline', () async {
      when(mockNetworkInfo.isConnected).thenAnswer((_) async => false);

      final result = await repository.getCommands();

      expect(result.fold((failure) => failure, (_) => null), isA<ConnectionFailure>());
      verifyZeroInteractions(mockRemote);
    });

    test('pastikan ServerFailure kalau bridge menolak', () async {
      final options = RequestOptions(path: '/');
      when(mockRemote.getCommands()).thenThrow(
        DioException(
          requestOptions: options,
          response: Response(requestOptions: options, statusCode: 403, data: {'error': 'origin tidak diizinkan'}),
        ),
      );

      final result = await repository.getCommands();

      final failure = result.fold((failure) => failure, (_) => null);
      expect(failure, isA<ServerFailure>());
      expect((failure! as ServerFailure).dataApiFailure.statusCode, 403);
    });

    test('pastikan ParsingFailure kalau respons rusak', () async {
      when(mockRemote.getCommands()).thenThrow(const FormatException('rusak'));

      final result = await repository.getCommands();

      expect(result.fold((failure) => failure, (_) => null), isA<ParsingFailure>());
    });
  });

  group('GetChatCommands', () {
    test('pastikan diteruskan ke repository', () async {
      final mockRepository = MockChatRepository();
      when(mockRepository.getCommands()).thenAnswer((_) async => const Right([tStatus]));

      final result = await GetChatCommands(repository: mockRepository)(NoParams());

      expect(result, const Right<Failure, List<ChatCommand>>([tStatus]));
      verify(mockRepository.getCommands());
    });
  });
}
