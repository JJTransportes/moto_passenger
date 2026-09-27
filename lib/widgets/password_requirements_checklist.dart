import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:moto_passenger/core/utils/password_policy_validator.dart';
import 'package:moto_passenger/design_system/design_system.dart';
import 'package:moto_passenger/modules/auth/domain/entities/password_policy_entity.dart';

/// Checklist de requisitos de senha estilo gov.br: nenhum item nasce em
/// vermelho — fica neutro até ser cumprido, e vira verde com ✓ quando a
/// condição bate. Sempre mostra a lista completa (não só o que falta), para
/// dar feedback positivo progressivo em vez de uma lista de erros.
class PasswordRequirementsChecklist extends StatelessWidget {
  final String password;
  final PasswordPolicy policy;

  const PasswordRequirementsChecklist({
    super.key,
    required this.password,
    required this.policy,
  });

  @override
  Widget build(BuildContext context) {
    final requirements = passwordRequirementsStatus(password, policy);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'A senha deve conter:',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: context.moto.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        ...requirements.map(
          (requirement) => Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  requirement.met ? Icons.check_circle : Icons.circle_outlined,
                  size: 14,
                  color: requirement.met ? context.moto.success : context.moto.textTertiary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    requirement.label,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: requirement.met
                          ? context.moto.success
                          : context.moto.textSecondary,
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
