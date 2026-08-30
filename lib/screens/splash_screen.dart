import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:moto_passenger/core/auth/auth_storage.dart';
import 'package:moto_passenger/core/auth/sign_out_service.dart';
import 'package:moto_passenger/core/config/app_config.dart';
import 'package:moto_passenger/core/errors/exceptions.dart';
import 'package:moto_passenger/core/local_db/repositories/auth_local_repository.dart';
import 'package:moto_passenger/core/local_db/repositories/travel_local_repository.dart';
import 'package:moto_passenger/core/theme/app_theme.dart';
import 'package:moto_passenger/modules/auth/data/datasources/i_auth_datasource.dart';

class SplashScreen extends StatefulWidget {
  final Duration delay;

  const SplashScreen({
    super.key,
    this.delay = const Duration(seconds: 2),
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    await Future.delayed(widget.delay);
    if (!mounted) return;

    // Try local DB cache first
    final authLocal = Modular.get<AuthLocalRepository>();
    final localAuth = await authLocal.getAuth();

    // If we have a refresh token, try to renew the session
    if (localAuth != null && localAuth.refreshToken.isNotEmpty) {
      final refreshed = await _tryRefreshToken(localAuth.refreshToken);
      if (!mounted) return;
      if (refreshed) {
        await _afterAuthSuccess();
        return;
      }
      // Refresh failed (token expired) — sign out and go to login
      await Modular.get<SignOutService>().signOut();
      return;
    }

    // Fallback: access token from local cache (no refresh token available)
    if (localAuth != null && localAuth.accessToken.isNotEmpty) {
      if (!mounted) return;
      await _afterAuthSuccess();
      return;
    }

    // Fallback to secure storage
    final storage = Modular.get<AuthStorage>();
    final token = await storage.getToken();

    if (!mounted) return;
    if (token != null) {
      await _afterAuthSuccess();
    } else {
      Modular.to.navigate('/login');
    }
  }

  Future<void> _afterAuthSuccess() async {
    final restored = await _checkActiveTravel();
    if (!mounted) return;
    if (!restored) Modular.to.navigate('/usage-terms-guard');
  }

  /// Tries to refresh the access token using the [refreshToken].
  /// Returns true on success, false on failure.
  Future<bool> _tryRefreshToken(String refreshToken) async {
    try {
      final authDatasource = Modular.get<IAuthDatasource>();
      final result = await authDatasource.refreshToken(refreshToken);

      final storage = Modular.get<AuthStorage>();
      final authLocal = Modular.get<AuthLocalRepository>();

      await storage.saveTokens(
        result.accessToken,
        result.refreshToken!,
        result.userId,
      );
      await authLocal.updateTokens(
        result.accessToken,
        result.refreshToken!,
      );
      return true;
    } on UnauthorizedException {
      // Refresh token expirado ou revogado — não recuperável
      return false;
    } on DeviceMismatchException {
      // Token vinculado a outro tipo de dispositivo — não recuperável neste aparelho
      return false;
    } catch (_) {
      // Network or other error — fall through to access token fallback
      return false;
    }
  }

  /// Checks if there's an active travel in local storage and navigates to it.
  /// Returns true if restored, false if no active travel found.
  Future<bool> _checkActiveTravel() async {
    final travelRepo = Modular.get<TravelLocalRepository>();
    final active = await travelRepo.getActiveTravel();

    if (active == null || active.status == 'Completed' || active.status == 'Cancelled') {
      return false;
    }

    // Verify travel still exists on backend
    try {
      final dio = Modular.get<Dio>();
      await dio.get('${AppConfig.getBaseUrl()}/api/travels/${active.travelId}');
      if (active.status == 'Accepted' || active.status == 'InProgress') {
        Modular.to.pushNamed('/new-travel/tracking', arguments: {'travelId': active.travelId});
        return true;
      }
    } catch (_) {
      // Travel no longer exists
      await travelRepo.clearTravels();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: Center(
        child: Image.asset(
          'assets/images/moto_passenger_logo.png',
          width: 257,
          height: 103,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const SizedBox(
            width: 257,
            height: 103,
            child: Placeholder(),
          ),
        ),
      ),
    );
  }
}
