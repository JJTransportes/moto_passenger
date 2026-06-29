import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moto_passenger/modules/passenger_registration/domain/entities/public_partition_entity.dart';
import 'package:moto_passenger/modules/passenger_registration/domain/entities/register_passenger_request.dart';
import 'package:moto_passenger/modules/passenger_registration/domain/usecases/i_load_partitions_usecase.dart';
import 'package:moto_passenger/modules/passenger_registration/domain/usecases/i_register_usecase.dart';

part 'register_event.dart';
part 'register_state.dart';

class RegisterBloc extends Bloc<RegisterEvent, RegisterState> {
  final ILoadPartitionsUsecase _loadPartitionsUsecase;
  final IRegisterUsecase _registerUsecase;

  RegisterBloc(this._loadPartitionsUsecase, this._registerUsecase)
      : super(const RegisterInitial()) {
    on<LoadPartitions>(_onLoadPartitions);
    on<RegisterSubmitted>(_onRegisterSubmitted);
  }

  Future<void> _onLoadPartitions(
    LoadPartitions event,
    Emitter<RegisterState> emit,
  ) async {
    emit(const PartitionsLoading());

    final result = await _loadPartitionsUsecase.call();

    result.fold(
      (partitions) => emit(PartitionsLoaded(partitions)),
      (error) =>
          emit(PartitionsError(error.toString())),
    );
  }

  Future<void> _onRegisterSubmitted(
    RegisterSubmitted event,
    Emitter<RegisterState> emit,
  ) async {
    emit(const RegisterSubmitting());

    final request = RegisterPassengerRequest(
      fullName: event.fullName,
      cpf: event.cpf,
      rg: event.rg,
      registration: event.registration,
      birthdate: event.birthdate,
      email: event.email,
      initialPassword: event.initialPassword,
      department: event.department,
      publicPartitionId: event.publicPartitionId,
    );

    final result = await _registerUsecase.call(request);

    result.fold(
      (_) => emit(const RegisterSuccess()),
      (error) => emit(RegisterFailure(error.toString())),
    );
  }
}
