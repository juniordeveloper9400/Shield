import 'dart:async';
import 'dart:convert';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'widget_otp_initialization.dart';
import 'mobile_build_config.dart';

/// MSG91 Widget OTP on native (Android/iOS) — runs the exact same JS widget
/// `msg91_widget_otp_web.dart` runs in a real browser, just hosted in an
/// invisible, headless WebView instead of the page itself. See that file's
/// own doc for why this has to be the JS widget rather than a plain
/// server-to-server call: confirmed live (2026-10-13) that
/// `backend/api`'s `sendMsg91Otp`/`verifyMsg91Otp` — a bare REST call with
/// the exact same widgetId/tokenAuth — gets HTTP 403 "Invalid request"
/// from MSG91, while the identical credential works fine through the
/// widget's own JS. MSG91's Widget product evidently does not support a
/// real server-to-server send at all; the browser-hosted widget is the
/// only supported shape, on every platform.
///
/// `HeadlessInAppWebView` (flutter_inappwebview) rather than
/// `webview_flutter`: it is built specifically to run a page and its JS
/// without ever being part of the widget tree or shown on screen — exactly
/// what sending an SMS OTP needs, with nothing for the member to look at.
///
/// `MSG91_WIDGET_ID`/`MSG91_WIDGET_TOKEN_AUTH` are compiled in via
/// `--dart-define`, identically to the web build (see that file's own
/// doc on why that's safe to ship client-side by MSG91's own design).
const String _widgetId = MobileBuildConfig.widgetId;
const String _tokenAuth = MobileBuildConfig.widgetToken;
const String _scriptUrl = 'https://verify.msg91.com/otp-provider.js';

/// A real HTTPS origin for the headless page, rather than `about:blank` or
/// a bare `data:` URL — MSG91's own script makes cross-origin XHR/fetch
/// calls to its own servers, which some WebView origin policies refuse
/// from a null/opaque origin. Never actually requested; the WebView never
/// navigates anywhere beyond the inline HTML `baseUrl` below loads with.
final WebUri _baseUri = WebUri('https://app.sahakar360.local/');

HeadlessInAppWebView? _headless;
InAppWebViewController? _controller;
final _initialization = WidgetOtpInitialization<InAppWebViewController>();
const _operationTimeout = Duration(seconds: 30);
int _requestId = 0;

String get _pageHtml =>
    '''
<!DOCTYPE html>
<html>
<head><meta charset="utf-8"></head>
<body>
<script>
  var booted = false;
  function report(ok, message) {
    window.flutter_inappwebview.callHandler('sahakarOtpReady', ok, message);
  }
  function boot() {
    if (booted || !window.flutter_inappwebview || !window.flutter_inappwebview.callHandler) return;
    booted = true;
    var script = document.createElement('script');
    script.src = ${jsonEncode(_scriptUrl)};
    script.onerror = function () { report(false, 'Could not load SMS verification. Check your connection and try again.'); };
    script.onload = function () {
      try {
        initSendOTP({
        widgetId: ${jsonEncode(_widgetId)},
        tokenAuth: ${jsonEncode(_tokenAuth)},
        exposeMethods: true,
        success: function (data) {},
        failure: function (err) {}
        });
        (function poll(remaining) {
          if (typeof window.sendOtp === 'function' && typeof window.verifyOtp === 'function') {
            report(true, 'ready');
          } else if (remaining > 0) {
            setTimeout(function () { poll(remaining - 1); }, 50);
          } else {
            report(false, 'SMS verification could not start. Please try again.');
          }
        })(200);
      } catch (e) { report(false, 'SMS verification could not start. Please try again.'); }
    };
    document.head.appendChild(script);
  }
  window.addEventListener('flutterInAppWebViewPlatformReady', boot);
  window.addEventListener('load', boot);
  boot();
</script>
</body>
</html>
''';

/// Starts the headless page once and waits for `window.sendOtp`/`verifyOtp`
/// to actually be attached — `initSendOTP` defers its own setup the same
/// way it does in a real browser (see `msg91_widget_otp_web.dart`'s own
/// doc on why a poll is needed rather than a single synchronous check).
Future<InAppWebViewController> _ensureWidget() {
  return _initialization.ensure(() async {
    if (_widgetId.isEmpty || _tokenAuth.isEmpty) {
      throw StateError(
        'OTP sending is not configured in this build (missing MSG91_WIDGET_ID/MSG91_WIDGET_TOKEN_AUTH).',
      );
    }

    final readyCompleter = Completer<void>();
    final headless = HeadlessInAppWebView(
      initialData: InAppWebViewInitialData(data: _pageHtml, baseUrl: _baseUri),
      initialSettings: InAppWebViewSettings(javaScriptEnabled: true),
      onWebViewCreated: (controller) {
        _controller = controller;
        controller.addJavaScriptHandler(
          handlerName: 'sahakarOtpReady',
          callback: (args) {
            if (readyCompleter.isCompleted) return;
            if (args.isNotEmpty && args[0] == true) {
              readyCompleter.complete();
            } else {
              readyCompleter.completeError(
                StateError(
                  'SMS verification could not load. Check your connection and try again.',
                ),
              );
            }
          },
        );
      },
      onLoadStop: (controller, _) async {
        await controller.evaluateJavascript(source: 'boot();');
      },
    );
    _headless = headless;
    // Attach error handling before startup can fire a JS failure callback.
    final ready = readyCompleter.future.timeout(const Duration(seconds: 20));
    try {
      await Future.wait([headless.run(), ready]);
      return _controller!;
    } catch (_) {
      try {
        await headless.dispose();
      } catch (_) {
        /* Startup may fail before a platform view exists. */
      }
      _headless = null;
      _controller = null;
      rethrow;
    }
  });
}

