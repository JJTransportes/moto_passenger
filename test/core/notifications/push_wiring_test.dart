// Fiação do push na injeção de dependência (spec passenger-push-notifications, req
// 1.7 e 7.1): o serviço é único no app e pode ser substituído nos testes.
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moto_passenger/core/auth/sign_out_service.dart';
import 'package:moto_passenger/core/notifications/i_push_notification_service.dart';
import 'package:moto_passenger/core/notifications/notification_channel_service.dart';
import 'package:moto_passenger/core/notifications/onesignal_gateway.dart';
import 'package:moto_passenger/core/notifications/onesignal_push_service.dart';
import 'package:moto_passenger/core/notifications/pending_notification_router.dart';
import 'package:moto_passenger/modules/common_module.dart';
import 'package:moto_passenger/modules/auth/domain/repositories/i_auth_repository.dart';

class _RootModule extends Module {
  @override
  List<Module> get imports => [CommonModule()];
}

void main() {
  setUp(() => Modular.init(_RootModule()));

  tearDown(() {
    try {
      Modular.destroy();
    } catch (_) {}
  });

  test('o serviço de push é resolvido como o serviço do OneSignal', () {
    expect(Modular.get<IPushNotificationService>(), isA<OneSignalPushService>());
  });

  test('o serviço de push é um singleton (inicializa uma única vez por execução)', () {
    expect(
      identical(Modular.get<IPushNotificationService>(), Modular.get<IPushNotificationService>()),
      isTrue,
    );
  });

  test('o gateway do SDK é resolvido por interface (substituível nos testes)', () {
    expect(Modular.get<IOneSignalGateway>(), isA<OneSignalSdkGateway>());
  });

  test('o roteador do toque guardado é resolvido', () {
    expect(Modular.get<PendingNotificationRouter>(), isA<PendingNotificationRouter>());
  });

  test('SignOutService resolve com o push (cobre logout, exclusão de conta e sessão expirada)', () {
    expect(Modular.get<SignOutService>(), isA<SignOutService>());
  });

  test('AuthRepository resolve com o push (identifica o aparelho no login)', () {
    expect(Modular.get<IAuthRepository>(), isA<IAuthRepository>());
  });

  test('o serviço do canal de notificação é resolvido e é um singleton', () {
    final service = Modular.get<INotificationChannelService>();

    expect(service, isA<NotificationChannelService>());
    expect(identical(service, Modular.get<INotificationChannelService>()), isTrue);
  });
}
