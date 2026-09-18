# Handoff — Validadores e Máscaras de Formulário (padronizar com o app do Passageiro)

**Para:** agente de código trabalhando no repositório do app **Passageiro**.
**Origem:** estas regras já foram implementadas, corrigidas (um bug real foi achado e
resolvido no caminho) e testadas no app **Moto Driver**, que envia para o **mesmo endpoint**
de cadastro (`POST /api/registrations`, mesmo backend). O objetivo aqui é levar exatamente
o mesmo comportamento de validação/máscara para o formulário de cadastro do passageiro, para
os dois apps ficarem consistentes.

> Mesma premissa do handoff de reset de senha: assumo Flutter + mesma Clean Architecture.
> Adapte nomes de arquivo à estrutura já existente no app Passageiro, mas **não** altere as
> regras de validação em si — foram alinhadas (e uma delas corrigida) com o backend.

---

## 1. Contexto — por que isso importa

O formulário de cadastro tem dois tipos de validação, e é importante não confundir:

1. **Formato/máscara** (client-side, cosmético + prevenção de erro óbvio) — o que este
   documento cobre.
2. **Regra de negócio do backend** (checksum de CPF, unicidade de e-mail/CPF/CNH, política
   de senha) — o cliente replica o que dá pra replicar (para dar feedback rápido), mas o
   backend é sempre a fonte de verdade e pode rejeitar mesmo com o cliente validando OK
   (ex.: e-mail duplicado só o backend sabe).

**Já aconteceu de o formato do cliente e o do backend divergirem e quebrar 100% dos
cadastros** — ver seção 5. Não implemente "no olho"; siga as regras exatas abaixo.

---

## 2. Tabela de campos — validação, máscara, teclado

Campos compartilhados entre os dois cadastros (motorista e passageiro usam o mesmo
`POST /api/registrations`, só o `role` muda):

| Campo | Placeholder (hint) | Teclado | Formatter de entrada | Validação client-side | Regra do backend |
|---|---|---|---|---|---|
| Nome completo | "Informe seu nome completo" | texto | — | não-vazio, máx. 100, `validateSafeText` | obrigatório, máx. 100 |
| CPF | `000.000.000-00` | número | `CpfInputFormatter` (mascara ao digitar) | não-vazio, checksum (`validateCpf`) | obrigatório, checksum |
| RG | "Somente letras e números (7 a 12 caracteres)" | **texto** | `AlphanumericInputFormatter(maxLength: 12)` | não-vazio, `validateRg` (alfanumérico, 7–12) | obrigatório, alfanumérico, **7 a 12 caracteres** (ver seção 5) |
| Matrícula | "N° de matrícula (letras e números)" | **texto** | `AlphanumericInputFormatter(maxLength: 30)` | não-vazio, `validateAlphanumericFormat(..., 30)` | obrigatório, alfanumérico, máx. 30 |
| Telefone | `(12) 91234-5678` | telefone | — | opcional; **se preenchido**, ≥10 dígitos (checagem só do cliente, ver nota) | opcional, sem validação de formato |
| Data de nascimento | "Selecione a data" (date picker) | — | `lastDate: DateTime.now()` no picker | não-vazio, implicitamente no passado | obrigatório, deve ser passado |
| E-mail | "Informe seu e-mail" | e-mail | — | não-vazio, formato + `validateSafeText`, máx. 100 | obrigatório (no cadastro do motorista o backend só checa não-vazio — **confirme se é igual no endpoint do passageiro**) |
| Senha (`initialPassword`) | "Informe sua senha" | — (obscure) | — | não-vazio, 8–72 caracteres | obrigatório, 8–72 |

Campos **específicos de cada app** (não confundir com os de cima):

| App | Campo extra | Observação |
|---|---|---|
| Motorista | `cnh` | 11 dígitos, `FilteringTextInputFormatter.digitsOnly`, obrigatório só para `role: "Driver"` |
| Passageiro | `publicPartitionId` | não é validação de texto — é um seletor (dropdown) preenchido a partir de `GET /public-partitions/list`. Fora do escopo deste documento; garanta só que o campo é obrigatório se o backend exigir. |

> ⚠️ **Nota sobre o telefone:** a checagem "≥10 dígitos" que o app Motorista faz **não vem do
> backend** — é uma conveniência do cliente pra pegar número obviamente incompleto antes de
> gastar uma requisição. Adote se fizer sentido pro UX do passageiro, mas saiba que não é
> contrato — o backend aceita qualquer coisa nesse campo hoje.

