import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationResult {
  final Position? position;
  final LocationStatus status;

  const LocationResult({this.position, required this.status});

  bool get isGranted => status == LocationStatus.granted && position != null;
}

class LocationService {
  Future<LocationResult> getCurrentPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return const LocationResult(status: LocationStatus.serviceDisabled);
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return const LocationResult(status: LocationStatus.denied);
      }
    }
    if (permission == LocationPermission.deniedForever) {
      return const LocationResult(status: LocationStatus.deniedForever);
    }

    final position = await Geolocator.getCurrentPosition();
    return LocationResult(position: position, status: LocationStatus.granted);
  }

  Future<void> openAppSettings() async {
    await Geolocator.openAppSettings();
  }

  Future<void> openLocationSettings() async {
    await Geolocator.openLocationSettings();
  }

  static Future<void> requestPermissionIfNeeded() async {
    // Na web não pré-solicitamos permissão no start: a Permissions API do
    // navegador pode lançar (ex.: OperationError) e derrubaria o main() antes
    // do runApp. O navegador pede a permissão quando a geolocalização é de fato
    // usada (mapa/corrida).
    if (kIsWeb) return;

    try {
      if (Platform.isIOS) {
        await Permission.location.request();
        return;
      }

      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
    } catch (_) {
      // Nunca deixar a checagem de permissão bloquear a inicialização do app.
    }
  }
}

enum LocationStatus {
  granted,
  denied,
  deniedForever,
  serviceDisabled,
}
