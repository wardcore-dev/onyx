// lib/screens/active_sessions_screen.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../managers/account_manager.dart';
import '../managers/settings_manager.dart';
import '../l10n/app_localizations.dart';
import '../widgets/onyx_dialog.dart';
import '../widgets/security_level_dialog.dart';
import 'recovery_screen.dart';

// Shared with SecurityLevelSection so every card on this screen (device
// entries, security settings) uses the same wallpaper-aware glass surface
// instead of the theme's flat default Card color.
Color glassSurfaceColor(ColorScheme cs, {double? alphaOverride}) =>
    SettingsManager.glassSurfaceColor(cs.surfaceContainerHigh, alphaOverride: alphaOverride);

// Matches RootScreen's _presentSnack styling so feedback on this screen looks
// consistent with the rest of the app instead of the Material default SnackBar.
void showStyledSnack(BuildContext context, String text) {
  if (!SettingsManager.snackbarEnabled.value) return;
  final colorScheme = Theme.of(context).colorScheme;
  final brightness = SettingsManager.elementBrightness.value;
  final opacity = SettingsManager.elementOpacity.value;
  final backgroundColor = SettingsManager.getElementColor(
    colorScheme.surfaceContainerHighest,
    brightness,
  ).withValues(alpha: opacity);

  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        text,
        style: TextStyle(
          color: colorScheme.onSurfaceVariant,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        textAlign: TextAlign.center,
      ),
      backgroundColor: backgroundColor,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      margin: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
      elevation: 4,
      duration: const Duration(seconds: 2),
    ),
  );
}

// Embeddable device-management panel: security level, recovery banner and
// the session list, laid out as a plain (non-scrolling) Column so it can sit
// inside Settings' collapsible "Active Devices" section — the section's own
// AnimatedSize/ScrollView provides the bounds, unlike the old full-screen
// version which needed its own Scaffold + Expanded/ListView.
class ActiveDevicesPanel extends StatefulWidget {
  final String serverBase;
  final String? username;
  // Hidden on a device that isn't primary/trusted yet — the security level
  // it would show reflects the account's real setting, not something this
  // device is allowed to see or change until it recovers trust.
  final bool showSecurityLevel;

  const ActiveDevicesPanel({
    super.key,
    required this.serverBase,
    this.username,
    this.showSecurityLevel = true,
  });

  @override
  State<ActiveDevicesPanel> createState() => _ActiveDevicesPanelState();
}

class _ActiveDevicesPanelState extends State<ActiveDevicesPanel> {
  List<Map<String, dynamic>> _sessions = [];
  bool _loading = true;
  String? _error;
  String? _token;
  // Tracked separately from _sessions: a pending account-recovery request
  // isn't tied to this device's own trust state, so once this device gets
  // approved the RecoveryBanner must keep showing (it's the only entry point
  // to cancel it) instead of disappearing along with the "untrusted" badge.
  bool _hasPendingRecovery = false;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  @override
  void didUpdateWidget(ActiveDevicesPanel old) {
    super.didUpdateWidget(old);
    if (old.username != widget.username) {
      _token = null;
      _loadSessions();
    }
  }

