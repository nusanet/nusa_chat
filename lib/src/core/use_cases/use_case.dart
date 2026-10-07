import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:nusa_chat/src/core/error/failure.dart';

abstract class UseCase<T, Params> {
  Future<Either<Failure, T>> call(Params params);
}

/// A use case that yields a stream of values, e.g. real-time socket events.
abstract class StreamUseCase<T, Params> {
  Stream<T> call(Params params);
}

class NoParams extends Equatable {
  @override
  List<Object> get props => [];
}
