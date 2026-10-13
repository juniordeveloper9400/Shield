/// Public Android client settings, shared with the release scripts.
/// This is MSG91's scoped widget token, never the server Authkey.
/// Dart defines can override these defaults for another deployment.
abstract final class MobileBuildConfig {
  static const widgetId = String.fromEnvironment(
    'MSG91_WIDGET_ID', defaultValue: '366a696a446a343235393238',
  );
  static const widgetToken = String.fromEnvironment(
    'MSG91_WIDGET_TOKEN_AUTH', defaultValue: '579930TU1QZriuNLU6ac9d73bP1',
  );
  static const backendUrl = String.fromEnvironment(
    'BACKEND_API_BASE_URL', defaultValue: 'https://shieldbackend.vercel.app',
  );
}