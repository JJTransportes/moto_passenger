import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:moto_passenger/modules/common_module.dart';
import 'package:moto_passenger/modules/delete_account/data/datasources/delete_account_datasource.dart';
import 'package:moto_passenger/modules/delete_account/data/repositories/delete_account_repository.dart';
import 'package:moto_passenger/modules/delete_account/domain/usecases/delete_account_usecase.dart';
import 'package:moto_passenger/modules/delete_account/presentation/blocs/delete_account_bloc.dart';
import 'package:moto_passenger/modules/delete_account/presentation/pages/delete_account_page.dart';

class DeleteAccountModule extends Module {
  @override
  List<Module> get imports => [
    CommonModule(),
  ];

  @override
  void binds(Injector i) {
    i.add<IDeleteAccountDatasource>(DeleteAccountDatasource.new);
    i.add<IDeleteAccountRepository>(DeleteAccountRepository.new);
    i.add<DeleteAccountUsecase>(DeleteAccountUsecase.new);
    i.addSingleton<DeleteAccountBloc>(DeleteAccountBloc.new);
  }

  @override
  void routes(RouteManager r) {
    r.child(
      '/',
      child: (_) => BlocProvider.value(
        value: Modular.get<DeleteAccountBloc>(),
        child: DeleteAccountPage(),
      ),
    );
  }
}
