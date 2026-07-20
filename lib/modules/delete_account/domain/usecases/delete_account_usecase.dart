import 'package:moto_passenger/core/auth/sign_out_service.dart';
import 'package:moto_passenger/modules/delete_account/data/repositories/delete_account_repository.dart';

class DeleteAccountUsecase {
  final IDeleteAccountRepository _repository;
  final SignOutService _signOutService;

  DeleteAccountUsecase(this._repository, this._signOutService);

  Future<void> execute(String password) async {
    final result = await _repository.deleteAccount(password);
    result.getOrThrow();
    await _signOutService.signOut();
  }
}
