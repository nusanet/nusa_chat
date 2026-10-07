import 'package:equatable/equatable.dart';

/// Class model ini berfungsi untuk menyimpan info-info kegagalan dari API.
/// [statusCode] nilai respon kode dari API.
/// [message] message yang ada di respon API (field `error` dari bridge).
/// [httpMessage] message yang dibuat oleh http request atau Dio.
class DataApiFailure extends Equatable {
  final int? statusCode;
  final String? message;
  final String? httpMessage;

  const DataApiFailure({this.statusCode, this.message, this.httpMessage});

  @override
  List<Object?> get props => [statusCode, message, httpMessage];

  @override
  String toString() {
    return 'DataApiFailure{statusCode: $statusCode, message: $message, httpMessage: $httpMessage}';
  }
}
