import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:moto_passenger/app/app_module.dart';
import 'package:moto_passenger/app/app_widget.dart';
import 'package:moto_passenger/core/config/app_config.dart';
import 'package:moto_passenger/core/local_db/local_database_service.dart';
import 'package:moto_passenger/core/location/location_service.dart';
import 'package:moto_passenger/core/notifications/deep_link_holder.dart';
import 'package:moto_passenger/core/notifications/notification_handler.dart';
import 'package:moto_passenger/core/notifications/push_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load();
  await AppConfig.loadEnv();
  await LocalDatabaseService.init();

  await LocationService.requestPermissionIfNeeded();

  // Inicializar OneSignal ANTES de runApp (cold start notifications)
  final pushService = PushNotificationService();
  unawaited(
    pushService.initialize().timeout(
      const Duration(seconds: 10),
      onTimeout: () => debugPrint('[PUSH] Init timeout — continuing without push'),
    ),
  );

  // Registrar listener para taps em notificação.
  // OneSignal v5 gerencia cold start automaticamente — o click listener
  // dispara tanto para cold start (buffered) quanto warm start.
  // O SplashScreen tem delay de 2s, dando tempo para o listener disparar.
  pushService.onNotificationTap.listen((data) {
    debugPrint('[PUSH] Notification tap: type=${data.type}');
    DeepLinkHolder.store(data);
    // Se o SplashScreen já passou (warm start), processa imediatamente
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationHandler.handleNotificationTap(data);
    });
  });

  runApp(
    ModularApp(
      module: AppModule(),
      child: const AppWidget(),
    ),
  );
}
