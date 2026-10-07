import 'package:equatable/equatable.dart';
import 'package:nusa_chat/src/core/util/constant_error_message.dart';
import 'package:nusa_chat/src/features/data/models/data_api_failure/data_api_failure.dart';

/// Class abstrak [Failure].
abstract class Failure extends Equatable {
  /// Message that can be shown to the user.
  String get message;
}

/// Class ini berfungsi sebagai state jika app mengalami kegagalan dari API.
/// Dan class ini memiliki property [dataApiFailure].
class ServerFailure extends Failure {
  final DataApiFailure dataApiFailure;

  ServerFailure(this.dataApiFailure);

  @override
  String get message => dataApiFailure.message ?? ConstantErrorMessage.failureServer;

  @override
  List<Object> get props => [dataApiFailure];

  @override
  String toString() {
    return 'ServerFailure{dataApiFailure: $dataApiFailure}';
  }
}

/// Class ini berfungsi sebagai state jika app mengalami kegagalan ketika mengambil data dari lokal/database.
/// Dan class ini memiliki property [errorMessage].
class CacheFailure extends Failure {
  final String errorMessage;

  CacheFailure(this.errorMessage);

  @override
  String get message => errorMessage;

  @override
  List<Object> get props => [errorMessage];

  @override
  String toString() {
    return 'CacheFailure{errorMessage: $errorMessage}';
  }
}

/// Class ini berfungsi sebagai state jika app dalam kondisi tidak terhubung ke mobile data/wifi.
/// Didalam class ini memiliki property [errorMessage].
class ConnectionFailure extends Failure {
  final String errorMessage = ConstantErrorMessage.connectionError;

  @override
  String get message => errorMessage;

  @override
  List<Object> get props => [errorMessage];

  @override
  String toString() {
    return 'ConnectionFailure{errorMessage: $errorMessage}';
  }
}

class ParsingFailure extends Failure {
  final String errorMessage;

  ParsingFailure(this.errorMessage);

  @override
  String get message => ConstantErrorMessage.failureParsing;

  @override
  List<Object> get props => [errorMessage];

  @override
  String toString() {
    return 'ParsingFailure{errorMessage: $errorMessage}';
  }
}

/// Class ini berfungsi sebagai state jika koneksi WebSocket gagal dibuka atau tidak tersedia.
class SocketFailure extends Failure {
  final String errorMessage;

  SocketFailure(this.errorMessage);

  @override
  String get message => errorMessage;

  @override
  List<Object> get props => [errorMessage];

  @override
  String toString() {
    return 'SocketFailure{errorMessage: $errorMessage}';
  }
}
