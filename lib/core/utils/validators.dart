import 'masks.dart';

/// Validates a Brazilian CPF using the standard check-digit algorithm.
/// Mirrors the same logic used in the admin web panel and in the backend's
/// PersonValidator, so the three layers agree on what counts as a valid CPF.
String? validateCpf(String cpf) {
  final digits = unmaskDigits(cpf);
  if (digits.length != 11) return 'CPF inválido.';
  if (RegExp(r'^(\d)\1{10}$').hasMatch(digits)) return 'CPF inválido.';

  int calcDigit(String d, int length) {
    var sum = 0;
    for (var i = 0; i < length; i++) {
      sum += int.parse(d[i]) * (length + 1 - i);
    }
    final rem = (sum * 10) % 11;
    return (rem == 10 || rem == 11) ? 0 : rem;
  }

  if (calcDigit(digits, 9) != int.parse(digits[9])) return 'CPF inválido.';
  if (calcDigit(digits, 10) != int.parse(digits[10])) return 'CPF inválido.';
  return null;
}

String? validateRg(String rg) {
  final trimmed = rg.trim();
  if (trimmed.isEmpty) return 'RG obrigatório.';
  final cleaned = trimmed.replaceAll(RegExp(r'[\s.\-/]'), '');
  if (!RegExp(r'^[a-zA-Z0-9]+$').hasMatch(cleaned)) {
    return 'RG deve conter apenas caracteres alfanuméricos.';
  }
  if (trimmed.length > 20) return 'RG deve ter no máximo 20 caracteres.';
  return null;
}

String? validateFullName(String value) {
  if (value.trim().isEmpty) return 'Nome completo é obrigatório.';
  if (value.length > 100) return 'Nome completo deve ter no máximo 100 caracteres.';
  return null;
}

String? validateEmail(String email) {
  if (email.trim().isEmpty) return 'E-mail é obrigatório.';
  if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
    return 'E-mail inválido.';
  }
  if (email.length > 100) return 'E-mail deve ter no máximo 100 caracteres.';
  final safeTextError = validateSafeText(email, 'E-mail');
  if (safeTextError != null) return safeTextError;
  return null;
}

/// Matches the backend's InitialPasswordPolicy (min 8, max 72).
String? validatePassword(String password) {
  if (password.isEmpty) return 'Senha é obrigatória.';
  if (password.length < 8) return 'Senha deve ter no mínimo 8 caracteres.';
  if (password.length > 72) return 'Senha deve ter no máximo 72 caracteres.';
  return null;
}

String? validateRequired(String value, String fieldName) {
  if (value.trim().isEmpty) return '$fieldName é obrigatório.';
  return null;
}

String? validateMaxLength(String value, int max, String fieldName) {
  if (value.length > max) return '$fieldName deve ter no máximo $max caracteres.';
  return null;
}

/// Defense-in-depth for free-text inputs: blocks characters/patterns with no
/// legitimate use in names, addresses, etc. (HTML/script tags, SQL
/// meta-characters, event handler injection). Not the primary defense — the
/// backend must always use parameterized queries — but stops obviously
/// malicious input at the door, mirroring the same check in the web panel.
final RegExp _unsafeTextPattern = RegExp(
  r'<|>|javascript:|on\w+\s*=|--|/\*|\*/|;\s*(drop|delete|insert|update|select|exec)\b|\bunion\s+select\b|\bdrop\s+table\b|\bxp_\w+',
  caseSensitive: false,
);

String? validateSafeText(String value, String fieldName) {
  if (_unsafeTextPattern.hasMatch(value)) {
    return '$fieldName contém caracteres ou padrões não permitidos.';
  }
  return null;
}
