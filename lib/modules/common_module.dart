import 'package:dio/dio.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:moto_passenger/core/auth/auth_storage.dart';
import 'package:moto_passenger/core/auth/sign_out_service.dart';
import 'package:moto_passenger/core/http/dio_client.dart';
import 'package:moto_passenger/core/local_db/repositories/auth_local_repository.dart';
import 'package:moto_passenger/core/local_db/repositories/profile_local_repository.dart';
import 'package:moto_passenger/core/local_db/repositories/travel_local_repository.dart';
import 'package:moto_passenger/core/location/location_service.dart';
import 'package:moto_passenger/core/location/background_location_service.dart';
import 'package:moto_passenger/core/maps/i_places_autocomplete_service.dart';
import 'package:moto_passenger/core/maps/places_autocomplete_service.dart';
import 'package:moto_passenger/core/network/signalr_service.dart';
import 'package:moto_passenger/core/notifications/i_push_notification_service.dart';
import 'package:moto_passenger/core/notifications/notification_channel_service.dart';
import 'package:moto_passenger/core/notifications/notification_handler.dart';
import 'package:moto_passenger/core/notifications/onesignal_gateway.dart';
import 'package:moto_passenger/core/notifications/onesignal_push_service.dart';
import 'package:moto_passenger/core/notifications/pending_notification_router.dart';
import 'package:moto_passenger/modules/auth/data/datasources/auth_datasource.dart';
import 'package:moto_passenger/modules/auth/data/datasources/i_auth_datasource.dart';
import 'package:moto_passenger/modules/auth/data/repositories/auth_repository.dart';
import 'package:moto_passenger/modules/auth/domain/repositories/i_auth_repository.dart';

class CommonModule extends Module {
  @override
  void binds(Injector i) {
    i.addSingleton<Dio>(DioClient.create);
    i.addSingleton<AuthStorage>(AuthStorage.new);
    i.addSingleton<PassengerBackgroundLocationService>(
      PassengerBackgroundLocationService.new,
    );
    i.addSingleton<AuthLocalRepository>(AuthLocalRepository.new);
    i.addSingleton<ProfileLocalRepository>(ProfileLocalRepository.new);
    i.addSingleton<TravelLocalRepository>(TravelLocalRepository.new);
    i.addSingleton<SignOutService>(SignOutService.new);
    i.addSingleton<SignalRService>(SignalRService.new);
    // Push (spec passenger-push-notifications): o SDK fica atrás de uma interface e o
    // serviço é único por execução, para inicializar uma só vez.
    i.addSingleton<IOneSignalGateway>(OneSignalSdkGateway.new);
    i.addSingleton<IPushNotificationService>(
      () => OneSignalPushService(
        Modular.get<IOneSignalGateway>(),
        Modular.get<IAuthDatasource>(),
      ),
    );
    i.addSingleton<INotificationChannelService>(() => NotificationChannelService());
    i.addSingleton<PendingNotificationRouter>(
      () =>
          PendingNotificationRouter(NotificationHandler.handleNotificationTap),
    );
    i.addSingleton<LocationService>(LocationService.new);
    i.addSingleton<IPlacesAutocompleteService>(PlacesAutocompleteService.new);
    i.add<IAuthDatasource>(AuthDatasource.new);
    i.add<IAuthRepository>(AuthRepository.new);
  }
}
