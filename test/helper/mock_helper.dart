import 'package:dio/dio.dart';
import 'package:mockito/annotations.dart';
import 'package:nusa_chat/src/core/service/network_info.dart';
import 'package:nusa_chat/src/features/data/data_sources/chat_local_data_source.dart';
import 'package:nusa_chat/src/features/data/data_sources/chat_remote_data_source.dart';
import 'package:nusa_chat/src/features/data/data_sources/chat_socket_data_source.dart';
import 'package:nusa_chat/src/features/domain/repositories/chat/chat_repository.dart';

@GenerateNiceMocks([
  MockSpec<Dio>(),
  MockSpec<NetworkInfo>(),
  MockSpec<ChatRemoteDataSource>(),
  MockSpec<ChatSocketDataSource>(),
  MockSpec<ChatLocalDataSource>(),
  MockSpec<ChatRepository>(),
])
void main() {}
