part of 'register_bloc.dart';

sealed class RegisterState {
  const RegisterState();
}

final class RegisterInitial extends RegisterState {
  const RegisterInitial();
}

final class PartitionsLoading extends RegisterState {
  const PartitionsLoading();
}

final class PartitionsLoaded extends RegisterState {
  final List<PublicPartition> partitions;

  const PartitionsLoaded(this.partitions);
}

final class PartitionsError extends RegisterState {
  final String message;

  const PartitionsError(this.message);
}

final class RegisterSubmitting extends RegisterState {
  const RegisterSubmitting();
}

final class RegisterSuccess extends RegisterState {
  const RegisterSuccess();
}

final class RegisterFailure extends RegisterState {
  final String message;

  const RegisterFailure(this.message);
}
