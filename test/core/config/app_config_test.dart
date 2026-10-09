// Spec passenger-push-notifications (req 1.4): sem ONE_SIGNAL_ID o app inicia
// normalmente, apenas sem push — nunca lança erro nem deixa tela em branco.
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moto_passenger/core/config/app_config.dart';

void main() {
  tearDown(() => dotenv.loadFromString(envString: 'X=1'));

  test('lê API_BASE_URL e ONE_SIGNAL_ID quando presentes', () async {
    dotenv.loadFromString(envString: 'API_BASE_URL=http://api.test\nONE_SIGNAL_ID=app-123');

    await AppConfig.loadEnv();

    expect(AppConfig.getBaseUrl(), 'http://api.test');
    expect(AppConfig.getOneSignalAppId(), 'app-123');
  });

  test('sem ONE_SIGNAL_ID não lança e o identificador fica vazio', () async {
    dotenv.loadFromString(envString: 'API_BASE_URL=http://api.test');

    await expectLater(AppConfig.loadEnv(), completes);

    expect(AppConfig.getOneSignalAppId(), isEmpty);
    expect(AppConfig.getBaseUrl(), 'http://api.test');
  });

  test('ONE_SIGNAL_ID em branco também fica vazio', () async {
    dotenv.loadFromString(envString: 'API_BASE_URL=http://api.test\nONE_SIGNAL_ID=   ');

    await AppConfig.loadEnv();

    expect(AppConfig.getOneSignalAppId(), isEmpty);
  });

  test('o identificador é aparado', () async {
    dotenv.loadFromString(envString: 'API_BASE_URL=http://api.test\nONE_SIGNAL_ID=  app-123  ');

    await AppConfig.loadEnv();

    expect(AppConfig.getOneSignalAppId(), 'app-123');
  });

  test('recarregar sem o identificador limpa o valor anterior', () async {
    dotenv.loadFromString(envString: 'API_BASE_URL=http://api.test\nONE_SIGNAL_ID=app-123');
    await AppConfig.loadEnv();

    dotenv.loadFromString(envString: 'API_BASE_URL=http://api.test');
    await AppConfig.loadEnv();

    expect(AppConfig.getOneSignalAppId(), isEmpty);
  });
}
