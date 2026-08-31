import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:moto_passenger/modules/common_module.dart';
import 'package:moto_passenger/modules/passenger_home/data/datasources/i_passenger_home_datasource.dart';
import 'package:moto_passenger/modules/passenger_home/data/datasources/passenger_home_datasource.dart';
import 'package:moto_passenger/modules/passenger_home/data/repositories/passenger_home_repository.dart';
import 'package:moto_passenger/modules/passenger_home/domain/repositories/i_passenger_home_repository.dart';
import 'package:moto_passenger/modules/passenger_home/domain/usecases/get_passenger_profile_usecase.dart';
import 'package:moto_passenger/modules/passenger_home/domain/usecases/get_travels_usecase.dart';
import 'package:moto_passenger/modules/passenger_home/domain/usecases/i_get_passenger_profile_usecase.dart';
import 'package:moto_passenger/modules/passenger_home/domain/usecases/i_get_travels_usecase.dart';
import 'package:moto_passenger/modules/passenger_home/presentation/blocs/passenger_home_bloc.dart';
import 'package:moto_passenger/modules/passenger_home/presentation/pages/passenger_home_page.dart';
import 'package:moto_passenger/screens/travel_history_page.dart';

class PassengerHomeModule extends Module {
  @override
  List<Module> get imports => [
    CommonModule(),
  ];

  @override
  void binds(i) {
    i.add<IPassengerHomeDatasource>(PassengerHomeDatasource.new);
    i.add<IPassengerHomeRepository>(PassengerHomeRepository.new);
    i.add<IGetPassengerProfileUsecase>(GetPassengerProfileUsecase.new);
    i.add<IGetActiveTravelUsecase>(GetActiveTravelUsecase.new);
    i.add<IGetLastTravelsUsecase>(GetLastTravelsUsecase.new);
    i.addSingleton<PassengerHomeBloc>(PassengerHomeBloc.new);
  }

  @override
  void routes(r) {
    r.child(
      '/',
      child: (_) => BlocProvider.value(
        value: Modular.get<PassengerHomeBloc>(),
        child: const PassengerHomePage(),
      ),
    );
    r.child('/travel-history', child: (_) => const TravelHistoryPage());
  }
}
