import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import 'package:moto_passenger/core/location/background_location_service.dart';

/// Impede o uso do app Android sem as permissões necessárias para manter a
/// localização do passageiro durante todo o fluxo da corrida.
class MandatoryLocationGate extends StatefulWidget {
  final Widget child;
  final Future<PassengerBackgroundLocationPermission> Function(bool request)?
  permissionCheck;
  final bool? isAndroid;

  const MandatoryLocationGate({
    super.key,
    required this.child,
    this.permissionCheck,
    this.isAndroid,
  });

  @override
  State<MandatoryLocationGate> createState() => _MandatoryLocationGateState();
}

class _MandatoryLocationGateState extends State<MandatoryLocationGate>
    with WidgetsBindingObserver {
  PassengerBackgroundLocationPermission? _status;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check(request: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check({bool request = false}) async {
    if (!(widget.isAndroid ?? Platform.isAndroid)) {
      if (mounted) setState(() => _checking = false);
      return;
    }

    if (mounted) setState(() => _checking = true);
    PassengerBackgroundLocationPermission status;
    if (widget.permissionCheck case final checker?) {
      status = await checker(request);
    } else if (!await Geolocator.isLocationServiceEnabled()) {
      status = PassengerBackgroundLocationPermission.serviceDisabled;
    } else {
      var location = await Geolocator.checkPermission();
      if (request && location == LocationPermission.denied) {
        location = await Geolocator.requestPermission();
      }
      if (location == LocationPermission.deniedForever) {
        status = PassengerBackgroundLocationPermission.locationDeniedForever;
      } else if (location == LocationPermission.denied) {
        status = PassengerBackgroundLocationPermission.locationDenied;
      } else if (location != LocationPermission.always) {
        status =
            PassengerBackgroundLocationPermission.backgroundLocationRequired;
      } else {
        var notification =
            await FlutterForegroundTask.checkNotificationPermission();
        if (request && notification != NotificationPermission.granted) {
          notification =
              await FlutterForegroundTask.requestNotificationPermission();
        }
        status = notification == NotificationPermission.granted
            ? PassengerBackgroundLocationPermission.granted
            : PassengerBackgroundLocationPermission.notificationsDenied;
      }
    }

    if (!mounted) return;
    setState(() {
      _status = status;
      _checking = false;
    });
  }

  Future<void> _openRequiredSetting() async {
    if (_status == PassengerBackgroundLocationPermission.serviceDisabled) {
      await Geolocator.openLocationSettings();
    } else {
      await Geolocator.openAppSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    final blocked =
        (widget.isAndroid ?? Platform.isAndroid) &&
        (_checking || _status != PassengerBackgroundLocationPermission.granted);

    final gpsDisabled =
        _status == PassengerBackgroundLocationPermission.serviceDisabled;
    // O Navigator entregue pelo MaterialApp nunca pode ser removido durante
    // uma checagem de lifecycle. Ao voltar do background, um push pode navegar
    // no mesmo frame; substituir [widget.child] por outra árvore fazia o
    // Flutter desativar e reativar o mesmo Navigator/GlobalKey simultaneamente.
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (blocked)
          Material(
            color: const Color(0xFFF6F8FC),
            child: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: _checking
                        ? const CircularProgressIndicator()
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.location_on_rounded,
                                size: 72,
                                color: Color(0xFF246BFD),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                gpsDisabled
                                    ? 'Ative a localização'
                                    : 'Localização obrigatória',
                                textAlign: TextAlign.center,
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineSmall,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                gpsDisabled
                                    ? 'O GPS precisa permanecer ligado para usar o Motô.'
                                    : 'Para usar o Motô e manter o acompanhamento durante a corrida, permita a localização o tempo todo e as notificações.',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                              const SizedBox(height: 28),
                              FilledButton.icon(
                                onPressed: _openRequiredSetting,
                                icon: const Icon(Icons.settings),
                                label: const Text('Abrir configurações'),
                              ),
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: () => _check(request: true),
                                child: const Text('Verificar novamente'),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
