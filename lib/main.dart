import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:moto_passenger/app/app_module.dart';
import 'package:moto_passenger/app/app_widget.dart';
import 'package:moto_passenger/core/config/app_config.dart';
import 'package:moto_passenger/core/local_db/local_database_service.dart';
import 'package:moto_passenger/core/location/location_service.dart';
import 'package:moto_passenger/core/location/background_location_service.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load();
  await AppConfig.loadEnv();
  await LocalDatabaseService.init();

  FlutterForegroundTask.initCommunicationPort();
  PassengerBackgroundLocationService.initialize();

  await LocationService.requestPermissionIfNeeded();

  final app = ModularApp(module: AppModule(), child: const AppWidget());
  const sentryDsnFromBuild = String.fromEnvironment('SENTRY_DSN');
  const appEnvironmentFromBuild = String.fromEnvironment('APP_ENV');
  final sentryDsn =
      (sentryDsnFromBuild.isNotEmpty
              ? sentryDsnFromBuild
              : dotenv.env['SENTRY_DSN'] ?? '')
          .trim();
  final appEnvironment =
      (appEnvironmentFromBuild.isNotEmpty
              ? appEnvironmentFromBuild
              : dotenv.env['APP_ENV'] ?? 'production')
          .trim();
  if (sentryDsn.isEmpty) {
    runApp(app);
    return;
  }

  await SentryFlutter.init(
    (options) {
      options.dsn = sentryDsn;
      options.environment = appEnvironment;
      options.sendDefaultPii = false;
      options.tracesSampleRate = 0.1;
    },
    appRunner: () => runApp(app),
  );
}