/// Sends a real SMS OTP to [identifier] — MSG91 format: country-code
/// prefixed digits only (e.g. `919876543210`), no `+`. Throws on failure.
Future<void> sendWidgetOtp(String identifier) async {
  final controller = await _ensureWidget();
  final resultCompleter = Completer<void>();
  final handler = 'sahakarSendResult${++_requestId}';
  final result = resultCompleter.future.timeout(_operationTimeout);
  controller.addJavaScriptHandler(
    handlerName: handler,
    callback: (args) {
      if (resultCompleter.isCompleted) return;
      final ok = args.isNotEmpty && args[0] == true;
      if (ok) {
        resultCompleter.complete();
      } else {
        final message = args.length > 1
            ? _describeJsError(args[1])
            : 'Could not send the code.';
        resultCompleter.completeError(StateError(message));
      }
    },
  );
  try {
    await Future.wait<dynamic>([
      controller.evaluateJavascript(
        source:
            '''
      try { window.sendOtp(
        ${jsonEncode(identifier)},
        function (data) { window.flutter_inappwebview.callHandler('$handler', true, data); },
        function (err) { window.flutter_inappwebview.callHandler('$handler', false, err); }
      ); } catch (e) { window.flutter_inappwebview.callHandler('$handler', false, 'Could not start SMS verification.'); }
    ''',
      ),
      result,
    ]);
  } finally {
    controller.removeJavaScriptHandler(handlerName: handler);
  }
}

/// Verifies [code] against the last [sendWidgetOtp] call and returns the
/// MSG91 access-token on success — hand this to the backend
/// (`/v1/member/auth/widget/verify`, `/widget/register`, or
/// `/v1/agent/otp/verify-widget`) to actually confirm it server-side; the
/// token alone proves nothing on its own.
Future<String> verifyWidgetOtp(String code) async {
  final controller = await _ensureWidget();
  final resultCompleter = Completer<String>();
  final handler = 'sahakarVerifyResult${++_requestId}';
  final result = resultCompleter.future.timeout(_operationTimeout);
  controller.addJavaScriptHandler(
    handlerName: handler,
    callback: (args) {
      if (resultCompleter.isCompleted) return;
      final ok = args.isNotEmpty && args[0] == true;
      if (ok) {
        final token = args.length > 1 ? _accessTokenFrom(args[1]) : null;
        if (token != null) {
          resultCompleter.complete(token);
        } else {
          resultCompleter.completeError(
            StateError('Could not verify that code.'),
          );
        }
      } else {
        final message = args.length > 1
            ? _describeJsError(args[1])
            : 'Could not send the code.';
        resultCompleter.completeError(StateError(message));
      }
    },
  );
  try {
    final values = await Future.wait<dynamic>([
      controller.evaluateJavascript(
        source:
            '''
      try { window.verifyOtp(
        ${jsonEncode(code)},
        function (data) { window.flutter_inappwebview.callHandler('$handler', true, data); },
        function (err) { window.flutter_inappwebview.callHandler('$handler', false, err); }
      ); } catch (e) { window.flutter_inappwebview.callHandler('$handler', false, 'Could not verify that code.'); }
    ''',
      ),
      result,
    ]);
    return values.last as String;
  } finally {
    controller.removeJavaScriptHandler(handlerName: handler);
  }
}

/// [data] arrives already JSON-decoded by the plugin's own bridge (a
/// String, a Map, or null) — mirrors `_accessTokenFrom` in
/// `msg91_widget_otp_web.dart`, same candidate field names MSG91's
/// callback payload is known to use.
String? _accessTokenFrom(Object? data) {
  if (data == null) return null;
  if (data is String) return data;
  if (data is Map) {
    for (final key in ['access-token', 'message', 'token']) {
      final value = data[key];
      if (value is String) return value;
    }
  }
  return null;
}

String _describeJsError(Object? err) {
  if (err == null) return 'Could not send the code.';
  if (err is String) return err;
  if (err is Map && err['message'] is String) return err['message'] as String;
  return 'Could not send the code.';
}

/// Tears the headless widget down — not called anywhere yet (a fresh
/// `sendWidgetOtp` after a failed attempt just reuses the same page; MSG91
/// identifiers are per-call, not per-session), but here so a future caller
/// (e.g. on sign-out) has a clean way to release it rather than leaving it
/// running for the rest of the app's process lifetime.
Future<void> disposeWidgetOtp() async {
  await _headless?.dispose();
  _headless = null;
  _controller = null;
  _initialization.reset();
}
