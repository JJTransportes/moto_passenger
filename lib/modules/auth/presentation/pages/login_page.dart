import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart' hide ReadContext;
import 'package:flutter_modular/flutter_modular.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:moto_passenger/core/utils/validators.dart' as validators;
import 'package:moto_passenger/design_system/design_system.dart';
import 'package:moto_passenger/modules/auth/domain/entities/user_entity.dart';
import 'package:moto_passenger/modules/auth/presentation/blocs/login_bloc.dart';
import 'package:moto_passenger/widgets/app_text_field.dart';

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
  bool _serverErrorBlocked = false;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_onFieldsChanged);
    _passwordController.addListener(_onFieldsChanged);
  }

  void _onFieldsChanged() => setState(() => _serverErrorBlocked = false);

  bool get _isFormFilled =>
      validators.validateEmail(_emailController.text) == null &&
      _passwordController.text.isNotEmpty;

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
    Navigator.of(context).pushReplacementNamed('/usage-terms-guard');
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<LoginBloc, LoginState>(
      listener: (context, state) {
        if (state is LoginSuccess) {
          _onLoginSuccess(context, state.user);
        } else if (state is LoginFailure) {
          setState(() => _serverErrorBlocked = true);
        }
      },
      builder: (context, state) {
        final isLoading = state is LoginLoading;
        final errorMessage = state is LoginFailure ? state.message : null;

        return Scaffold(
          body: MotoCanvas(
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLogo(),
                    const SizedBox(height: 32),
                    Text(
                      'APP PASSAGEIRO',
                      style: TextStyle(
                        fontFamily: MotoFont.ui,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.6,
                        color: context.moto.accent,
                      ),
                    ),
                    const SizedBox(height: MotoSpace.s2),
                    Text('Bom te ver de novo.', style: Theme.of(context).textTheme.displaySmall),
                    const SizedBox(height: MotoSpace.s2),
                    Text(
                      'Entre para chamar seu carro.',
                      style: Theme.of(context).textTheme.bodyLarge!.copyWith(color: context.moto.textSecondary),
                    ),
                    const SizedBox(height: 40),
                    Column(
                      spacing: 16,
                      children: [
                        AppTextField(
                          label: 'E-mail',
                          hint: 'Informe seu e-mail',
                          icon: Icons.mail_outline,
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          errorText: _emailError,
                        ),
                        AppTextField(
                          label: 'Senha',
                          hint: 'Informe sua senha',
                          icon: Icons.lock_outline,
                          controller: _passwordController,
                          obscureText: true,
                          enableVisibilityToggle: true,
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
                                color: context.moto.accent,
                              ),
                            ),
                          ),
                        ),
                        if (errorMessage != null)
                          Text(
                            errorMessage,
                            style: TextStyle(
                              color: context.moto.danger,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        MotoButton(
                          label: 'Entrar',
                          loading: isLoading,
                          onPressed: _isFormFilled && !_serverErrorBlocked ? _submit : null,
                        ),
                        MotoButton(
                          label: 'Criar conta',
                          variant: MotoButtonVariant.glass,
                          onPressed: isLoading ? null : () => Navigator.of(context).pushNamed('/register'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLogo() {
    return ClipRRect(
      borderRadius: MotoRadius.brMd,
      child: Image.asset(
        'assets/images/moto_passenger_logo.png',
        height: 72,
        width: 72,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: 72,
          height: 72,
          color: context.moto.accent,
        ),
      ),
    );
  }
}
