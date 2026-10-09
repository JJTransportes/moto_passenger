import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:onesignal_flutter/onesignal_flutter.dart';

/// Conteúdo de uma notificação entregue pelo SDK, já sem tipos do pacote.
class PushNotificationContent {
  final Map<String, dynamic>? additionalData;
  final String? title;
  final String? body;

  const PushNotificationContent({
    required this.additionalData,
    required this.title,
    required this.body,
  });
}

/// Fina camada sobre a API estática do OneSignal. É o ÚNICO arquivo que importa
/// o pacote `onesignal_flutter`: o resto do app (e os testes) fala com esta
/// interface (spec passenger-push-notifications).
abstract class IOneSignalGateway {
  /// Falso onde o SDK não existe (ex.: Flutter Web).
  bool get isSupported;

  /// `android` ou `ios`, como o backend espera no registro do aparelho.
  String get platform;

  Future<void> initialize(String appId);

  /// Pede a permissão de notificações. Devolve se foi concedida.
  Future<bool> requestPermission();

  /// Associa o aparelho ao usuário (`external id`), que é como o backend endereça.
  Future<void> login(String externalId);

  Future<void> logout();

  /// Identificador do aparelho no OneSignal; nulo até a assinatura existir.
  String? get pushSubscriptionId;

  /// Avisa quando o identificador do aparelho muda ou passa a existir.
  void onSubscriptionChanged(void Function(String? id) listener);

  /// Toque na notificação (inclusive o que abriu o app: o SDK guarda o clique até
  /// o listener ser registrado).
  void onNotificationClicked(
    void Function(PushNotificationContent content) listener,
  );

  /// Notificação prestes a ser exibida com o app em primeiro plano. O [shouldSuppress]
  /// decide de forma síncrona; `true` impede o banner do sistema.
  void onNotificationWillDisplay(
    bool Function(PushNotificationContent content) shouldSuppress,
  );
}

class OneSignalSdkGateway implements IOneSignalGateway {
  @override
  bool get isSupported => !kIsWeb;

  @override
  String get platform => Platform.isIOS ? 'ios' : 'android';

  @override
  Future<void> initialize(String appId) => OneSignal.initialize(appId);

  @override
  Future<bool> requestPermission() =>
      OneSignal.Notifications.requestPermission(false);

  @override
  Future<void> login(String externalId) => OneSignal.login(externalId);

  @override
  Future<void> logout() => OneSignal.logout();

  @override
  String? get pushSubscriptionId => OneSignal.User.pushSubscription.id;

  @override
  void onSubscriptionChanged(void Function(String? id) listener) {
    OneSignal.User.pushSubscription.addObserver(
      (state) => listener(state.current.id),
    );
  }

  @override
  void onNotificationClicked(
    void Function(PushNotificationContent content) listener,
  ) {
    OneSignal.Notifications.addClickListener(
      (event) => listener(_content(event.notification)),
    );
  }

  @override
  void onNotificationWillDisplay(
    bool Function(PushNotificationContent content) shouldSuppress,
  ) {
    OneSignal.Notifications.addForegroundWillDisplayListener((event) {
      // `preventDefault` precisa ser chamado de forma síncrona dentro do listener.
      if (shouldSuppress(_content(event.notification))) {
        event.preventDefault();
      }
    });
  }

  static PushNotificationContent _content(OSNotification notification) =>
      PushNotificationContent(
        additionalData: notification.additionalData,
        title: notification.title,
        body: notification.body,
      );
}
