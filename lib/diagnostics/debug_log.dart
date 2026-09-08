import 'dart:io';

import 'package:flutter/foundation.dart';

/// One captured line — a framework error, an uncaught async error, an
/// explicitly reported exception, or a plain `debugPrint`.
@immutable
class DebugLogEntry {
  final DateTime time;

  /// `flutter` · `error` · `log` — anything but `log` is an issue.
  final String level;
  final String message;
  final String? stack;

  const DebugLogEntry({
    required this.time,
    required this.level,
    required this.message,
    this.stack,
  });

  bool get isIssue => level != 'log';

  /// `[2026-09-08T14:03:11.482] ERROR  Something failed` + the stack below it.
  String format() {
    final head =
        '[${time.toIso8601String()}] ${level.toUpperCase().padRight(7)} $message';
    return stack == null || stack!.trim().isEmpty ? head : '$head\n$stack';
  }
}

/// Collects what went wrong while the app was running, so a member who hits a
/// bug can hand support a report instead of trying to describe it.
///
/// [install] hooks the three places Flutter surfaces trouble — framework
/// errors, uncaught async errors, and `debugPrint` — into a capped in-memory
/// buffer that is also mirrored to a file, so a report survives the crash that
/// produced it. Nothing here ever throws: a failure to write the log must not
/// become a second bug on top of the first.
class DebugLog {
  DebugLog._();

  static final DebugLog instance = DebugLog._();

  /// The buffer holds at most this many lines; older ones roll off. A report
  /// is meant to be read, not archived.
  static const int _maxEntries = 600;

  final List<DebugLogEntry> _entries = [];

  /// Bumps on every captured issue (not plain logs), so a menu badge can show
  /// "something to report" without the whole list rebuilding.
  final ValueNotifier<int> issueCount = ValueNotifier<int>(0);

  File? _file;
  bool _installed = false;

  List<DebugLogEntry> get entries => List.unmodifiable(_entries);

  bool get hasIssues => issueCount.value > 0;

  bool get isEmpty => _entries.isEmpty;

  /// Call once from `main()` before `runApp`. Idempotent.
  void install() {
    if (_installed) {
      return;
    }
    _installed = true;

    _openFile();

    final previousOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      _add('flutter', details.exceptionAsString(), details.stack?.toString());
      previousOnError?.call(details);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      _add('error', error.toString(), stack.toString());
      // Not "handled" — let the platform log/crash as it normally would.
      return false;
    };

    // Mirror debugPrint output into the buffer. Reassigning debugPrint is a
    // supported extension point; the original still runs.
    final originalDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null && message.isNotEmpty) {
        _add('log', message, null);
      }
      originalDebugPrint(message, wrapWidth: wrapWidth);
    };
  }

  /// Record a caught exception with context, e.g. from a repository's
  /// `catch` block: `DebugLog.instance.reportError(e, s, 'OrderRepository.save')`.
  void reportError(Object error, [StackTrace? stack, String? context]) {
    _add(
      'error',
      context == null || context.isEmpty ? '$error' : '$context — $error',
      stack?.toString(),
    );
  }

  void _add(String level, String message, String? stack) {
    final entry = DebugLogEntry(
      time: DateTime.now(),
      level: level,
      message: message,
      stack: stack,
    );
    _entries.add(entry);
    if (_entries.length > _maxEntries) {
      _entries.removeRange(0, _entries.length - _maxEntries);
    }
    if (entry.isIssue) {
      issueCount.value = _entries.where((e) => e.isIssue).length;
    }
    _appendToFile(entry);
  }

  void _openFile() {
    try {
      final file = File('${Directory.systemTemp.path}/shield_debug_log.txt');
      // Carry the tail of the previous run into this session, then start the
      // file fresh — a crash report is most useful with the run before it,
      // but two-runs-ago is just noise.
      if (file.existsSync()) {
        final previous = file.readAsStringSync().trim();
        if (previous.isNotEmpty) {
          _entries.add(
            DebugLogEntry(
              time: DateTime.now(),
              level: 'log',
              message: '──── previous session ────\n$previous\n──── this session ────',
            ),
          );
        }
        file.writeAsStringSync('');
      }
      _file = file;
    } catch (error) {
      // No writable temp dir (unusual). The in-memory buffer still works for
      // a report taken before the app is killed.
      _file = null;
    }
  }

  void _appendToFile(DebugLogEntry entry) {
    final file = _file;
    if (file == null) {
      return;
    }
    try {
      file.writeAsStringSync('${entry.format()}\n', mode: FileMode.append);
    } catch (_) {
      // Ignore — the buffer is the source of truth for the report.
    }
  }

  /// Empties the buffer and the file — offered on the report screen once a
  /// member has downloaded and sent what they needed.
  void clear() {
    _entries.clear();
    issueCount.value = 0;
    try {
      _file?.writeAsStringSync('');
    } catch (_) {}
  }

  /// The whole report as text: a header block, then every captured line.
  String buildReport({String? appVersion}) {
    final buffer = StringBuffer()
      ..writeln('SHIELD — debug report')
      ..writeln('Generated  : ${DateTime.now().toIso8601String()}')
      ..writeln('App        : ${appVersion ?? 'unknown'}')
      ..writeln('Build mode : ${kReleaseMode ? 'release' : 'debug'}')
      ..writeln('Platform   : ${_platformLine()}')
      ..writeln('Locale     : ${_localeName()}')
      ..writeln('Issues     : ${issueCount.value}   ·   Lines: ${_entries.length}')
      ..writeln('=' * 56);
    if (_entries.isEmpty) {
      buffer.writeln('No errors or logs were captured this session.');
    }
    for (final entry in _entries) {
      buffer.writeln(entry.format());
    }
    return buffer.toString();
  }

  /// Writes [buildReport] to a timestamped `.txt` file and returns its path,
  /// ready to hand to the platform share sheet. Null when no temp dir is
  /// available.
  Future<String?> writeReportFile({String? appVersion}) async {
    try {
      final stamp = DateTime.now()
          .toIso8601String()
          .replaceAll(RegExp(r'[:.]'), '-')
          .replaceAll('T', '_')
          .split('_')
          .take(2)
          .join('_');
      final file =
          File('${Directory.systemTemp.path}/shield-debug-$stamp.txt');
      await file.writeAsString(buildReport(appVersion: appVersion));
      return file.path;
    } catch (error) {
      return null;
    }
  }

  static String _platformLine() {
    try {
      return '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
    } catch (_) {
      return defaultTargetPlatform.name;
    }
  }

  static String _localeName() {
    try {
      return Platform.localeName;
    } catch (_) {
      return PlatformDispatcher.instance.locale.toLanguageTag();
    }
  }
}
