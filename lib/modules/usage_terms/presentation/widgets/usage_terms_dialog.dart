import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:moto_passenger/core/theme/app_theme.dart';
import 'package:moto_passenger/modules/usage_terms/domain/entities/usage_term_entity.dart';
import 'package:moto_passenger/widgets/app_button.dart';

class UsageTermsDialog extends StatelessWidget {
  final UsageTermEntity terms;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final bool isSubmitting;

  const UsageTermsDialog({
    super.key,
    required this.terms,
    required this.onAccept,
    required this.onDecline,
    this.isSubmitting = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // AppBar area
        Container(
          width: double.infinity,
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 16,
            bottom: 16,
            left: 24,
            right: 24,
          ),
          decoration: const BoxDecoration(
            gradient: AppGradients.primary,
          ),
          child: Text(
            'Termos de Uso',
            style: GoogleFonts.robotoFlex(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.white,
            ),
          ),
        ),
        // Scrollable content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  terms.title,
                  style: GoogleFonts.robotoFlex(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 24),
                ...terms.subTerms.map(
                  (subTerm) => Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          subTerm.title,
                          style: GoogleFonts.robotoFlex(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          subTerm.content,
                          style: GoogleFonts.robotoFlex(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: Colors.black87,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Bottom buttons
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
            child: Column(
              children: [
                AppButton(
                  label: 'Aceitar',
                  loading: isSubmitting,
                  onPressed: isSubmitting ? null : onAccept,
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: isSubmitting ? null : onDecline,
                  child: Text(
                    'Recusar',
                    style: GoogleFonts.robotoFlex(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.secondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
