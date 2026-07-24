// lib/widgets/security_level_dialog.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../l10n/app_localizations.dart';
import '../screens/active_sessions_screen.dart' show showStyledSnack;

// Full-width editor for the device-trust security level & session TTL,
// pulled out of the settings accordion into its own dialog (styled to match
// showAboutOnyxDialog) so the three level cards and their descriptions get a
// fixed, comfortable width instead of being squeezed by whatever narrow
// column the "Active Devices" settings panel happens to have.
Future<void> showSecurityLevelDialog(
  BuildContext context, {
  required String serverBase,
  required String token,
  required String level,
  required int? ttlDays,
  required int? recommendedTtl,
  required ValueChanged<String> onLevelChanged,
  required ValueChanged<int?> onTtlChanged,
}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Security level',
    barrierColor: Colors.black.withValues(alpha: 0.55),
    transitionDuration: const Duration(milliseconds: 187),
    transitionBuilder: (ctx, anim, _, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeIn),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
    pageBuilder: (ctx, _, __) => _SecurityLevelDialogContent(
      serverBase: serverBase,
      token: token,
      initialLevel: level,
      initialTtlDays: ttlDays,
      initialRecommendedTtl: recommendedTtl,
      onLevelChanged: onLevelChanged,
      onTtlChanged: onTtlChanged,
    ),
  );
}

class _SecurityLevelDialogContent extends StatefulWidget {
  final String serverBase;
  final String token;
  final String initialLevel;
  final int? initialTtlDays;
  final int? initialRecommendedTtl;
  final ValueChanged<String> onLevelChanged;
  final ValueChanged<int?> onTtlChanged;

  const _SecurityLevelDialogContent({
    required this.serverBase,
    required this.token,
    required this.initialLevel,
    required this.initialTtlDays,
    required this.initialRecommendedTtl,
    required this.onLevelChanged,
    required this.onTtlChanged,
  });

  @override
  State<_SecurityLevelDialogContent> createState() =>
      _SecurityLevelDialogContentState();
}

