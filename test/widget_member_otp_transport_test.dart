import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shield/module/auth/auth_service.dart';

void main() {
  test('sending passes the MSG91 country-prefixed identifier', () async {
    String? identifier;
    final transport = WidgetMemberOtpTransport(sendOtp: (value) async { identifier = value; });
    expect((await transport.sendCode('9876543210')).ok, isTrue);
    expect(identifier, '919876543210');
  });

  test('a script timeout is reported as timeout instead of wrong code', () async {
    final transport = WidgetMemberOtpTransport(
      sendOtp: (_) async => throw TimeoutException('send'),
      verifyOtp: (_) async => throw TimeoutException('verify'),
    );
    expect((await transport.sendCode('9876543210')).failure, OtpError.timeout);
    expect((await transport.confirmCode('9876543210', '1234')).failure, OtpError.timeout);
  });

  test('missing widget build settings produce a configuration error', () async {
    final transport = WidgetMemberOtpTransport(sendOtp: (_) async => throw StateError('OTP sending is not configured in this build'));
    expect((await transport.sendCode('9876543210')).failure, OtpError.configError);
  });
}
