// lib/screens/recovery_screen.dart
//
// Self-service account recovery: reclaim primary/trusted status using the
// account password + the 12-word recovery phrase shown once at registration.
// Only reachable from a device that is logged in but NOT yet trusted (see
// active_sessions_screen.dart banner). The request does not execute
// immediately — see server-side src/jobs/recoveryExecutor.js for the delay
// and cancellation window.
//
// Presented as a modal dialog (same chrome as showAboutOnyxDialog in
// widgets/about_onyx_dialog.dart) rather than a full screen, so it reads as
// a quick self-service action instead of a separate app section.
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../l10n/app_localizations.dart';

void showRecoveryDialog(
  BuildContext context, {
  required String serverBase,
  required String token,
}) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Recovery',
    barrierColor: Colors.black.withValues(alpha: 0.55),
    transitionDuration: const Duration(milliseconds: 187),
    transitionBuilder: (ctx, anim, _, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeIn),
        child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1.0).animate(curved),
            child: child),
      );
    },
    pageBuilder: (ctx, _, __) =>
        _RecoveryDialogContent(serverBase: serverBase, token: token),
  );
}

class _RecoveryDialogContent extends StatefulWidget {
  final String serverBase;
  final String token;

  const _RecoveryDialogContent({
    required this.serverBase,
    required this.token,
  });

  @override
  State<_RecoveryDialogContent> createState() => _RecoveryDialogContentState();
}

class _RecoveryDialogContentState extends State<_RecoveryDialogContent> {
  final _passwordController = TextEditingController();
  final _passphraseController = TextEditingController();
  bool _obscurePassword = true;
  bool _submitting = false;
  bool _loadingStatus = true;
  String? _error;

  // Pending-request state, once one exists (either just submitted or already
  // pending from an earlier session).
  String? _status; // none | pending | executed | cancelled
  DateTime? _executesAt;
  Timer? _pollTimer;
  bool _cancelling = false;
  String? _cancelError;

