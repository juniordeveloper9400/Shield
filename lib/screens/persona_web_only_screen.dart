import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../module/auth/auth_service.dart';
import '../module/auth/persona_gate.dart';
import '../theme/app_colors.dart';

/// Shown in place of the whole app when the signed-in member has been made an
/// agent or investor from the admin console.
///
/// Agents and investors run everything from the web portal, so the shop, cart
/// and account screens are taken away and replaced with this: what changed,
/// and the link to the web app.
class PersonaWebOnlyScreen extends StatelessWidget {
  const PersonaWebOnlyScreen({super.key, this.status});

  /// The persona to name in the copy. Falls back to [PersonaGate]'s current
  /// status when not given.
  final PersonaStatus? status;

  /// The web portal agents and investors sign in to.
  static const String webAppUrl = 'https://shield-webapp-xq85.vercel.app/';

  /// The launch itself, behind a seam so a test can watch it fire without a
  /// browser to open. Reset with [resetOpenerForTest].
  @visibleForTesting
  static Future<bool> Function(Uri uri) opener =
      (uri) => launchUrl(uri, mode: LaunchMode.externalApplication);

  @visibleForTesting
  static void resetOpenerForTest() =>
      opener = (uri) => launchUrl(uri, mode: LaunchMode.externalApplication);

  PersonaStatus get _status =>
      status ?? PersonaGate.instance.status;

  String get _personaWord =>
      _status == PersonaStatus.investor ? 'Investor' : 'Agent';

  Future<void> _openWebApp(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    var opened = false;
    try {
      opened = await opener(Uri.parse(webAppUrl));
    } catch (_) {
      opened = false;
    }
    if (!opened) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Could not open the browser. Copy the link instead.'),
            backgroundColor: AppColors.textDark,
          ),
        );
    }
  }

  Future<void> _copyLink(BuildContext context) async {
    await Clipboard.setData(const ClipboardData(text: webAppUrl));
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Link copied')),
      );
  }

  @override
  Widget build(BuildContext context) {
    final persona = _personaWord;

    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 40, 28, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Image.asset(
                  'assets/logos/shield_logo.png',
                  height: 64,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 36),
                Container(
                  width: 76,
                  height: 76,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.pageTint,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.language_rounded,
                    size: 38,
                    color: AppColors.brandBlue,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  "You're now a SHIELD $persona",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'The SHIELD app is for members. ${persona}s manage their '
                  'portfolio, team and earnings on the web portal — open it in '
                  'your browser to sign in with this same mobile number.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14.5,
                    height: 1.5,
                    color: AppColors.textBody,
                  ),
                ),
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.pageTint,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.link_rounded,
                        size: 18,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SelectableText(
                          PersonaWebOnlyScreen.webAppUrl,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.brandBlue,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Copy link',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _copyLink(context),
                        icon: const Icon(
                          Icons.copy_rounded,
                          size: 18,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => _openWebApp(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brandBlue,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Open the web app',
                    style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: AuthService.instance.logOut,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textMuted,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    'Log out',
                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
