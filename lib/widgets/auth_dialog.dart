// lib/widgets/auth_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'dart:async';
import 'package:window_manager/window_manager.dart';
import '../managers/settings_manager.dart';
import '../l10n/app_localizations.dart';
import '../managers/secure_store.dart';

final _usernameFormatter = FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_.\-]'));
bool _isValidUsername(String u) =>
    u.length >= 3 && u.length <= 16 && RegExp(r'^[a-zA-Z0-9_.\-]+$').hasMatch(u);

class AuthDialog extends StatefulWidget {
  final Future<bool> Function(String, String) onLogin;
  
  final Future<String?> Function(String, String) onRegister;

  const AuthDialog({super.key, required this.onLogin, required this.onRegister});

  @override
  State<AuthDialog> createState() => AuthDialogState();
}

class AuthDialogState extends State<AuthDialog> {
  final TextEditingController _userCtrl = TextEditingController();
  final TextEditingController _passCtrl = TextEditingController();
  bool _obscure = true;

  String _generatePassword16() {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%&*()-_=+[]{};:,.<>?';
    final rnd = Random.secure();
    return String.fromCharCodes(
      Iterable.generate(16, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))),
    );
  }

  void _showSnack(String text) {
    if (!mounted) return;
    final colorScheme = Theme.of(context).colorScheme;
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
        backgroundColor: colorScheme.surfaceContainerHighest.withValues(
          alpha: SettingsManager.elementOpacity.value,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        elevation: 4,
        margin: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _showPassphraseDialog(String username, String passphrase) async {
    if (!mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _PassphraseDialog(
        passphrase: passphrase,
        onConfirmed: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 700;
    final colorScheme = Theme.of(context).colorScheme;

    InputDecoration glassInputDecoration({
      required String labelText,
      Widget? prefixIcon,
      Widget? suffixIcon,
      required Color surfaceHighestColor,
    }) {
      return InputDecoration(
        labelText: labelText,
        labelStyle: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.7)),
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: surfaceHighestColor.withValues(alpha: 0.5),
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.15),
            width: 1.0,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.15),
            width: 1.0,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.4),
        ),
      );
    }

    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 16.0 + keyboardInset),
        child: Center(
          child: SingleChildScrollView(
            child: ValueListenableBuilder<double>(
            valueListenable: SettingsManager.elementOpacity,
            builder: (_, elemOpacity, __) {
              return ValueListenableBuilder<double>(
                valueListenable: SettingsManager.elementBrightness,
                builder: (_, brightness, ___) {
                  final surfaceHighestColor = SettingsManager.getElementColor(
                    colorScheme.surfaceContainerHighest,
                    brightness,
                  );
                  final l = AppLocalizations(SettingsManager.appLocale.value);
                  return Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: isDesktop ? 400 : double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: surfaceHighestColor.withValues(alpha: elemOpacity),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: colorScheme.outlineVariant.withValues(alpha: 0.15),
                          width: 1.0,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isDesktop)
                            GestureDetector(
                              onPanStart: (details) => windowManager.startDragging(),
                              child: Container(
                                height: 24,
                                alignment: Alignment.center,
                                child: Text(
                                  l.addAccount,
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                ),
                              ),
                            )
                          else
                            Container(
                              height: 56,
                              alignment: Alignment.center,
                              child: Text(
                                l.addAccount,
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                            ),

                          if (isDesktop) const SizedBox(height: 16),
                          TextField(
                            controller: _userCtrl,
                            style: TextStyle(color: colorScheme.onSurface),
                            maxLength: 16,
                            inputFormatters: [_usernameFormatter],
                            decoration: glassInputDecoration(
                              labelText: l.authUsernameLabel,
                              prefixIcon: Icon(
                                Icons.person_outline,
                                color: colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                              surfaceHighestColor: surfaceHighestColor,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _passCtrl,
                            obscureText: _obscure,
                            style: TextStyle(color: colorScheme.onSurface),
                            decoration: glassInputDecoration(
                              labelText: l.authPasswordLabel,
                              prefixIcon: Icon(
                                Icons.lock_outline,
                                color: colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                              surfaceHighestColor: surfaceHighestColor,
                              suffixIcon: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.vpn_key_outlined, size: 18),
                                    onPressed: () => _passCtrl.text = _generatePassword16(),
                                    tooltip: l.generatePasswordTooltip,
                                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      _obscure ? Icons.visibility_off : Icons.visibility,
                                      size: 18,
                                    ),
                                    onPressed: () => setState(() => _obscure = !_obscure),
                                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            children: [
                              FilledButton.icon(
                                onPressed: () async {
                                  final u = _userCtrl.text.trim();
                                  final p = _passCtrl.text;
                                  if (u.isEmpty) {
                                    _showSnack(l.enterUsernameMsg);
                                    return;
                                  }
                                  final nav = Navigator.of(context);
                                  if (await widget.onLogin(u, p)) {
                                    if (!mounted) return;
                                    _showSnack(l.loginSuccess);
                                    nav.pop();
                                  } else {
                                    _showSnack(l.loginFailed);
                                  }
                                },
                                icon: const Icon(Icons.login, size: 18),
                                label: Text(l.loginBtn),
                              ),

                              FilledButton.icon(
                                onPressed: () async {
                                  final u = _userCtrl.text.trim();
                                  final p = _passCtrl.text;
                                  if (!_isValidUsername(u)) {
                                    _showSnack(l.usernameInvalidMsg);
                                    return;
                                  }
                                  if (p.length < 16) {
                                    _showSnack(l.passwordTooShortMsg);
                                    return;
                                  }
                                  _showSnack(l.registeringMsg);
                                  final passphrase = await widget.onRegister(u, p);
                                  if (!mounted) return;
                                  if (passphrase != null) {
                                    
                                    await SecureStore.write('passphrase_$u', passphrase);
                                    await SecureStore.write('is_primary_device_$u', 'true');
                                    
                                    await _showPassphraseDialog(u, passphrase);
                                    if (!mounted) return;
                                    
                                    if (await widget.onLogin(u, p)) {
                                      if (mounted) Navigator.of(context).pop();
                                    }
                                  } else {
                                    _showSnack(l.registrationFailed);
                                  }
                                },
                                icon: const Icon(Icons.app_registration, size: 18),
                                label: Text(l.registerBtn),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        ),
      ),
    );
  }
}

class _PassphraseDialog extends StatefulWidget {
  final String passphrase;
  final VoidCallback onConfirmed;

  const _PassphraseDialog({required this.passphrase, required this.onConfirmed});

  @override
  State<_PassphraseDialog> createState() => _PassphraseDialogState();
}

class _PassphraseDialogState extends State<_PassphraseDialog> {
  int _countdown = 10;
  bool _copied = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        if (_countdown > 0) _countdown--;
        if (_countdown == 0) t.cancel();
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _copy() {
    Clipboard.setData(ClipboardData(text: widget.passphrase));
    setState(() => _copied = true);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final words = widget.passphrase.split(' ');

    final l = AppLocalizations(SettingsManager.appLocale.value);
    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: Row(
          children: [
            Icon(Icons.key, color: colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(l.yourPassphraseTitle, style: const TextStyle(fontSize: 16)),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.passphraseWriteDown,
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.edit_note_rounded, color: Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l.passphraseWriteOnPaper,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: words.asMap().entries.map((e) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${e.key + 1}. ${e.value}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _copy,
                icon: Icon(_copied ? Icons.check : Icons.copy, size: 16),
                label: Text(_copied ? l.copiedToClipboard : l.copyToClipboard),
              ),
              const SizedBox(height: 12),
              if (_countdown > 0)
                Text(
                  l.passphraseCountdown(_countdown),
                  style: const TextStyle(fontSize: 12, color: Colors.orange),
                )
              else
                FilledButton.icon(
                  onPressed: widget.onConfirmed,
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: Text(l.iSavedIt),
                ),
            ],
          ),
        ),
      ),
    );
  }
}