  static const _btnShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(50)),
  );
  static const _btnPadding = EdgeInsets.symmetric(vertical: 13);

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _passwordController.dispose();
    _passphraseController.dispose();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    try {
      final res = await http.get(
        Uri.parse('${widget.serverBase}/auth/recover-primary/status'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      ).timeout(const Duration(seconds: 8));
      if (!mounted) return;
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final status = data['status'] as String?;
        setState(() {
          _loadingStatus = false;
          if (status == 'pending') {
            _status = 'pending';
            final ea = data['executes_at'] as String?;
            _executesAt = ea != null ? DateTime.tryParse(ea)?.toLocal() : null;
            _startPolling();
          } else {
            _status = null; // no pending request — show the form
          }
        });
      } else {
        setState(() => _loadingStatus = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loadingStatus = false);
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      try {
        final res = await http.get(
          Uri.parse('${widget.serverBase}/auth/recover-primary/status'),
          headers: {'Authorization': 'Bearer ${widget.token}'},
        ).timeout(const Duration(seconds: 8));
        if (!mounted || res.statusCode != 200) return;
        final data = jsonDecode(res.body);
        final status = data['status'] as String?;
        if (status != 'pending') {
          setState(() => _status = status);
          _pollTimer?.cancel();
        }
      } catch (_) {}
    });
  }

  Future<void> _cancel() async {
    final l10n = AppLocalizations.of(context);
    setState(() { _cancelling = true; _cancelError = null; });
    try {
      final res = await http.post(
        Uri.parse('${widget.serverBase}/auth/recover-primary/cancel'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      ).timeout(const Duration(seconds: 15));
      if (!mounted) return;
      if (res.statusCode == 200) {
        _pollTimer?.cancel();
        setState(() {
          _cancelling = false;
          _status = 'cancelled';
        });
      } else if (res.statusCode == 403) {
        setState(() {
          _cancelling = false;
          _cancelError = l10n.recoveryCancelRequiresTrusted;
        });
      } else {
        setState(() { _cancelling = false; _cancelError = l10n.error; });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() { _cancelling = false; _cancelError = '$e'; });
    }
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final password = _passwordController.text;
    final passphrase = _passphraseController.text.trim();
    if (password.isEmpty || passphrase.isEmpty) return;

    setState(() { _submitting = true; _error = null; });
    try {
      final res = await http.post(
        Uri.parse('${widget.serverBase}/auth/recover-primary'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'password': password, 'passphrase': passphrase}),
      ).timeout(const Duration(seconds: 15));

      if (!mounted) return;

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final ea = data['executes_at'] as String?;
        setState(() {
          _submitting = false;
          _status = 'pending';
          _executesAt = ea != null ? DateTime.tryParse(ea)?.toLocal() : null;
        });
        _startPolling();
      } else if (res.statusCode == 409) {
        final data = jsonDecode(res.body);
        final ea = data['executes_at'] as String?;
        setState(() {
          _submitting = false;
          _error = l10n.recoveryAlreadyPending;
          _status = 'pending';
          _executesAt = ea != null ? DateTime.tryParse(ea)?.toLocal() : null;
        });
        _startPolling();
      } else if (res.statusCode == 401) {
        setState(() { _submitting = false; _error = l10n.recoveryInvalid; });
      } else {
        setState(() { _submitting = false; _error = l10n.error; });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() { _submitting = false; _error = '$e'; });
    }
  }

  String _formatDateTime(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Material(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Header ────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 20, 16, 16),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.06),
                    border: Border(
                      bottom: BorderSide(
                        color: colorScheme.primary.withValues(alpha: 0.10),
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
                          color: colorScheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.lock_reset_rounded,
                          color: colorScheme.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          l10n.recoveryTitle,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: colorScheme.onSurface.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: colorScheme.onSurface.withValues(alpha: 0.55),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Body ─────────────────────────────────────────────
                Flexible(
                  child: _loadingStatus
                      ? const Padding(
                          padding: EdgeInsets.all(40),
                          child: Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        )
                      : SingleChildScrollView(
                          child: _status == 'pending'
                              ? _buildPendingView(l10n, colorScheme)
                              : _buildFormView(l10n, colorScheme),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPendingView(AppLocalizations l10n, ColorScheme colorScheme) {
    final when = _executesAt != null ? _formatDateTime(_executesAt!) : '';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.hourglass_top_rounded, size: 48, color: colorScheme.primary),
          const SizedBox(height: 16),
          Text(
            l10n.recoveryPendingTitle,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.recoveryPendingBody(when),
            textAlign: TextAlign.center,
            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
          ),
          if (_cancelError != null) ...[
            const SizedBox(height: 12),
            Text(_cancelError!, style: TextStyle(color: colorScheme.error, fontSize: 13), textAlign: TextAlign.center),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _cancelling ? null : _cancel,
                  style: FilledButton.styleFrom(
                    padding: _btnPadding,
                    shape: _btnShape,
                    backgroundColor: colorScheme.error,
                    foregroundColor: colorScheme.onError,
                  ),
                  icon: _cancelling
                      ? SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.onError),
                        )
                      : const Icon(Icons.block_rounded, size: 18),
                  label: Text(l10n.recoveryAlertCancelButton),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  style: FilledButton.styleFrom(
                    padding: _btnPadding,
                    shape: _btnShape,
                    backgroundColor: colorScheme.primary.withValues(alpha: 0.16),
                    foregroundColor: colorScheme.primary,
                  ),
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: Text(l10n.close),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFormView(AppLocalizations l10n, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.recoveryIntro,
            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: l10n.recoveryPasswordLabel,
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passphraseController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: l10n.recoveryPassphraseLabel,
              alignLabelWithHint: true,
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: colorScheme.error, fontSize: 13)),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            style: FilledButton.styleFrom(
              padding: _btnPadding,
              shape: _btnShape,
            ),
            child: _submitting
                ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colorScheme.onPrimary,
                    ),
                  )
                : Text(l10n.recoverySubmit),
          ),
        ],
      ),
    );
  }
}
