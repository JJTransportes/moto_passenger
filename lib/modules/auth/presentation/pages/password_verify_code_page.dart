import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart' hide ModularWatchExtension;
import 'package:google_fonts/google_fonts.dart';
import 'package:moto_passenger/core/theme/app_theme.dart';
import 'package:moto_passenger/modules/auth/presentation/blocs/password_verify_code_bloc.dart';
import 'package:moto_passenger/widgets/app_button.dart';
import 'package:moto_passenger/widgets/app_text_field.dart';
import 'package:moto_passenger/widgets/gradient_text.dart';

class PasswordVerifyCodePage extends StatefulWidget {
  const PasswordVerifyCodePage({super.key});

  @override
  State<PasswordVerifyCodePage> createState() => _PasswordVerifyCodePageState();
}

class _PasswordVerifyCodePageState extends State<PasswordVerifyCodePage> {
  final _codeController = TextEditingController();

  int _wrongAttempts = 0;
  String? _codeServerError;

  @override
  void initState() {
    super.initState();
    _codeController.addListener(_onFieldsChanged);
  }

  void _onFieldsChanged() {
    _codeServerError = null;
    setState(() {});
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _submit() {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;
    context.read<PasswordVerifyCodeBloc>().add(CodeSubmitted(code));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: BlocConsumer<PasswordVerifyCodeBloc, PasswordVerifyCodeState>(
          listener: (context, state) {
            if (state is PasswordVerifyCodeSuccess) {
              Modular.to.pushNamed(
                '/reset-password',
                arguments: {'resetToken': state.resetToken},
              );
            } else if (state is PasswordVerifyCodeError) {
              _codeServerError = state.message;
              if (!state.requestNewCode) _wrongAttempts++;
              setState(() {});
            }
          },
          builder: (context, state) {
            final isLoading = state is PasswordVerifyCodeSubmitting;
            final requestNewCode =
                state is PasswordVerifyCodeError && state.requestNewCode;
            final remainingAttemptsHint =
                _wrongAttempts >= 2 ? 5 - _wrongAttempts : null;

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GradientText(
                    'Verifique seu e-mail',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 72),
                  Text(
                    'Informe o código de verificação enviado para o seu e-mail.',
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
                    errorText: _codeServerError,
                  ),
                  if (remainingAttemptsHint != null && remainingAttemptsHint > 0) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Restam $remainingAttemptsHint tentativas antes de precisar pedir um novo código.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                  if (requestNewCode) ...[
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
                    onPressed: _codeController.text.trim().isEmpty || _codeServerError != null
                        ? null
                        : _submit,
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
