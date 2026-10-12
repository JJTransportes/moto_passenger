import 'package:flutter/material.dart';

/// Global [ScaffoldMessengerState] key so non-widget code (interceptors,
/// services) can show a [SnackBar] without a [BuildContext] — e.g. the
/// "sessão expirou" message shown right after a forced logout triggered by
/// the auth interceptor.
final GlobalKey<ScaffoldMessengerState> appScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// Shows [message] in a [SnackBar] using the global messenger, if one is
/// currently attached to the widget tree. Safe to call from anywhere
/// (no-op if there's no messenger mounted yet).
void showGlobalSnackBar(String message) {
  final messenger = appScaffoldMessengerKey.currentState;
  messenger?.showSnackBar(SnackBar(content: Text(message)));
}
