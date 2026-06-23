import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:geolocator/geolocator.dart';
import 'package:moto_passenger/core/auth/auth_storage.dart';
import 'package:moto_passenger/core/config/app_config.dart';
import 'package:moto_passenger/core/network/signalr_service.dart';
import 'package:moto_passenger/core/theme/app_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Timer? _locationTimer;

  @override
  void initState() {
    super.initState();
    _connectAndReport();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    super.dispose();
  }

  Future<void> _connectAndReport() async {
    final signalR = Modular.get<SignalRService>();
    final authStorage = Modular.get<AuthStorage>();
    final token = await authStorage.getToken();
    if (token == null) return;

    try {
      await signalR.connect(
        'travel-management',
        '${AppConfig.getBaseUrl()}/hubs/travel-management',
        token,
      );
    } catch (_) {
      // Non-critical
    }

    _startLocationReporting(signalR);
  }

  void _startLocationReporting(SignalRService signalR) {
    _locationTimer?.cancel();
    _locationTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) async {
        try {
          final hasPermission = await Geolocator.checkPermission();
          if (hasPermission == LocationPermission.denied ||
              hasPermission == LocationPermission.deniedForever) {
            return;
          }
          final position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
            ),
          );
          await signalR.reportLocation(position.latitude, position.longitude);
        } catch (_) {
          // Silently skip on error
        }
      },
    );
  }

  Future<void> _logout(BuildContext context) async {
    _locationTimer?.cancel();
    await Modular.get<SignalRService>().disconnectAll();
    final storage = AuthStorage();
    await storage.clear();
    if (context.mounted) {
      Modular.to.navigate('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: const Text('Moto Passageiro'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sair',
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: const Center(
        child: Text('Bem-vindo ao Moto Passageiro!'),
      ),
    );
  }
}
