import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:moto_passenger/core/theme/app_theme.dart';
import 'package:moto_passenger/widgets/app_button.dart';
import 'package:moto_passenger/widgets/gradient_text.dart';

class PendingApprovalPage extends StatelessWidget {
  const PendingApprovalPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 36),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.check_circle_outline,
                size: 80,
                color: Colors.green,
              ),
              const SizedBox(height: 24),
              GradientText(
                'Conta criada!',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Sua conta foi criada e está pendente de aprovação por um Administrador Global.',
                textAlign: TextAlign.center,
                style: GoogleFonts.robotoFlex(
                  fontSize: 14,
                  fontWeight: FontWeight.w300,
                  color: AppColors.primary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Você não receberá um e-mail de notificação. '
                'A aprovação é manual. Tente fazer login mais tarde.',
                textAlign: TextAlign.center,
                style: GoogleFonts.robotoFlex(
                  fontSize: 12,
                  fontWeight: FontWeight.w300,
                  color: AppColors.secondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 48),
              AppButton(
                label: 'Ir para o login',
                onPressed: () {
                  Modular.to.navigate('/login');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
