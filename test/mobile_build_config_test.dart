import 'package:flutter_test/flutter_test.dart';
import 'package:shield/module/auth/mobile_build_config.dart';

void main() {
  test('Android builds without dart-defines have usable OTP configuration', () {
    expect(MobileBuildConfig.widgetId.isNotEmpty, isTrue);
    expect(MobileBuildConfig.widgetToken.isNotEmpty, isTrue);
    expect(Uri.parse(MobileBuildConfig.backendUrl).scheme, 'https');
    expect(Uri.parse(MobileBuildConfig.backendUrl).host.isNotEmpty, isTrue);
  });
}
