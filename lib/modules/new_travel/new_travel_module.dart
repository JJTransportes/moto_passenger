import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:moto_passenger/core/location/location_service.dart';
import 'package:moto_passenger/core/maps/i_places_autocomplete_service.dart';
import 'package:moto_passenger/modules/common_module.dart';
import 'package:moto_passenger/modules/new_travel/data/datasources/new_travel_datasource.dart';
import 'package:moto_passenger/modules/new_travel/data/datasources/travel_tracking_datasource.dart';
import 'package:moto_passenger/modules/new_travel/data/repositories/new_travel_repository.dart';
import 'package:moto_passenger/modules/new_travel/data/repositories/travel_tracking_repository.dart';
import 'package:moto_passenger/modules/new_travel/presentation/blocs/new_travel_bloc.dart';
import 'package:moto_passenger/modules/new_travel/presentation/blocs/travel_tracking_bloc.dart';
import 'package:moto_passenger/modules/new_travel/presentation/pages/new_travel_page.dart';
import 'package:moto_passenger/modules/new_travel/presentation/pages/travel_tracking_page.dart';
import 'package:moto_passenger/modules/new_travel/presentation/pages/waiting_page.dart';

class NewTravelModule extends Module {
  @override
  List<Module> get imports => [
        CommonModule(),
      ];

  @override
  void binds(i) {
    i.add<NewTravelDatasource>(NewTravelDatasource.new);
    i.add<NewTravelRepository>(NewTravelRepository.new);
    i.addSingleton<NewTravelBloc>(
      () => NewTravelBloc(
        Modular.get<NewTravelRepository>(),
        Modular.get<LocationService>(),
        Modular.get<IPlacesAutocompleteService>(),
      ),
    );
    i.add<ITravelTrackingDatasource>(TravelTrackingDatasource.new);
    i.add<ITravelTrackingRepository>(TravelTrackingRepository.new);
    i.addSingleton<TravelTrackingBloc>(TravelTrackingBloc.new);
  }

  @override
  void routes(r) {
    r.child(
      '/',
      child: (_) => BlocProvider.value(
        value: Modular.get<NewTravelBloc>(),
        child: const NewTravelPage(),
      ),
    );
    r.child(
      '/tracking',
      child: (_) {
        final args = Modular.args.data as Map<String, dynamic>;
        return BlocProvider<TravelTrackingBloc>(
          create: (_) => Modular.get<TravelTrackingBloc>(),
          child: TravelTrackingPage(
            travelId: args['travelId'] as String,
            orderId: args['orderId'] as String?,
          ),
        );
      },
    );
    r.child(
      '/waiting',
      child: (_) {
        final args = Modular.args.data as Map<String, dynamic>;
        return WaitingPage(
          orderId: args['orderId'] as String,
        );
      },
    );
  }
}
