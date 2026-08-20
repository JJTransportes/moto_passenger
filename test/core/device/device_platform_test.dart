import 'package:flutter_test/flutter_test.dart';
import 'package:moto_passenger/core/device/device_platform.dart';

void main() {
  tearDown(() {
    DevicePlatform.clearOverride();
  });

  group('DevicePlatform', () {
    test('returns null on non-mobile platforms by default (test host)', () {
      // O host de testes não é Android/iOS → neutro
      expect(DevicePlatform.type, isNull);
    });

    test('returns android when overridden', () {
      DevicePlatform.overrideForTesting('android');
      expect(DevicePlatform.type, 'android');
    });

    test('returns ios when overridden', () {
      DevicePlatform.overrideForTesting('ios');
      expect(DevicePlatform.type, 'ios');
    });

    test('clearOverride restores neutral behavior', () {
      DevicePlatform.overrideForTesting('android');
      expect(DevicePlatform.type, 'android');

      DevicePlatform.clearOverride();
      expect(DevicePlatform.type, isNull);
    });
  });
}
