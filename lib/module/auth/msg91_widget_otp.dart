/// Entry point for `sendWidgetOtp`/`verifyWidgetOtp` — MSG91's own JS
/// widget, run directly in the page on web (`msg91_widget_otp_web.dart`),
/// or hosted in an invisible headless WebView everywhere else
/// (`msg91_widget_otp_native.dart`) — see that file's own doc on why native
/// needs this too, not a plain server call. Import this file, never the
/// two it switches between directly.
library;

export 'msg91_widget_otp_native.dart' if (dart.library.js_interop) 'msg91_widget_otp_web.dart';