---

## 3. Código-fonte para copiar (reaproveitável quase 100%, é lógica pura sem nada de UI)

### 3.1 — `core/utils/masks.dart`

```dart
import 'package:flutter/services.dart';

/// Strips everything but digits.
String unmaskDigits(String value) => value.replaceAll(RegExp(r'\D'), '');

/// Strips everything but digits and the letter X (used in some RG check digits).
String unmaskRg(String value) =>
    value.toUpperCase().replaceAll(RegExp(r'[^0-9X]'), '');

/// Formats as the user types: 000.000.000-00
class CpfInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = unmaskDigits(newValue.text).substring(
      0,
      unmaskDigits(newValue.text).length > 11
          ? 11
          : unmaskDigits(newValue.text).length,
    );

    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      buffer.write(digits[i]);
      if (i == 2 || i == 5) {
        if (i != digits.length - 1) buffer.write('.');
      } else if (i == 8) {
        if (i != digits.length - 1) buffer.write('-');
      }
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Restricts input to letters and digits (optionally capped at
/// [maxLength]) — no dots, dashes, slashes or spaces. Used for RG e
/// Matrícula: o backend rejeita qualquer pontuação nesses dois campos
/// (regex alfanumérico puro), e o RG varia de formato por estado (letras
/// misturadas, tamanhos diferentes), então uma máscara fixa não serve
/// para nenhum dos dois.
class AlphanumericInputFormatter extends TextInputFormatter {
  AlphanumericInputFormatter({this.maxLength});

  final int? maxLength;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = newValue.text.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    final cap = maxLength;
    if (cap != null && text.length > cap) {
      text = text.substring(0, cap);
    }
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
```

### 3.2 — `core/utils/validators.dart`

```dart
import 'masks.dart';

/// Validates a Brazilian CPF using the standard check-digit algorithm.
/// Mirrors the same logic used no painel web e no backend, para as duas
/// camadas concordarem sobre o que é um CPF válido. Retorna null se válido
/// (NÃO checa vazio — quem chama trata "campo obrigatório" separadamente).
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

/// Enforces alphanumeric-only content (no punctuation/spaces) within
/// [minLength]..[maxLength] — o formato que o backend exige. Não checa
/// vazio (minLength só reprova se maior que zero; "campo obrigatório" é
/// tratado à parte por quem chama).
String? validateAlphanumericFormat(
  String value,
  String fieldName,
  int maxLength, {
  int minLength = 1,
}) {
  final trimmed = value.trim();
  if (!RegExp(r'^[a-zA-Z0-9]+$').hasMatch(trimmed)) {
    return '$fieldName deve conter apenas letras e números, sem pontuação.';
  }
  if (trimmed.length < minLength) {
    return '$fieldName deve ter no mínimo $minLength caracteres.';
  }
  if (trimmed.length > maxLength) {
    return '$fieldName deve ter no máximo $maxLength caracteres.';
  }
  return null;
}

/// RGs brasileiros válidos variam de 7 (estados/DF com numeração antiga e
/// curta) a 12 caracteres (casos raros com 11 dígitos + verificador, ou
/// legados com dígito verificador alfanumérico). Mesma faixa usada no
/// backend, já limpo de pontuação: ^[0-9A-Za-z]{7,12}$
String? validateRg(String rg) => validateAlphanumericFormat(rg, 'RG', 12, minLength: 7);

/// CNH must be exactly 11 digits, matching the backend's CnhRegex.
/// (Só se aplica ao cadastro de motorista — não existe no de passageiro.)
String? validateCnh(String cnh) {
  final digits = unmaskDigits(cnh);
  if (digits.length != 11) return 'CNH deve conter exatamente 11 dígitos.';
  return null;
}

String? validateEmailFormat(String email) {
  if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
    return 'E-mail inválido.';
  }
  final safeTextError = validateSafeText(email, 'E-mail');
  if (safeTextError != null) return safeTextError;
  return null;
}

/// Matches the backend's InitialPasswordPolicy (min 8, max 72).
String? validatePasswordLength(String password) {
  if (password.length < 8) return 'Senha deve ter no mínimo 8 caracteres.';
  if (password.length > 72) return 'Senha deve ter no máximo 72 caracteres.';
  return null;
}

String? validateMaxLength(String value, int max, String fieldName) {
  if (value.trim().length > max) {
    return '$fieldName deve ter no máximo $max caracteres.';
  }
  return null;
}

/// Defense-in-depth para campos de texto livre: bloqueia caracteres/padrões
/// sem uso legítimo em nomes, endereços etc. (tags HTML/script,
/// meta-caracteres de SQL, injeção de event handler). Não é a defesa
/// principal — o backend sempre deve usar queries parametrizadas — mas
/// barra entrada obviamente maliciosa na porta, espelhando o mesmo check
/// do painel web.
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
```

