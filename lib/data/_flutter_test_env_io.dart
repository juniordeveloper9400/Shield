import 'dart:io' show Platform;

/// `true` when `flutter test` is running — it sets `FLUTTER_TEST` in the
/// environment. [BackendHttp]'s base URL is a compiled-in const, so without
/// this check every repository would fire real traffic at the backend
/// during a test run.
bool get isUnderFlutterTest => Platform.environment.containsKey('FLUTTER_TEST');
