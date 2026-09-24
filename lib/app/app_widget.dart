import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:moto_passenger/core/navigation/app_messenger.dart';
import 'package:moto_passenger/core/navigation/route_observer.dart';
import 'package:moto_passenger/core/theme/app_theme.dart';

class AppWidget extends StatelessWidget {
  const AppWidget({super.key});

  @override
  Widget build(BuildContext context) {
    Modular.setObservers([appRouteObserver]);
    return MaterialApp.router(
      title: 'Moto Passageiro',
      scaffoldMessengerKey: appScaffoldMessengerKey,
      theme: AppTheme.theme,
      debugShowCheckedModeBanner: false,
      locale: const Locale('pt', 'BR'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('pt', 'BR'),
      ],
      routerConfig: Modular.routerConfig,
    );
  }
}
