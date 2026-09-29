import 'package:moto_passenger/modules/auth/domain/entities/password_policy_entity.dart';

/// Um requisito de senha com seu rótulo legível e se [password] o cumpre —
/// fonte única de verdade usada tanto pelo checklist visual (estilo gov.br,
/// ✓/✗ por item) quanto pela validação que habilita/desabilita o submit.
class PasswordRequirementStatus {
  final String label;
  final bool met;

  const PasswordRequirementStatus({required this.label, required this.met});
}

/// Lista todos os requisitos de [policy] com o status de cada um para
/// [password]. Sempre retorna os mesmos itens (na mesma ordem), variando só
/// `met` — usado para renderizar o checklist completo, não só o que falta.
List<PasswordRequirementStatus> passwordRequirementsStatus(
  String password,
  PasswordPolicy policy,
) {
  final items = <PasswordRequirementStatus>[
    PasswordRequirementStatus(
      label: 'Entre ${policy.minLength} e ${policy.maxLength} caracteres',
      met: password.length >= policy.minLength &&
          password.length <= policy.maxLength,
    ),
  ];

  if (policy.requireUppercase) {
    items.add(PasswordRequirementStatus(
      label: 'Pelo menos 1 letra maiúscula',
      met: password.contains(RegExp(r'[A-Z]')),
    ));
  }
  if (policy.requireLowercase) {
    items.add(PasswordRequirementStatus(
      label: 'Pelo menos 1 letra minúscula',
      met: password.contains(RegExp(r'[a-z]')),
    ));
  }
  if (policy.requireDigit) {
    items.add(PasswordRequirementStatus(
      label: 'Pelo menos 1 número',
      met: password.contains(RegExp(r'[0-9]')),
    ));
  }
  if (policy.requireSpecialChar) {
    items.add(PasswordRequirementStatus(
      label: 'Pelo menos 1 caractere especial (ex: ! @ # \$ % &)',
      met: password.contains(RegExp(r'[^A-Za-z0-9\s]')),
    ));
  }

  return items;
}

/// Retorna os rótulos dos requisitos de [policy] ainda não cumpridos por
/// [password]. Lista vazia = senha válida — usado para habilitar/desabilitar
/// o botão de submit.
List<String> unmetPasswordRequirements(String password, PasswordPolicy policy) {
  return passwordRequirementsStatus(password, policy)
      .where((r) => !r.met)
      .map((r) => r.label)
      .toList();
}