  Future<void> _loadSessions() async {
    setState(() { _loading = true; _error = null; });
    try {
      final username = widget.username;
      if (username == null) {
        setState(() { _error = 'Not logged in'; _loading = false; });
        return;
      }
      _token ??= await AccountManager.getToken(username);
      if (!mounted) return;
      if (_token == null) {
        setState(() { _error = 'Not authenticated'; _loading = false; });
        return;
      }
      final res = await http.get(
        Uri.parse('${widget.serverBase}/me/sessions'),
        headers: {'Authorization': 'Bearer $_token'},
      );
      if (!mounted) return;
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        setState(() {
          _sessions = list.cast<Map<String, dynamic>>();
          _loading = false;
        });
        unawaited(_loadRecoveryStatus());
      } else {
        setState(() { _error = 'Failed to load sessions (${res.statusCode})'; _loading = false; });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = 'Network error: $e'; _loading = false; });
    }
  }

  Future<void> _loadRecoveryStatus() async {
    try {
      final res = await http.get(
        Uri.parse('${widget.serverBase}/auth/recover-primary/status'),
        headers: {'Authorization': 'Bearer $_token'},
      );
      if (!mounted || res.statusCode != 200) return;
      final data = jsonDecode(res.body);
      setState(() => _hasPendingRecovery = data['status'] == 'pending');
    } catch (_) {}
  }

  Future<void> _revokeSession(int id) async {
    final l = AppLocalizations.of(context);
    final confirmed = await showOnyxConfirmDialog(
      context: context,
      title: l.revokeSessionQuestion,
      message: l.revokeSessionConfirm,
      confirmLabel: l.revoke,
      isDestructive: true,
      icon: Icons.logout,
    );
    if (confirmed != true) return;
    try {
      final res = await http.delete(
        Uri.parse('${widget.serverBase}/me/sessions/$id'),
        headers: {'Authorization': 'Bearer $_token'},
      );
      if (res.statusCode == 200) {
        _loadSessions();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).failedToRevokeSession)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _approveSession(int id) async {
    try {
      final res = await http.post(
        Uri.parse('${widget.serverBase}/me/sessions/$id/approve'),
        headers: {'Authorization': 'Bearer $_token'},
      );
      if (res.statusCode == 200) {
        _loadSessions();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).failedToApproveDevice)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  String _formatDate(String? iso) {
    if (iso == null) return 'Unknown';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 30) return '${diff.inDays}d ago';
      return '${dt.day}.${dt.month}.${dt.year}';
    } catch (e) {
      return iso;
    }
  }

  IconData _deviceIcon(String os) {
    final lower = os.toLowerCase();
    if (lower.contains('android')) return Icons.phone_android;
    if (lower.contains('ios')) return Icons.phone_iphone;
    if (lower.contains('windows')) return Icons.desktop_windows;
    if (lower.contains('mac')) return Icons.laptop_mac;
    if (lower.contains('linux')) return Icons.computer;
    return Icons.devices;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: _loading ? null : _loadSessions,
            tooltip: AppLocalizations.of(context).refresh,
            visualDensity: VisualDensity.compact,
          ),
        ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_error != null)
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error!, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 12),
                FilledButton(onPressed: _loadSessions, child: Text(AppLocalizations.of(context).retry)),
              ],
            ),
          )
        else ...[
          if (_token != null) ...[
            if (widget.showSecurityLevel)
              SecurityLevelSection(serverBase: widget.serverBase, token: _token!),
            if (_hasPendingRecovery ||
                _sessions.any((s) => s['is_current'] == true && s['e2e_trusted'] != true))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: RecoveryBanner(serverBase: widget.serverBase, token: _token!),
              ),
            const SizedBox(height: 12),
          ],
          if (_sessions.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 8),
              child: Center(child: Text(AppLocalizations.of(context).noActiveSessionsFound)),
            )
          else
            for (final s in _sessions) ...[
              Builder(builder: (ctx) {
                final isCurrent = s['is_current'] == true;
                final isTrusted = s['e2e_trusted'] == true;
                final isPending = !isTrusted && !isCurrent;
                final approvals = s['approvals'] as int? ?? 0;
                final approvalsRequired = s['approvals_required'] as int? ?? 1;
                final id = s['id'] as int;
                final deviceName = s['device_name'] as String? ?? 'Unknown device';
                final deviceOs = s['device_os'] as String? ?? 'Unknown OS';
                final lastUsed = _formatDate(s['last_used_at'] as String?);
                return Card(
                  elevation: 0,
                  color: glassSurfaceColor(colorScheme),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                    side: BorderSide(
                      color: isPending
                          ? Colors.orange.withValues(alpha: 0.7)
                          : isCurrent
                              ? colorScheme.primary.withValues(alpha: 0.6)
                              : colorScheme.outlineVariant.withValues(alpha: 0.3),
                      width: isPending || isCurrent ? 1.5 : 1.0,
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: isPending
                          ? Colors.orange.withValues(alpha: 0.15)
                          : isCurrent
                              ? colorScheme.primaryContainer
                              : colorScheme.surfaceContainerHighest,
                      child: Icon(
                        _deviceIcon(deviceOs),
                        color: isPending
                            ? Colors.orange.shade700
                            : isCurrent
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant,
                      ),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            deviceName,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        if (isCurrent)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'This device',
                              style: TextStyle(
                                fontSize: 11,
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isPending)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 3),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.lock_clock, size: 12, color: Colors.orange.shade700),
                                const SizedBox(width: 4),
                                Text(
                                  approvalsRequired > 1
                                      ? 'Waiting for approval — ${AppLocalizations.of(context).approvalsProgress} $approvals/$approvalsRequired'
                                      : 'Waiting for approval',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.orange.shade700,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Text(
                          '$deviceOs • Last active: $lastUsed',
                          style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                    trailing: isCurrent
                        ? null
                        : isPending
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.check_circle_outline, color: Colors.green.shade600),
                                    tooltip: 'Approve device',
                                    onPressed: () => _approveSession(id),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.logout, color: Colors.red.shade400),
                                    tooltip: 'Revoke this session',
                                    onPressed: () => _revokeSession(id),
                                  ),
                                ],
                              )
                            : IconButton(
                                icon: Icon(Icons.logout, color: Colors.red.shade400),
                                tooltip: 'Revoke this session',
                                onPressed: () => _revokeSession(id),
                              ),
                  ),
                );
              }),
              const SizedBox(height: 8),
            ],
        ],
      ],
    );
  }
}

