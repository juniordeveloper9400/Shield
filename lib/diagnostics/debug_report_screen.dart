import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../theme/app_colors.dart';
import 'debug_log.dart';

/// "Debug report" — reached from the menu. Shows what the app has caught going
/// wrong this run and lets the member download it (a `.txt` file through the
/// system share sheet — "Save to Files" drops it in Downloads) to send to
/// support, or copy it, or clear it once they have.
class DebugReportScreen extends StatefulWidget {
  const DebugReportScreen({super.key});

  /// Kept in step with `pubspec.yaml`'s `version:`. Printed at the top of the
  /// report so a support ticket names the build it came from.
  static const String appVersion = '1.0.0+1';

  @override
  State<DebugReportScreen> createState() => _DebugReportScreenState();
}

class _DebugReportScreenState extends State<DebugReportScreen> {
  bool _busy = false;

  Future<void> _download() async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final path = await DebugLog.instance.writeReportFile(
        appVersion: DebugReportScreen.appVersion,
      );
      if (path == null) {
        // No file could be written — fall back to sharing the text itself.
        await SharePlus.instance.share(
          ShareParams(
            subject: 'SHIELD debug report',
            text: DebugLog.instance.buildReport(
              appVersion: DebugReportScreen.appVersion,
            ),
          ),
        );
      } else {
        await SharePlus.instance.share(
          ShareParams(
            subject: 'SHIELD debug report',
            text: 'SHIELD debug report attached.',
            files: [XFile(path, mimeType: 'text/plain')],
          ),
        );
      }
    } on Exception {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not open the share sheet here.')),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _copy() async {
    await Clipboard.setData(
      ClipboardData(
        text: DebugLog.instance.buildReport(
          appVersion: DebugReportScreen.appVersion,
        ),
      ),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report copied to clipboard')),
      );
    }
  }

  Future<void> _clear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear the report?'),
        content: const Text(
          'This removes every line captured so far. Download it first if you '
          'still need to send it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.brandBlue),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      DebugLog.instance.clear();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final log = DebugLog.instance;
    final entries = log.entries;

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        surfaceTintColor: AppColors.white,
        elevation: 0,
        title: const Text(
          'Debug report',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Download report',
            onPressed: _busy ? null : _download,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.brandBlue,
                    ),
                  )
                : const Icon(Icons.download_rounded, color: AppColors.brandBlue),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
      ),
      body: Column(
        children: [
          _SummaryCard(issues: log.issueCount.value, lines: entries.length),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: entries.isEmpty ? null : _copy,
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text('Copy'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.brandBlue,
                      side: const BorderSide(color: AppColors.brandBlue),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: entries.isEmpty ? null : _clear,
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: const Text('Clear'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textMuted,
                      side: const BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          Expanded(
            child: entries.isEmpty
                ? const _EmptyState()
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                    itemCount: entries.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) =>
                        _LogTile(entry: entries[entries.length - 1 - index]),
                  ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _busy ? null : _download,
              icon: const Icon(Icons.download_rounded, size: 20),
              label: Text(_busy ? 'Preparing…' : 'Download report'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brandBlue,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final int issues;
  final int lines;

  const _SummaryCard({required this.issues, required this.lines});

  @override
  Widget build(BuildContext context) {
    final ok = issues == 0;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ok ? AppColors.greenTint : const Color(0xFFFBEBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ok ? const Color(0xFFCDE8CA) : const Color(0xFFE7C3C3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            ok ? Icons.check_circle_outline_rounded : Icons.error_outline_rounded,
            color: ok ? AppColors.brandGreenDark : const Color(0xFFB4322F),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ok
                      ? 'No issues recorded'
                      : '$issues issue${issues == 1 ? '' : 's'} recorded',
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  ok
                      ? 'If something goes wrong, come back and download the report to send to support.'
                      : '$lines lines captured · Download and send this to support.',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textBody,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LogTile extends StatelessWidget {
  final DebugLogEntry entry;

  const _LogTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final issue = entry.isIssue;
    final tint = issue ? const Color(0xFFFBEBEB) : AppColors.pageTint;
    final accent =
        issue ? const Color(0xFFB4322F) : AppColors.textMuted;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                entry.level.toUpperCase(),
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: accent,
                ),
              ),
              const Spacer(),
              Text(
                _clock(entry.time),
                style: const TextStyle(
                  fontSize: 10.5,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SelectableText(
            entry.stack == null
                ? entry.message
                : '${entry.message}\n${entry.stack}',
            style: const TextStyle(
              fontSize: 12,
              height: 1.35,
              fontFamily: 'monospace',
              color: AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }

  static String _clock(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bug_report_outlined,
              size: 46,
              color: AppColors.textMuted.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 12),
            const Text(
              'Nothing to report',
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'The app has not caught anything going wrong this run. If you hit '
              'a bug, open this screen again and download the report.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
