import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart' hide ModularWatchExtension;
import 'package:google_fonts/google_fonts.dart';
import 'package:moto_passenger/core/utils/validators.dart' as validators;
import 'package:moto_passenger/design_system/design_system.dart';
import 'package:moto_passenger/modules/auth/presentation/blocs/password_recovery_bloc.dart';
import 'package:moto_passenger/widgets/app_button.dart';
import 'package:moto_passenger/widgets/app_text_field.dart';
import 'package:moto_passenger/widgets/gradient_text.dart';

class PasswordRecoveryPage extends StatefulWidget {
  const PasswordRecoveryPage({super.key});

  @override
  State<PasswordRecoveryPage> createState() => _PasswordRecoveryPageState();
}

class _PasswordRecoveryPageState extends State<PasswordRecoveryPage> {
  final _emailController = TextEditingController();
  final _confirmEmailController = TextEditingController();

  String? _localError;
  String? _emailServerError;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_onEmailChanged);
    _confirmEmailController.addListener(_onFieldsChanged);
  }

  void _onFieldsChanged() => setState(() {});

  void _onEmailChanged() {
    _emailServerError = null;
    setState(() {});
  }

  bool get _isFormFilled =>
      validators.validateEmail(_emailController.text) == null &&
      _confirmEmailController.text.trim() == _emailController.text.trim();

  String? get _confirmEmailMismatch {
    final email = _emailController.text.trim();
    final confirmEmail = _confirmEmailController.text.trim();
    if (email.isEmpty || confirmEmail.isEmpty) return null;
    if (email == confirmEmail) return null;
    return 'Os e-mails não coincidem';
  }

  @override
  void dispose() {
    _emailController.dispose();
    _confirmEmailController.dispose();
    super.dispose();
  }

  void _submit() {
    final email = _emailController.text.trim();
    final confirmEmail = _confirmEmailController.text.trim();

    if (email.isEmpty || confirmEmail.isEmpty) {
      setState(() => _localError = 'Confirme seu e-mail');
      return;
    }
    if (email != confirmEmail) {
      setState(() => _localError = 'Os e-mails não coincidem');
      return;
    }

    setState(() => _localError = null);
    context.read<PasswordRecoveryBloc>().add(RequestCodeSubmitted(email));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: BlocConsumer<PasswordRecoveryBloc, PasswordRecoveryState>(
          listener: (context, state) {
            if (state is PasswordRecoverySent) {
              Modular.to.pushNamed(
                '/verify-code',
                arguments: {'email': state.email},
              );
            } else if (state is PasswordRecoveryError) {
              setState(() => _emailServerError = state.message);
            }
          },
          builder: (context, state) {
            final isLoading = state is PasswordRecoveryLoading;
            final errorMessage = _localError;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
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
                        'Informe o e-mail da sua conta. Enviaremos um código de verificação para que você redefina sua senha.',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: context.moto.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppTextField(
                        label: 'E-mail',
                        hint: 'Informe seu e-mail',
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        errorText: _emailServerError,
                      ),
                      const SizedBox(height: 12),
                      AppTextField(
                        label: 'Confirmar e-mail',
                        hint: 'Repita seu e-mail',
                        controller: _confirmEmailController,
                        keyboardType: TextInputType.emailAddress,
                        errorText: _confirmEmailMismatch,
                      ),
                      if (errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          errorMessage,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: context.moto.danger,
                          ),
                        ),
                      ],
                    ],
                  ),
                  AppButton(
                    label: 'Enviar',
                    loading: isLoading,
                    onPressed: _isFormFilled && _emailServerError == null ? _submit : null,
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
