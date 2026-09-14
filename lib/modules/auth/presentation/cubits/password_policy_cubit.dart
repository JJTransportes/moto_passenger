import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moto_passenger/modules/auth/domain/entities/password_policy_entity.dart';
import 'package:moto_passenger/modules/auth/domain/usecases/i_get_password_policy_usecase.dart';

/// Estado sempre válido — nunca expõe erro para a UI. Se `GET
/// /api/auth/password-policy` falhar, emite [PasswordPolicy.fallback].
class PasswordPolicyCubit extends Cubit<PasswordPolicy> {
  final IGetPasswordPolicyUsecase _usecase;

  PasswordPolicyCubit(this._usecase) : super(PasswordPolicy.fallback);

  Future<void> load() async {
    final result = await _usecase.call();
    emit(result.fold((policy) => policy, (_) => PasswordPolicy.fallback));
  }
}
