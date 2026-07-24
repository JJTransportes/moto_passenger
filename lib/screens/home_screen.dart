import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:geolocator/geolocator.dart';
import 'package:moto_passenger/core/auth/auth_storage.dart';
import 'package:moto_passenger/core/config/app_config.dart';
import 'package:moto_passenger/core/network/signalr_service.dart';
import 'package:moto_passenger/core/theme/app_theme.dart';
import 'package:moto_passenger/widgets/profile_image_display.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Timer? _locationTimer;
  String? _userName;
  String? _userPhotoUrl;

  @override
  void initState() {
    super.initState();
    _connectAndReport();
    _checkActiveTravel();
    _loadUserProfile();
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

  Future<void> _loadUserProfile() async {
    try {
      final dio = Modular.get<Dio>();
      final response = await dio.get('/api/passengers/me');
      if (!mounted) return;
      if (response.statusCode == 200 && response.data != null) {
        final name = response.data['fullName'] as String?;
        var photoUrl = response.data['photoUrl'] as String?;
        if (photoUrl != null && photoUrl.isNotEmpty &&
            !photoUrl.startsWith('http://') && !photoUrl.startsWith('https://')) {
          photoUrl = '${AppConfig.getBaseUrl()}$photoUrl';
        }
        setState(() {
          if (name != null && name.isNotEmpty) _userName = name;
          _userPhotoUrl = photoUrl;
        });
      }
    } catch (_) {
      // Silently fallback
    }
  }

  Future<void> _checkActiveTravel() async {
    try {
      final dio = Modular.get<Dio>();
      final response = await dio.get('/api/travels/active');
      // 204 No Content = sem viagem ativa
      if (response.statusCode == 204) return;
      final data = response.data;
      if (data != null && data['travelId'] != null && mounted) {
        Modular.to.pushNamed(
          '/new-travel/tracking',
          arguments: {'travelId': data['travelId'] as String},
        );
      }
    } catch (_) {
      // Não crítico — permanece na Home
    }
  }

  void _startLocationReporting(SignalRService signalR) {
    _locationTimer?.cancel();
    _locationTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) async {
        try {
          final hasPermission = await Geolocator.checkPermission();
          if (hasPermission == LocationPermission.denied || hasPermission == LocationPermission.deniedForever) {
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
    final firstName = _userName != null && _userName!.isNotEmpty
        ? _userName!.split(' ').first
        : 'Passageiro';

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
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ProfileImageDisplay(
              photoUrl: _userPhotoUrl,
              name: _userName ?? '',
              radius: 32,
            ),
            const SizedBox(height: 12),
            Text(
              'Olá, $firstName!',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Color(0xFF4E4E4E),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Bem-vindo ao Moto Passageiro',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
