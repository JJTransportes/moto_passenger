import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart' hide ReadContext;
import 'package:flutter_modular/flutter_modular.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:moto_passenger/core/notifications/deep_link_holder.dart';
import 'package:moto_passenger/core/notifications/notification_handler.dart';
import 'package:moto_passenger/core/notifications/push_notification_service.dart';
import 'package:moto_passenger/core/theme/app_theme.dart';
import 'package:moto_passenger/modules/auth/data/datasources/i_auth_datasource.dart';
import 'package:moto_passenger/modules/auth/domain/entities/user_entity.dart';
import 'package:moto_passenger/modules/auth/presentation/blocs/login_bloc.dart';
import 'package:moto_passenger/widgets/app_button.dart';
import 'package:moto_passenger/widgets/app_text_field.dart';
import 'package:moto_passenger/widgets/gradient_text.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  String? _emailError;
  String? _passwordError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool _validate() {
    bool valid = true;
    setState(() {
      _emailError = null;
      _passwordError = null;

      if (_emailController.text.trim().isEmpty) {
        _emailError = 'E-mail obrigatório';
        valid = false;
      }
      if (_passwordController.text.isEmpty) {
        _passwordError = 'Senha obrigatória';
        valid = false;
      }
    });
    return valid;
  }

  void _submit() {
    if (!_validate()) return;
    context.read<LoginBloc>().add(
      LoginSubmitted(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      ),
    );
  }

  Future<void> _onLoginSuccess(BuildContext context, UserEntity user) async {
    // Navegar imediatamente — push registration é fire-and-forget
    Navigator.of(context).pushReplacementNamed('/usage-terms-guard');

    // Registrar push notifications em background
    unawaited(_registerPushNotifications(user.id));
  }

  Future<void> _registerPushNotifications(String userId) async {
    try {
      final pushService = Modular.get<PushNotificationService>();

      // 1. Solicitar permissão
      final granted = await pushService.requestPermission();
      if (!granted) {
        log('[PUSH] Permission denied — skipping push registration');
        return;
      }

      // 2. OneSignal.login (obrigatório, com retry interno)
      await pushService.login(userId);

      // 3. Aguardar playerId
      String playerId;
      try {
        playerId = await pushService.onPlayerIdChanged.first
            .timeout(const Duration(seconds: 10));
      } on TimeoutException {
        log('[PUSH] PlayerId timeout — skipping register-device');
        return;
      }

      // 4. register-device (auditoria, retry 3x)
      final platform = Platform.isAndroid ? 'android' : 'ios';
      final authDatasource = Modular.get<IAuthDatasource>();
      for (var i = 0; i < 3; i++) {
        try {
          await authDatasource.registerDeviceToken(playerId, platform);
          log('[PUSH] register-device OK. playerId=$playerId');
          break;
        } catch (e) {
          log('[PUSH] register-device attempt ${i + 1}/3 failed: $e');
          if (i < 2) await Future.delayed(Duration(seconds: 1 << i));
        }
      }

      // 5. Processar deep link pendente (cold start com JWT expirado)
      final pending = DeepLinkHolder.consume();
      if (pending != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          NotificationHandler.handleNotificationTap(pending);
        });
      }
    } catch (e) {
      log('[PUSH] _registerPushNotifications error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return BlocConsumer<LoginBloc, LoginState>(
      listener: (context, state) {
        if (state is LoginSuccess) {
          _onLoginSuccess(context, state.user);
        }
      },
      builder: (context, state) {
        final isLoading = state is LoginLoading;
        final errorMessage = state is LoginFailure ? state.message : null;

        return Scaffold(
          backgroundColor: AppColors.white,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 36),
              child: Column(
                spacing: size.height * 0.1,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GradientText(
                    'App Passageiro',
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildLogo(),
                  Column(
                    spacing: 16,
                    children: [
                      AppTextField(
                    label: 'E-mail',
                    hint: 'Informe seu e-mail',
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    errorText: _emailError,
                      ),
                  AppTextField(
                    label: 'Senha',
                    hint: 'Informe sua senha',
                    controller: _passwordController,
                    obscureText: true,
                    errorText: _passwordError,
                      ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pushNamed('/recovery'),
                      child: Text(
                        'Esqueci minha senha',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      errorMessage,
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 24),
                      AppButton(label: 'Entrar', loading: isLoading, onPressed: _submit,),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.center,
                    child: TextButton(
                      onPressed: isLoading
                          ? null
                          : () => Navigator.of(context).pushNamed('/register'),
                      child: Text(
                        'Criar conta',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLogo() {
    return Image.asset(
      'assets/images/moto_passenger_logo.png',
      width: 224,
      height: 90,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => const SizedBox(width: 224, height: 90, child: Placeholder()),
    );
  }
}
