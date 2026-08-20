import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart' hide ModularWatchExtension;
import 'package:google_fonts/google_fonts.dart';
import 'package:moto_passenger/core/theme/app_theme.dart';
import 'package:moto_passenger/modules/auth/presentation/blocs/password_reset_bloc.dart';
import 'package:moto_passenger/widgets/app_button.dart';
import 'package:moto_passenger/widgets/app_text_field.dart';
import 'package:moto_passenger/widgets/gradient_text.dart';

class PasswordResetPage extends StatefulWidget {
  const PasswordResetPage({super.key});

  @override
  State<PasswordResetPage> createState() => _PasswordResetPageState();
}

class _PasswordResetPageState extends State<PasswordResetPage> {
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  String? _localError;

  @override
  void dispose() {
    _codeController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _submit() {
    final code = _codeController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    // Validação client-side: apenas campos não vazios e senha == confirmação.
    // Nenhuma regra de política de senha aqui — validada só no backend.
    if (code.isEmpty || password.isEmpty || confirm.isEmpty) {
      setState(() => _localError = 'Preencha todos os campos.');
      return;
    }
    if (password != confirm) {
      setState(() => _localError = 'As senhas não coincidem.');
      return;
    }

    setState(() => _localError = null);
    context.read<PasswordResetBloc>().add(
          ResetConfirmSubmitted(code: code, newPassword: password),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: BlocBuilder<PasswordResetBloc, PasswordResetState>(
          builder: (context, state) {
            if (state is PasswordResetSuccess) {
              return const _SuccessView();
            }

            final isLoading = state is PasswordResetSubmitting;
            final serverError =
                state is PasswordResetError ? state.message : null;
            final codeConsumed =
                state is PasswordResetError && state.codeConsumed;

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GradientText(
                    'Recupere sua senha',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 72),
                  Text(
                    'Informe o código de verificação abaixo e redefina sua senha',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Colors.black,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  AppTextField(
                    label: 'Código de verificação',
                    hint: 'Informe o código de verificação',
                    controller: _codeController,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    label: 'Senha',
                    hint: 'Defina sua senha',
                    controller: _passwordController,
                    obscureText: true,
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    label: 'Confirmar Senha',
                    hint: 'Digite novamente a senha',
                    controller: _confirmController,
                    obscureText: true,
                  ),
                  if (_localError != null || serverError != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _localError ?? serverError!,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: Colors.red,
                      ),
                    ),
                  ],
                  if (codeConsumed) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => Modular.to.navigate('/recovery'),
                      child: Text(
                        'Solicitar novo código',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                  AppButton(
                    label: 'Confirmar',
                    loading: isLoading,
                    onPressed: _submit,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SuccessView extends StatelessWidget {
  const _SuccessView();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 36),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, color: AppColors.primary, size: 64),
          const SizedBox(height: 24),
          Text(
            'Senha redefinida com sucesso!',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          AppButton(
            label: 'Fazer login',
            onPressed: () => Modular.to.navigate('/login'),
          ),
        ],
      ),
    );
  }
}
