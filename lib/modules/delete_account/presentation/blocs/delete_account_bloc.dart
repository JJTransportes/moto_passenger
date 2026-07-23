import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moto_passenger/core/errors/exceptions.dart';
import 'package:moto_passenger/modules/delete_account/domain/usecases/delete_account_usecase.dart';
import 'package:moto_passenger/modules/delete_account/presentation/blocs/delete_account_event.dart';
import 'package:moto_passenger/modules/delete_account/presentation/blocs/delete_account_state.dart';

class DeleteAccountBloc extends Bloc<DeleteAccountEvent, DeleteAccountState> {
  final DeleteAccountUsecase _usecase;

  DeleteAccountBloc(this._usecase) : super(const DeleteAccountIdle()) {
    on<SubmitDeletion>(_onSubmitDeletion);
  }

  Future<void> _onSubmitDeletion(
    SubmitDeletion event,
    Emitter<DeleteAccountState> emit,
  ) async {
    emit(const DeleteAccountLoading());

    try {
      await _usecase.execute(event.password);
      emit(const DeleteAccountSuccess());
    } on UnauthorizedException {
      emit(
        const DeleteAccountError(
          message: 'Senha incorreta.',
          type: DeleteAccountErrorType.invalidPassword,
        ),
      );
    } on ValidationException catch (e) {
      emit(
        DeleteAccountError(
          message: e.message,
          type: DeleteAccountErrorType.activeTravels,
        ),
      );
    } on Exception catch (e) {
      emit(
        DeleteAccountError(
          message: e.toString(),
          type: DeleteAccountErrorType.other,
        ),
      );
    }
  }
}
