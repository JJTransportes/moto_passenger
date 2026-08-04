import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:moto_passenger/modules/common_module.dart';
import 'package:moto_passenger/modules/usage_terms/data/datasources/i_usage_terms_datasource.dart';
import 'package:moto_passenger/modules/usage_terms/data/datasources/usage_terms_datasource.dart';
import 'package:moto_passenger/modules/usage_terms/data/repositories/i_usage_terms_repository.dart';
import 'package:moto_passenger/modules/usage_terms/data/repositories/usage_terms_repository.dart';
import 'package:moto_passenger/modules/usage_terms/domain/usecases/accept_terms_usecase.dart';
import 'package:moto_passenger/modules/usage_terms/domain/usecases/check_acceptance_status_usecase.dart';
import 'package:moto_passenger/modules/usage_terms/domain/usecases/i_accept_terms_usecase.dart';
import 'package:moto_passenger/modules/usage_terms/domain/usecases/i_check_acceptance_status_usecase.dart';
import 'package:moto_passenger/modules/usage_terms/presentation/blocs/usage_terms_bloc.dart';
import 'package:moto_passenger/modules/usage_terms/presentation/pages/usage_terms_guard_page.dart';

class UsageTermsModule extends Module {
  @override
  List<Module> get imports => [
    CommonModule(),
  ];

  @override
  void binds(Injector i) {
    i.add<IUsageTermsDatasource>(UsageTermsDatasource.new);
    i.add<IUsageTermsRepository>(UsageTermsRepository.new);
    i.add<ICheckAcceptanceStatusUsecase>(CheckAcceptanceStatusUsecase.new);
    i.add<IAcceptTermsUsecase>(AcceptTermsUsecase.new);
    i.addSingleton<UsageTermsBloc>(UsageTermsBloc.new);
  }

  @override
  void routes(RouteManager r) {
    r.child(
      '/',
      child: (_) => BlocProvider.value(
        value: Modular.get<UsageTermsBloc>(),
        child: const UsageTermsGuardPage(),
      ),
    );
  }
}
