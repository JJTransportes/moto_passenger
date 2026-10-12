import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:moto_passenger/core/navigation/app_messenger.dart';
import 'package:moto_passenger/core/auth/sign_out_service.dart';
import 'package:moto_passenger/core/location/mandatory_location_gate.dart';
import 'package:moto_passenger/core/network/mandatory_connectivity_gate.dart';
import 'package:moto_passenger/core/network/signalr_service.dart';
import 'package:moto_passenger/core/profile/mandatory_phone_gate.dart';
import 'package:moto_passenger/core/navigation/route_observer.dart';
import 'package:moto_passenger/core/update/mandatory_update_gate.dart';
import 'package:moto_passenger/design_system/design_system.dart';

class AppWidget extends StatefulWidget {
  const AppWidget({super.key});

  @override
  State<AppWidget> createState() => _AppWidgetState();
}

class _AppWidgetState extends State<AppWidget> {
  StreamSubscription<Map<String, dynamic>>? _sessionRevokedSubscription;
  bool _handlingSessionRevocation = false;

  @override
  void initState() {
    super.initState();
    _sessionRevokedSubscription = Modular.get<SignalRService>().onSessionRevoked
        .listen((_) => _handleSessionRevoked());
  }

  Future<void> _handleSessionRevoked() async {
    if (_handlingSessionRevocation) return;
    _handlingSessionRevocation = true;
    try {
      await Modular.get<SignalRService>().disconnectAll();
      await Modular.get<SignOutService>().signOut(
        message:
            'Sua sessão foi encerrada porque os dados de acesso da conta foram alterados.',
      );
    } finally {
      _handlingSessionRevocation = false;
    }
  }

  @override
  void dispose() {
    _sessionRevokedSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Modular.setObservers([appRouteObserver]);
    return MaterialApp.router(
      title: 'Moto Passageiro',
      scaffoldMessengerKey: appScaffoldMessengerKey,
      theme: MotoTheme.claro(),
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
      builder: (context, child) => MandatoryUpdateGate(
        child: MandatoryConnectivityGate(
          child: MandatoryLocationGate(
            child: MandatoryPhoneGate(child: child!),
          ),
        ),
      ),
      routerConfig: Modular.routerConfig,
    );
  }
}
