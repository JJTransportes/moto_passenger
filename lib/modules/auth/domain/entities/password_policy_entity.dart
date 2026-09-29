class PasswordPolicy {
  final int minLength;
  final int maxLength;
  final bool requireUppercase;
  final bool requireLowercase;
  final bool requireDigit;
  final bool requireSpecialChar;

  const PasswordPolicy({
    required this.minLength,
    required this.maxLength,
    required this.requireUppercase,
    required this.requireLowercase,
    required this.requireDigit,
    required this.requireSpecialChar,
  });

  /// Usada quando `GET /api/auth/password-policy` falha — mantém o app utilizável
  /// sem duplicar a regra do servidor em texto hardcoded como fonte única.
  static const fallback = PasswordPolicy(
    minLength: 8,
    maxLength: 72,
    requireUppercase: true,
    requireLowercase: true,
    requireDigit: true,
    requireSpecialChar: true,
  );
}