class _SecurityLevelDialogContentState
    extends State<_SecurityLevelDialogContent> {
  static const List<int?> _ttlOptions = [14, 30, 90, 180, 365, 730, null];

  late String _level = widget.initialLevel;
  late int? _ttlDays = widget.initialTtlDays;
  late int? _recommendedTtl = widget.initialRecommendedTtl;
  bool _saving = false;

  Future<void> _save(
    Map<String, dynamic> body, {
    required VoidCallback onSuccess,
    required VoidCallback onRevert,
  }) async {
    setState(() => _saving = true);
    try {
      final res = await http.put(
        Uri.parse('${widget.serverBase}/me/security-settings'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );
      if (!mounted) return;
      setState(() => _saving = false);
      if (res.statusCode == 200) {
        onSuccess();
      } else {
        onRevert();
        final l10n = AppLocalizations.of(context);
        String message = l10n.error;
        if (res.statusCode == 403) {
          message = l10n.securityLevelLowerRequiresTrusted;
        }
        showStyledSnack(context, message);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      onRevert();
      showStyledSnack(context, '$e');
    }
  }

  void _onLevelChanged(String newLevel) {
    if (newLevel == _level) return;
    final previous = _level;
    setState(() => _level = newLevel);
    _save(
      {'security_level': newLevel},
      onSuccess: () {
        final l10n = AppLocalizations.of(context);
        setState(() => _recommendedTtl = const {
              'easy': 90,
              'balanced': 30,
              'strict': 14,
            }[newLevel]);
        widget.onLevelChanged(newLevel);
        showStyledSnack(context, l10n.securityLevelUpdated);
      },
      onRevert: () => setState(() => _level = previous),
    );
  }

  void _onTtlChanged(int? newTtl) {
    if (newTtl == _ttlDays) return;
    final previous = _ttlDays;
    setState(() => _ttlDays = newTtl);
    _save(
      {'session_ttl_days': newTtl},
      onSuccess: () {
        final l10n = AppLocalizations.of(context);
        widget.onTtlChanged(newTtl);
        showStyledSnack(context, l10n.sessionTtlUpdated);
      },
      onRevert: () => setState(() => _ttlDays = previous),
    );
  }

  String _levelLabel(AppLocalizations l10n, String level) {
    switch (level) {
      case 'easy':
        return l10n.securityLevelEasy;
      case 'strict':
        return l10n.securityLevelStrict;
      default:
        return l10n.securityLevelBalanced;
    }
  }

  String _levelDesc(AppLocalizations l10n, String level) {
    switch (level) {
      case 'easy':
        return l10n.securityLevelEasyDesc;
      case 'strict':
        return l10n.securityLevelStrictDesc;
      default:
        return l10n.securityLevelBalancedDesc;
    }
  }

  String _ttlLabel(AppLocalizations l10n, int? days) =>
      days == null ? l10n.sessionTtlNever : l10n.sessionTtlDays(days);

  Widget _sectionLabel(ColorScheme cs, String text) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
            color: cs.onSurface.withValues(alpha: 0.38),
          ),
        ),
      );

  Widget _levelRow(AppLocalizations l10n, ColorScheme cs, String level,
      {required bool isLast}) {
    final selected = level == _level;
    return InkWell(
      onTap: _saving ? null : () => _onLevelChanged(level),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : Border(
                  bottom: BorderSide(
                    color: cs.outlineVariant.withValues(alpha: 0.2),
                    width: 0.8,
                  ),
                ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              size: 18,
              color: selected ? cs.primary : cs.onSurfaceVariant,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _levelLabel(l10n, level),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: selected ? cs.primary : cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _levelDesc(l10n, level),
                    style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant, height: 1.35),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ttlChip(AppLocalizations l10n, ColorScheme cs, int? days) {
    final selected = days == _ttlDays;
    final recommended = days == _recommendedTtl;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: _saving ? null : () => _onTtlChanged(days),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? cs.primary.withValues(alpha: 0.14)
              : cs.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? cs.primary.withValues(alpha: 0.6)
                : cs.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Icon(Icons.check_rounded, size: 14, color: cs.primary),
              ),
            Text(
              _ttlLabel(l10n, days),
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? cs.primary : cs.onSurface,
              ),
            ),
            if (recommended && !selected)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Icon(Icons.star_rounded, size: 13, color: cs.primary.withValues(alpha: 0.7)),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    const levels = ['easy', 'balanced', 'strict'];

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Material(
            color: cs.surface,
            borderRadius: BorderRadius.circular(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Header ────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 20, 16, 16),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.06),
                    border: Border(
                      bottom: BorderSide(
                        color: cs.primary.withValues(alpha: 0.10),
                        width: 0.8,
                      ),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(Icons.shield_outlined, size: 22, color: cs.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.securityLevelTitle,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 150),
                              child: _saving
                                  ? SizedBox(
                                      key: const ValueKey('saving'),
                                      height: 12,
                                      width: 12,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary),
                                    )
                                  : Container(
                                      key: ValueKey(_level),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: cs.primary.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        _levelLabel(l10n, _level),
                                        style: TextStyle(
                                          color: cs.primary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: cs.onSurface.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.close_rounded, size: 18, color: cs.onSurface.withValues(alpha: 0.55)),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Security level ──────────────────────────────────
                _sectionLabel(cs, l10n.securityLevelTitle.toUpperCase()),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3), width: 0.8),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        for (var i = 0; i < levels.length; i++)
                          _levelRow(l10n, cs, levels[i], isLast: i == levels.length - 1),
                      ],
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Divider(
                    height: 1,
                    indent: 20,
                    endIndent: 20,
                    color: cs.outlineVariant.withValues(alpha: 0.25),
                  ),
                ),

                // ── Session lifetime ─────────────────────────────────
                _sectionLabel(cs, l10n.sessionTtlTitle.toUpperCase()),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                  child: Text(
                    l10n.sessionTtlSubtitle,
                    style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant, height: 1.35),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [for (final opt in _ttlOptions) _ttlChip(l10n, cs, opt)],
                  ),
                ),

                // ── Close button ──────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(50))),
                    ),
                    child: Text(l10n.close),
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
