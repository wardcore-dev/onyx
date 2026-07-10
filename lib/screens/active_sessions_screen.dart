// lib/screens/active_sessions_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../managers/account_manager.dart';
import '../managers/settings_manager.dart';
import '../l10n/app_localizations.dart';
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

  const ActiveDevicesPanel({
    super.key,
    required this.serverBase,
    this.username,
  });

  @override
  State<ActiveDevicesPanel> createState() => _ActiveDevicesPanelState();
}

class _ActiveDevicesPanelState extends State<ActiveDevicesPanel> {
  List<Map<String, dynamic>> _sessions = [];
  bool _loading = true;
  String? _error;
  String? _token;

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
      } else {
        setState(() { _error = 'Failed to load sessions (${res.statusCode})'; _loading = false; });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = 'Network error: $e'; _loading = false; });
    }
  }

  Future<void> _revokeSession(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Revoke session?'),
        content: const Text('This device will be immediately logged out.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Revoke', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
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
          const SnackBar(content: Text('Failed to revoke session')),
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
          const SnackBar(content: Text('Failed to approve device')),
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
            tooltip: 'Refresh',
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
                FilledButton(onPressed: _loadSessions, child: const Text('Retry')),
              ],
            ),
          )
        else ...[
          if (_token != null) ...[
            SecurityLevelSection(serverBase: widget.serverBase, token: _token!),
            if (_sessions.any((s) => s['is_current'] == true && s['e2e_trusted'] != true))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: RecoveryBanner(serverBase: widget.serverBase, token: _token!),
              ),
            const SizedBox(height: 12),
          ],
          if (_sessions.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8, bottom: 8),
              child: Center(child: Text('No active sessions found')),
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
                    borderRadius: BorderRadius.circular(14),
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
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => RecoveryScreen(serverBase: serverBase, token: token),
                ));
              },
              child: Text(l10n.recoveryBannerButton),
            ),
          ),
        ],
      ),
    );
  }
}

// Box for the TTL bottom sheet's result: lets `null` days ("Never") be told
// apart from a dismissed sheet (which also resolves the future to `null`).
class _TtlPick {
  final int? days;
  const _TtlPick(this.days);
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
  static const List<int?> _ttlOptions = [14, 30, 90, 180, 365, 730, null];

  bool _loading = true;
  bool _saving = false;
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

  Future<void> _save(Map<String, dynamic> body, {required VoidCallback onSuccess, required VoidCallback onRevert}) async {
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

  void _onLevelChanged(String? newLevel) {
    if (newLevel == null || newLevel == _level) return;
    final previous = _level;
    setState(() => _level = newLevel);
    _save(
      {'security_level': newLevel},
      onSuccess: () {
        final l10n = AppLocalizations.of(context);
        setState(() => _recommendedTtl = {
              'easy': 90,
              'balanced': 30,
              'strict': 14,
            }[newLevel]);
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
        showStyledSnack(context, l10n.sessionTtlUpdated);
      },
      onRevert: () => setState(() => _ttlDays = previous),
    );
  }

  String _levelLabel(AppLocalizations l10n, String level) {
    switch (level) {
      case 'easy': return l10n.securityLevelEasy;
      case 'strict': return l10n.securityLevelStrict;
      default: return l10n.securityLevelBalanced;
    }
  }

  String _levelDesc(AppLocalizations l10n, String level) {
    switch (level) {
      case 'easy': return l10n.securityLevelEasyDesc;
      case 'strict': return l10n.securityLevelStrictDesc;
      default: return l10n.securityLevelBalancedDesc;
    }
  }

  String _ttlLabel(AppLocalizations l10n, int? days) =>
      days == null ? l10n.sessionTtlNever : l10n.sessionTtlDays(days);

  Future<void> _openTtlPicker() async {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    // Wrapped in a box so a dismissed sheet (Navigator pop with no result,
    // e.g. tap-outside or swipe-down) is distinguishable from the user
    // explicitly picking "Never" (opt == null) — both would otherwise read
    // as `null` and silently set the session lifetime to Never.
    final selectedBox = await showModalBottomSheet<_TtlPick>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: glassSurfaceColor(cs),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36, height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(color: cs.onSurfaceVariant.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(l10n.sessionTtlTitle, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                ),
              ),
              const SizedBox(height: 6),
              ..._ttlOptions.map((opt) {
                final isRecommended = opt == _recommendedTtl;
                final isSelected = opt == _ttlDays;
                return ListTile(
                  onTap: () => Navigator.of(ctx).pop(_TtlPick(opt)),
                  title: Text(_ttlLabel(l10n, opt), style: TextStyle(fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400)),
                  trailing: isSelected
                      ? Icon(Icons.check_rounded, color: cs.primary)
                      : isRecommended
                          ? Text(l10n.sessionTtlRecommended, style: TextStyle(fontSize: 11, color: cs.primary))
                          : null,
                );
              }),
            ],
          ),
        ),
      ),
    );
    if (selectedBox != null && selectedBox.days != _ttlDays) {
      _onTtlChanged(selectedBox.days);
    }
  }

  Widget _levelRow(AppLocalizations l10n, ColorScheme cs, String level) {
    final selected = level == _level;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: _saving ? null : () => _onLevelChanged(level),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: selected ? cs.primary.withValues(alpha: 0.12) : Colors.transparent,
          border: Border.all(color: selected ? cs.primary.withValues(alpha: 0.5) : cs.outlineVariant.withValues(alpha: 0.25)),
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
                  Text(_levelLabel(l10n, level), style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(_levelDesc(l10n, level), style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                ],
              ),
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

    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    // No independent expand/collapse of its own: this section already lives
    // inside the "Active Devices" accordion in Settings, so a second nested
    // collapse control here was both redundant and, being a second AnimatedSize
    // stacked inside the outer one, the source of the visible jank when
    // opening/closing the outer section.
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: glassSurfaceColor(cs),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                    if (_saving)
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: SizedBox(height: 12, width: 12, child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    else
                      Text(
                        _levelLabel(l10n, _level),
                        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant, fontWeight: FontWeight.w600),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...['easy', 'balanced', 'strict'].map((level) => _levelRow(l10n, cs, level)),
          const SizedBox(height: 4),
          Container(height: 1, color: cs.outlineVariant.withValues(alpha: 0.2)),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.timer_outlined, size: 16, color: cs.primary),
              const SizedBox(width: 8),
              Text(l10n.sessionTtlTitle, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 4),
          Text(l10n.sessionTtlSubtitle, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          const SizedBox(height: 10),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _saving ? null : _openTtlPicker,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _ttlOptions.contains(_ttlDays)
                          ? (_ttlDays == _recommendedTtl
                              ? '${_ttlLabel(l10n, _ttlDays)} — ${l10n.sessionTtlRecommended}'
                              : _ttlLabel(l10n, _ttlDays))
                          : _ttlLabel(l10n, _ttlDays),
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                  Icon(Icons.unfold_more_rounded, size: 18, color: cs.onSurfaceVariant),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}