### 3.3 — Como ligar nos campos do formulário (`AppTextField`)

```dart
// Nome completo
AppTextField(
  label: 'Nome completo *',
  hint: 'Informe seu nome completo',
  controller: _fullNameController,
  errorText: _fullNameError,
  maxLength: 100,
),

// CPF — com máscara visual (é a única com pontuação digitável; ver seção 5 do porquê)
AppTextField(
  label: 'CPF *',
  hint: '000.000.000-00',
  controller: _cpfController,
  keyboardType: TextInputType.number,
  errorText: _cpfError,
  inputFormatters: [CpfInputFormatter()],
  maxLength: 14,
),

// RG — SEM pontuação digitável, faixa 7–12
AppTextField(
  label: 'RG *',
  hint: 'Somente letras e números (7 a 12 caracteres)',
  controller: _rgController,
  keyboardType: TextInputType.text,
  errorText: _rgError,
  inputFormatters: [AlphanumericInputFormatter(maxLength: 12)],
  maxLength: 12,
),

// Matrícula — SEM pontuação digitável, sem mínimo, máx. 30
AppTextField(
  label: 'Matrícula *',
  hint: 'N° de matrícula (letras e números)',
  controller: _registrationController,
  keyboardType: TextInputType.text,
  errorText: _registrationError,
  inputFormatters: [AlphanumericInputFormatter(maxLength: 30)],
  maxLength: 30,
),

// Telefone — opcional, sem formatter (backend não valida formato)
AppTextField(
  label: 'Telefone',
  hint: '(12) 91234-5678',
  controller: _phoneController,
  keyboardType: TextInputType.phone,
  errorText: _phoneError,
),

// E-mail
AppTextField(
  label: 'E-mail *',
  hint: 'Informe seu e-mail',
  controller: _emailController,
  keyboardType: TextInputType.emailAddress,
  errorText: _emailError,
  maxLength: 100,
),
```

E a chamada de validação, campo a campo (dentro do `_validate()` da tela):

```dart
if (_rgController.text.trim().isEmpty) {
  _rgError = 'Campo obrigatório';
  valid = false;
} else {
  _rgError = validators.validateRg(_rgController.text);
  if (_rgError != null) valid = false;
}

if (_registrationController.text.trim().isEmpty) {
  _registrationError = 'Campo obrigatório';
  valid = false;
} else {
  _registrationError = validators.validateAlphanumericFormat(
      _registrationController.text, 'Matrícula', 30);
  if (_registrationError != null) valid = false;
}
```

### 3.4 — Montagem do corpo da requisição (o passo que quebrou antes — ver seção 5)

**Nunca envie o texto do controller direto para `cpf`/`rg` sem limpar.** No datasource,
antes de montar o body:

```dart
final body = <String, dynamic>{
  'role': 'Passenger', // 'Driver' no app motorista
  'fullName': params.fullName,
  // CPF e RG chegam aqui já formatados pela máscara/formatter do
  // formulário. O backend rejeita qualquer pontuação nos dois — precisa
  // ir só o valor "limpo", nunca o texto exibido no input.
  'cpf': unmaskDigits(params.cpf),
  'rg': unmaskRg(params.rg),
  'birthdate': DateFormat('yyyy-MM-dd').format(params.birthdate),
  'email': params.email.trim().toLowerCase(),
  'initialPassword': params.initialPassword,
  'registration': params.registration.trim(),
  'publicPartitionId': params.publicPartitionId, // específico do passageiro
};

if (params.phone != null && params.phone!.trim().isNotEmpty) {
  body['phone'] = params.phone!.trim();
}
```

---

## 4. Tratamento de erro do backend (mesmo padrão dos dois apps)

