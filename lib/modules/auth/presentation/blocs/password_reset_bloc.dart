import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moto_passenger/core/errors/exceptions.dart';
import 'package:moto_passenger/modules/auth/domain/usecases/i_confirm_password_reset_usecase.dart';

part 'password_reset_event.dart';
part 'password_reset_state.dart';

class PasswordResetBloc extends Bloc<PasswordResetEvent, PasswordResetState> {
  final IConfirmPasswordResetUsecase _confirmPasswordResetUsecase;
  final String email;

  PasswordResetBloc(this._confirmPasswordResetUsecase, {required this.email})
      : super(const PasswordResetInitial()) {
    on<ResetConfirmSubmitted>(_onResetConfirmSubmitted);
  }

  Future<void> _onResetConfirmSubmitted(
    ResetConfirmSubmitted event,
    Emitter<PasswordResetState> emit,
  ) async {
    emit(const PasswordResetSubmitting());

    final result = await _confirmPasswordResetUsecase.call(
      email: email,
      code: event.code,
      newPassword: event.newPassword,
    );

    result.fold(
      (_) => emit(const PasswordResetSuccess()),
      (error) {
        final (message, codeConsumed) = switch (error) {
          // 409: único caso em que o status HTTP sozinho garante a causa
          // (código já usado), então oferecemos a ação "solicitar novo código".
          ConflictException() => (error.message, true),
          ValidationException() => (error.message, false),
          RateLimitedException() => (error.message, false),
          _ => (
              'Erro ao redefinir a senha. Verifique sua conexão e tente novamente.',
              false,
            ),
        };
        emit(PasswordResetError(message, codeConsumed: codeConsumed));
      },
    );
  }
}
