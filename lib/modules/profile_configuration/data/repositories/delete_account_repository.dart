import 'package:moto_passenger/modules/delete_account/data/datasources/delete_account_datasource.dart';
import 'package:result_dart/result_dart.dart';

abstract class IDeleteAccountRepository {
  /// Deletes the current user's account after verifying the password.
  /// Returns Success(true) on success or Failure with the exception.
  AsyncResult<bool> deleteAccount(String password);
}

class DeleteAccountRepository implements IDeleteAccountRepository {
  final IDeleteAccountDatasource _datasource;

  DeleteAccountRepository(this._datasource);

  @override
  AsyncResult<bool> deleteAccount(String password) async {
    try {
      await _datasource.deleteAccount(password);
      return const Success(true);
    } on Exception catch (e) {
      return Failure(e);
    }
  }
}