// --- Recovery banner: shown when THIS device is logged in but not yet
// trusted (waiting for approval) — offers the password+passphrase recovery
// path in case no trusted device is reachable to approve it normally.
class RecoveryBanner extends StatelessWidget {
  final String serverBase;
  final String token;

  const RecoveryBanner({super.key, required this.serverBase, required this.token});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.error.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.recoveryBannerText,
            style: TextStyle(fontSize: 13, color: colorScheme.onErrorContainer),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonal(
              onPressed: () {
                showRecoveryDialog(context, serverBase: serverBase, token: token);
              },
              child: Text(l10n.recoveryBannerButton),
            ),
          ),
        ],
      ),
    );
  }
}

// --- Device-trust settings: security level (easy/balanced/strict) and
// session TTL (14/30/90/180/365/730 days, or never). Independent settings —
// the security level only supplies a recommended TTL, never forces it.
class SecurityLevelSection extends StatefulWidget {
  final String serverBase;
  final String token;

  const SecurityLevelSection({
    super.key,
    required this.serverBase,
    required this.token,
  });

  @override
  State<SecurityLevelSection> createState() => _SecurityLevelSectionState();
}

class _SecurityLevelSectionState extends State<SecurityLevelSection> {
  bool _loading = true;
  String _level = 'balanced';
  int? _ttlDays = 30;
  int? _recommendedTtl;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await http.get(
        Uri.parse('${widget.serverBase}/me/security-settings'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      if (!mounted) return;
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _level = data['security_level'] as String? ?? 'balanced';
          _ttlDays = data['session_ttl_days'] as int?;
          _recommendedTtl = data['recommended_session_ttl_days'] as int?;
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openDialog() {
    showSecurityLevelDialog(
      context,
      serverBase: widget.serverBase,
      token: widget.token,
      level: _level,
      ttlDays: _ttlDays,
      recommendedTtl: _recommendedTtl,
      onLevelChanged: (newLevel) => setState(() {
        _level = newLevel;
        _recommendedTtl = const {
          'easy': 90,
          'balanced': 30,
          'strict': 14,
        }[newLevel];
      }),
      onTtlChanged: (newTtl) => setState(() => _ttlDays = newTtl),
    );
  }

  String _levelLabel(AppLocalizations l10n, String level) {
    switch (level) {
      case 'easy': return l10n.securityLevelEasy;
      case 'strict': return l10n.securityLevelStrict;
      default: return l10n.securityLevelBalanced;
    }
  }

  String _ttlLabel(AppLocalizations l10n, int? days) =>
      days == null ? l10n.sessionTtlNever : l10n.sessionTtlDays(days);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final summary = _ttlDays == _recommendedTtl
        ? '${_levelLabel(l10n, _level)} · ${_ttlLabel(l10n, _ttlDays)} — ${l10n.sessionTtlRecommended}'
        : '${_levelLabel(l10n, _level)} · ${_ttlLabel(l10n, _ttlDays)}';

    // No independent expand/collapse of its own: this section already lives
    // inside the "Active Devices" accordion in Settings, so a second nested
    // collapse control here was both redundant and, being a second AnimatedSize
    // stacked inside the outer one, the source of the visible jank when
    // opening/closing the outer section. Editing now happens in a dialog
    // (showSecurityLevelDialog) instead of inline, since the level cards'
    // full descriptions became unreadable once squeezed into this panel's
    // narrow width — the dialog gets a fixed, comfortable width instead.
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      decoration: BoxDecoration(
        color: glassSurfaceColor(cs),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.25)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: _openDialog,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.shield_outlined, size: 18, color: cs.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.securityLevelTitle,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      summary,
                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 20, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}