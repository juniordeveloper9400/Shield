import 'package:flutter_test/flutter_test.dart';
import 'package:shield/module/auth/widget_otp_initialization.dart';

void main() {
  test(
    'a failed initialization can retry instead of caching the failure',
    () async {
      final initialization = WidgetOtpInitialization<String>();
      var attempts = 0;
      Future<String> start() async {
        attempts++;
        if (attempts == 1) throw StateError('network unavailable');
        return 'ready';
      }

      await expectLater(initialization.ensure(start), throwsStateError);
      expect(await initialization.ensure(start), 'ready');
      expect(attempts, 2);
      expect(await initialization.ensure(start), 'ready');
      expect(attempts, 2);
    },
  );

  test('simultaneous requests share initialization', () async {
    final initialization = WidgetOtpInitialization<String>();
    var attempts = 0;
    Future<String> start() async {
      attempts++;
      return 'ready';
    }

    expect(
      await Future.wait([
        initialization.ensure(start),
        initialization.ensure(start),
      ]),
      ['ready', 'ready'],
    );
    expect(attempts, 1);
  });

  test('disposing initialization allows a new widget', () async {
    final initialization = WidgetOtpInitialization<int>();
    var attempts = 0;
    Future<int> start() async => ++attempts;
    expect(await initialization.ensure(start), 1);
    initialization.reset();
    expect(await initialization.ensure(start), 2);
  });
}
