import 'dart:convert';

/// Converte respostas JSON de APIs em mapa sem lançar erro quando o servidor
/// devolve texto, corpo vazio ou JSON serializado como string.
Map<String, dynamic>? responseDataAsMap(Object? value) {
  Object? candidate = value;

  for (var attempt = 0; attempt < 2; attempt++) {
    if (candidate is Map<String, dynamic>) return candidate;
    if (candidate is Map) {
      return candidate.map((key, value) => MapEntry(key.toString(), value));
    }
    if (candidate is! String || candidate.trim().isEmpty) return null;

    try {
      candidate = jsonDecode(candidate);
    } on FormatException {
      return null;
    }
  }

  return candidate is Map
      ? candidate.map((key, value) => MapEntry(key.toString(), value))
      : null;
}
