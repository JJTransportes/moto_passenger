import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// Resolve o tipo de dispositivo usado no binding de sessão do backend.
///
/// Retorna `'android'` | `'ios'` em aparelhos reais e `null` (neutro) em
/// outras plataformas — nesse caso o campo `device` é omitido do request,
/// com o mesmo comportamento do web admin.
class DevicePlatform {
  static String? _testOverride;

  static String? get type => _testOverride ?? _detect();

  static String? _detect() {
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return null; // neutro — não envia 'device'
  }

  /// Permite fixar o tipo de dispositivo em testes (o host de testes não é
  /// Android/iOS, então `Platform.isAndroid`/`isIOS` retornam `false`).
  @visibleForTesting
  static void overrideForTesting(String? value) => _testOverride = value;

  @visibleForTesting
  static void clearOverride() => _testOverride = null;
}
