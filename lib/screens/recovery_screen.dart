// lib/screens/recovery_screen.dart
//
// Self-service account recovery: reclaim primary/trusted status using the
// account password + the 12-word recovery phrase shown once at registration.
// Only reachable from a device that is logged in but NOT yet trusted (see
// active_sessions_screen.dart banner). The request does not execute
// immediately — see server-side src/jobs/recoveryExecutor.js for the delay
// and cancellation window.
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../l10n/app_localizations.dart';

class RecoveryScreen extends StatefulWidget {
  final String serverBase;
  final String token;

  const RecoveryScreen({
    super.key,
    required this.serverBase,
    required this.token,
  });

  @override
  State<RecoveryScreen> createState() => _RecoveryScreenState();
}

class _RecoveryScreenState extends State<RecoveryScreen> {
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

    return Scaffold(
      appBar: AppBar(title: Text(l10n.recoveryTitle)),
      body: _loadingStatus
          ? const Center(child: CircularProgressIndicator())
          : _status == 'pending'
              ? _buildPendingView(l10n, colorScheme)
              : _buildFormView(l10n, colorScheme),
    );
  }

  Widget _buildPendingView(AppLocalizations l10n, ColorScheme colorScheme) {
    final when = _executesAt != null ? _formatDateTime(_executesAt!) : '';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.hourglass_top_rounded, size: 56, color: colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              l10n.recoveryPendingTitle,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.recoveryPendingBody(when),
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _loadStatus,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.close),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormView(AppLocalizations l10n, ColorScheme colorScheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.recoveryIntro,
            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: l10n.recoveryPasswordLabel,
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _passphraseController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: l10n.recoveryPassphraseLabel,
              border: const OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 20, width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(l10n.recoverySubmit),
            ),
          ),
        ],
      ),
    );
  }
}
