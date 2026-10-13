/// Shares startup, but never retains a failed startup across retries.
class WidgetOtpInitialization<T> {
  Future<T>? _pending;

  Future<T> ensure(Future<T> Function() start) {
    return _pending ??= Future<T>.sync(start).then(
      (value) => value,
      onError: (Object error, StackTrace stack) {
        _pending = null;
        Error.throwWithStackTrace(error, stack);
      },
    );
  }

  void reset() => _pending = null;
}
