import 'package:flutter/material.dart';

import '../data/neon/neon_http.dart';
import '../theme/app_colors.dart';

/// A one-line readout of whether the app can actually reach the Neon database.
///
/// It exists because a `--release` build that was compiled without
/// `--dart-define-from-file=.env` looks identical to a working one until you
/// notice `app.users` never fills in. This says so on screen — no `adb logcat`
/// needed. Safe to leave in; it is a thin status line, not a debug panel.
class NeonStatusBanner extends StatefulWidget {
  const NeonStatusBanner({super.key});

  @override
  State<NeonStatusBanner> createState() => _NeonStatusBannerState();
}

enum _State { checking, ok, notConfigured, unreachable }

class _NeonStatusBannerState extends State<NeonStatusBanner> {
  _State _status = _State.checking;
  String? _detail;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    if (!NeonHttp.isConfigured) {
      setState(() => _status = _State.notConfigured);
      return;
    }
    try {
      await NeonHttp.instance.ping();
      if (mounted) setState(() => _status = _State.ok);
    } catch (error) {
      if (mounted) {
        setState(() {
          _status = _State.unreachable;
          _detail = error.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final (Color fg, Color bg, IconData icon, String text) = switch (_status) {
      _State.checking => (
        AppColors.textMuted,
        AppColors.silverTint,
        Icons.sync_rounded,
        'Checking database…',
      ),
      _State.ok => (
        AppColors.brandGreenDeep,
        AppColors.greenTint,
        Icons.check_circle_outline_rounded,
        'Database connected — sign-in & registration will be saved',
      ),
      _State.notConfigured => (
        AppColors.danger,
        AppColors.dangerTint,
        Icons.error_outline_rounded,
        'No database configured (len=${NeonHttp.rawUrl.length}) — run '
            'tool/gen_neon_secret.dart, then rebuild',
      ),
      _State.unreachable => (
        AppColors.danger,
        AppColors.dangerTint,
        Icons.wifi_off_rounded,
        'Database unreachable — ${_detail ?? 'no connection'}',
      ),
    };

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              style: TextStyle(fontSize: 11.5, height: 1.3, color: fg),
            ),
          ),
        ],
      ),
    );
  }
}
