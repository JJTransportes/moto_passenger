import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:moto_passenger/modules/common_module.dart';
import 'package:moto_passenger/modules/passenger_registration/data/datasources/i_registration_datasource.dart';
import 'package:moto_passenger/modules/passenger_registration/data/datasources/registration_datasource.dart';
import 'package:moto_passenger/modules/passenger_registration/data/repositories/i_registration_repository.dart';
import 'package:moto_passenger/modules/passenger_registration/data/repositories/registration_repository.dart';
import 'package:moto_passenger/modules/passenger_registration/domain/usecases/i_load_partitions_usecase.dart';
import 'package:moto_passenger/modules/passenger_registration/domain/usecases/i_register_usecase.dart';
import 'package:moto_passenger/modules/passenger_registration/domain/usecases/load_partitions_usecase.dart';
import 'package:moto_passenger/modules/passenger_registration/domain/usecases/register_usecase.dart';
import 'package:moto_passenger/modules/passenger_registration/presentation/blocs/register_bloc.dart';
import 'package:moto_passenger/modules/passenger_registration/presentation/pages/pending_approval_page.dart';
import 'package:moto_passenger/modules/passenger_registration/presentation/pages/register_page.dart';

class PassengerRegistrationModule extends Module {
  @override
  List<Module> get imports => [
    CommonModule(),
  ];

  @override
  void binds(Injector i) {
    i.add<IRegistrationDatasource>(RegistrationDatasource.new);
    i.add<IRegistrationRepository>(RegistrationRepository.new);
    i.add<ILoadPartitionsUsecase>(LoadPartitionsUsecase.new);
    i.add<IRegisterUsecase>(RegisterUsecase.new);
    i.addSingleton<RegisterBloc>(RegisterBloc.new);
  }

  @override
  void routes(RouteManager r) {
    r.child(
      '/',
      child: (_) => BlocProvider.value(
        value: Modular.get<RegisterBloc>(),
        child: const RegisterPage(),
      ),
    );
    r.child(
      '/../pending-approval',
      child: (_) => const PendingApprovalPage(),
    );
  }
}