```dart
Exception _mapDioException(DioException e) {
  switch (e.response?.statusCode) {
    case 400:
      final serverMessage = e.response?.data?['error'] as String?;
      return ValidationException(
        serverMessage ?? 'Dados inválidos. Verifique as informações e tente novamente.',
      );
    case 409:
      final serverError = e.response?.data?['error'] as String? ?? '';
      final field = _extractDuplicateField(serverError);
      final message = _duplicateMessage(field, serverError);
      return DuplicateException(message, field: field);
    case var code when code != null && code >= 500:
      return const ServerException('Erro interno do servidor. Tente novamente mais tarde.');
    default:
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError) {
        return const NetworkException('Erro de conexão. Verifique sua internet e tente novamente.');
      }
      return NetworkException(e.message ?? 'Erro inesperado. Tente novamente.');
  }
}
```

`_extractDuplicateField` procura `email`/`cpf`/`cnh` no texto da mensagem de erro do 409
para dar uma mensagem amigável por campo — para o passageiro, ajuste a lista de campos
verificados (não tem `cnh`, mas pode ter `cpf`/`email`, e talvez algo ligado ao
`publicPartitionId` se o backend validar isso).

---

## 5. Lição já aprendida — não repita este bug

**O que aconteceu:** o campo de RG tinha uma máscara visual (`00.000.000-0`), mas o valor
**mascarado, com pontuação**, ia direto pro corpo da requisição, sem limpeza. O backend
exige `^[A-Za-z0-9]+$` (sem ponto/traço/barra/espaço) — resultado: **100% dos cadastros
com RG preenchido falhavam com 400**, silenciosamente, até alguém investigar a fundo.

**A correção teve duas partes, as duas obrigatórias:**
1. O **campo de entrada** parou de aplicar máscara com pontuação — agora só aceita
   alfanumérico puro desde a digitação (`AlphanumericInputFormatter`), então nunca existe
   pontuação para esquecer de limpar.
2. Mesmo assim, o **datasource** aplica `unmaskDigits`/`unmaskRg` antes de montar o corpo,
   como camada extra de defesa — protege contra `TextEditingController.text = ...`
   programático, que ignora o `TextInputFormatter`.

**Sequência de tamanho do RG também mudou durante o desenvolvimento** — começou sem
mínimo e máximo 20, depois foi ajustado para **mínimo 7, máximo 12** (faixa real de RGs
brasileiros válidos, incluindo formatos legados). Se você ver "20" em algum rascunho
anterior deste documento ou em código antigo, está desatualizado — a faixa vigente é
**7–12**, já refletida em todo o código acima.

**Regra geral pra não cair nisso de novo:** todo campo que tem máscara/formatter visual
precisa ter, no mínimo, uma pessoa perguntando explicitamente "o valor limpo ou o
mascarado é o que vai pro backend?" antes de dar como pronto. CPF tem o mesmo formato de
risco (máscara com pontuação) — já está com o `unmaskDigits` aplicado no exemplo da seção
3.4, não repita o problema aí.

---

## 6. Checklist de verificação

- [ ] `flutter analyze` limpo
- [ ] Testes de `masks.dart`/`validators.dart` cobrindo: RG aceita 7–12 alfanumérico,
      rejeita <7, rejeita >12, rejeita pontuação; Matrícula aceita alfanumérico até 30,
      rejeita pontuação
- [ ] Teste do datasource confirmando que `cpf`/`rg` saem **sem pontuação** no corpo da
      requisição, mesmo que o `RegisterParams` receba o valor já formatado
- [ ] Teste manual: preencher RG com 7 caracteres → sucesso; com 6 → erro; com 13 → erro;
      com pontuação (não deveria nem conseguir digitar) → confirmar que o formatter barra
- [ ] Confirmar com `curl` direto no backend, com um RG de 7 e um de 12 caracteres, que o
      endpoint aceita nos dois limites:
      ```bash
      curl -i -X POST http://localhost:5209/api/registrations \
        -H "Content-Type: application/json" \
        -d '{"role":"Passenger","fullName":"Teste","cpf":"...","rg":"1234567","registration":"1","birthdate":"1990-01-01","email":"teste@x.com","initialPassword":"Senha1234","publicPartitionId":"..."}'
      ```
- [ ] Confirmar que o `role` enviado é `"Passenger"`, não `"Driver"` (copiar/colar sem
      trocar isso é o erro mais bobo e mais fácil de cometer aqui)
