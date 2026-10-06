// lib/widgets/identity_onboarding_dialog.dart
//
// Stage-2 onboarding for the decentralized identity model: create a brand
// new master identity (mnemonic + derived Ed25519 key, see MasterIdentity)
// or restore one from a previously-saved seed phrase. Styled as a modal
// using the same OnyxDialogShell/OnyxDialogHeader chrome as About ONYX,
// rather than a full-screen route.
//
// This dialog only exercises MasterIdentity itself — it does not yet wire
// the resulting accountId into AccountManager/the local DB (that's the
// Stage 3 migration).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../managers/account_manager.dart';
import '../managers/settings_manager.dart';
import '../services/identity/master_identity.dart';
import 'onyx_dialog.dart';

Future<void> showIdentityOnboardingDialog(
  BuildContext context, {
  Future<void> Function(String accountId)? onSwitchAccount,
}) {
  return showOnyxDialog<void>(
    context: context,
    barrierLabel: 'Identity',
    builder: (ctx) => _IdentityOnboardingContent(onSwitchAccount: onSwitchAccount),
  );
}

/// The "?" explanation dialog next to the New Identity button — plain
/// single-button info dialog, same chrome as every other ONYX info popup.
Future<void> showIdentityInfoDialog(BuildContext context) {
  final l = AppLocalizations.of(context);
  return showOnyxInfoDialog(
    context: context,
    title: l.identityInfoTitle,
    message: l.identityInfoBody,
    icon: Icons.vpn_key_outlined,
  );
}

/// Matches the floating-pill snackbar style used elsewhere in the app
/// (RootScreen._presentSnack) instead of the default Material SnackBar.
void _showIdentitySnack(BuildContext context, String text) {
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      margin: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
      elevation: 4,
      duration: const Duration(seconds: 2),
    ),
  );
}

enum _Mode { choose, showMnemonic, restore, setup, done }

class _IdentityOnboardingContent extends StatefulWidget {
  final Future<void> Function(String accountId)? onSwitchAccount;

  const _IdentityOnboardingContent({this.onSwitchAccount});

  @override
  State<_IdentityOnboardingContent> createState() =>
      _IdentityOnboardingContentState();
}

class _IdentityOnboardingContentState
    extends State<_IdentityOnboardingContent> {
  _Mode _mode = _Mode.choose;
  String? _mnemonic;
  bool _savedConfirmed = false;
  String? _error;
  bool _busy = false;
  final _restoreController = TextEditingController();
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _restoreController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _createNew() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final mnemonic = await MasterIdentity.createNew();
      setState(() {
        _mnemonic = mnemonic;
        _mode = _Mode.showMnemonic;
      });
    } catch (e) {
      if (!mounted) return;
      final l = AppLocalizations.of(context);
      setState(() => _error = '${l.identityErrorCreatePrefix}: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final l = AppLocalizations.of(context);
    try {
      await MasterIdentity.restoreFromMnemonic(_restoreController.text);
      final cached =
          await AccountManager.getCachedDisplayName(MasterIdentity.accountId);
      if (cached != null) _nameController.text = cached;
      setState(() => _mode = _Mode.setup);
    } on FormatException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = '${l.identityErrorRestorePrefix}: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Registers the identity as a real, switchable local account -- the
  /// decentralized equivalent of what used to be server registration.
  /// Slots MasterIdentity.accountId into AccountManager's existing
  /// multi-account list (keyed by plain strings, so a crypto id works as a
  /// drop-in "username" for now) and makes it the active account.
  Future<void> _setupAccount() async {
    final accountId = MasterIdentity.accountId;
    final name = _nameController.text.trim();
    setState(() => _busy = true);
    try {
      await AccountManager.addAccount(accountId);
      if (name.isNotEmpty) {
        await AccountManager.cacheDisplayName(accountId, name);
      }
      // Go through the app's real account-switch pipeline when available
      // (reconnects/restarts WardLink, Onion Mode's hidden service scoped
      // to this account, chats, etc.) instead of just flipping the stored
      // "current account" pointer -- a bare setCurrentAccount left the old
      // account's onion identity (and stale display name) showing everywhere.
      final onSwitch = widget.onSwitchAccount;
      if (onSwitch != null) {
        await onSwitch(accountId);
      } else {
        await AccountManager.setCurrentAccount(accountId);
      }
      if (mounted) setState(() => _mode = _Mode.done);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    return OnyxDialogShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OnyxDialogHeader(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.vpn_key_outlined,
                  size: 20, color: colorScheme.primary),
            ),
            title: Text(
              _titleFor(l, _mode),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            onClose: () => Navigator.of(context).pop(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: _buildBody(context, l),
          ),
        ],
      ),
    );
  }

  String _titleFor(AppLocalizations l, _Mode mode) {
    switch (mode) {
      case _Mode.choose:
        return l.identityTitleChoose;
      case _Mode.showMnemonic:
        return l.identityTitleMnemonic;
      case _Mode.restore:
        return l.identityTitleRestore;
      case _Mode.setup:
        return l.identityTitleSetup;
      case _Mode.done:
        return l.identityTitleDone;
    }
  }

  Widget _buildBody(BuildContext context, AppLocalizations l) {
    switch (_mode) {
      case _Mode.choose:
        return _buildChoose(context, l);
      case _Mode.showMnemonic:
        return _buildShowMnemonic(context, l);
      case _Mode.restore:
        return _buildRestore(context, l);
      case _Mode.setup:
        return _buildSetup(context, l);
      case _Mode.done:
        return _buildDone(context, l);
    }
  }

  Widget _buildSetup(BuildContext context, AppLocalizations l) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l.identityDisplayNameLabel,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 8),
        // Same pill-shaped field as the Edit Profile dialog (accounts_tab's
        // _showEditProfileDialog) -- one visual language for "set your name"
        // wherever it appears.
        ValueListenableBuilder<double>(
          valueListenable: SettingsManager.elementBrightness,
          builder: (_, brightness, __) {
            final baseColor =
                SettingsManager.getElementColor(cs.surfaceContainerHighest, brightness);
            return TextField(
              controller: _nameController,
              autofocus: true,
              decoration: InputDecoration(
                filled: true,
                fillColor: baseColor.withValues(alpha: 0.5),
                hintText: l.identityDisplayNameHint,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(28)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide:
                      BorderSide(color: cs.outlineVariant.withValues(alpha: 0.3), width: 0.8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide(color: cs.primary, width: 1.4),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        FilledButton(
          style: FilledButton.styleFrom(
            padding: kOnyxDialogButtonPadding,
            shape: kOnyxDialogButtonShape,
          ),
          onPressed: _busy ? null : _setupAccount,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l.identityCreateAccountButton),
        ),
      ],
    );
  }

  Widget _buildChoose(BuildContext context, AppLocalizations l) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l.identityChooseSubtitle),
        const SizedBox(height: 20),
        if (_error != null) ...[
          Text(_error!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 12),
        ],
        FilledButton(
          style: FilledButton.styleFrom(
            padding: kOnyxDialogButtonPadding,
            shape: kOnyxDialogButtonShape,
          ),
          onPressed: _busy ? null : _createNew,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l.identityCreateNewButton),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            padding: kOnyxDialogButtonPadding,
            shape: kOnyxDialogButtonShape,
          ),
          onPressed: _busy
              ? null
              : () => setState(() {
                    _mode = _Mode.restore;
                    _error = null;
                  }),
          child: Text(l.identityRestoreLinkButton),
        ),
      ],
    );
  }

  Widget _buildShowMnemonic(BuildContext context, AppLocalizations l) {
    final colorScheme = Theme.of(context).colorScheme;
    final words = _mnemonic!.split(' ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l.identityMnemonicIntro),
        const SizedBox(height: 4),
        Text(
          l.identityMnemonicRestoreNote,
          style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.6)),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.3),
              width: 0.8,
            ),
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < words.length; i++)
                Chip(
                  label: Text('${i + 1}. ${words[i]}'),
                  shape: const StadiumBorder(),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        TextButton.icon(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: _mnemonic!));
            _showIdentitySnack(context, l.identityCopiedSnack);
          },
          icon: const Icon(Icons.copy, size: 16),
          label: Text(l.identityCopyButton),
        ),
        const SizedBox(height: 8),
        CheckboxListTile(
          value: _savedConfirmed,
          onChanged: (v) => setState(() => _savedConfirmed = v ?? false),
          title: Text(
            l.identitySavedConfirm,
            style: const TextStyle(fontSize: 13),
          ),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),
        const SizedBox(height: 4),
        FilledButton(
          style: FilledButton.styleFrom(
            padding: kOnyxDialogButtonPadding,
            shape: kOnyxDialogButtonShape,
          ),
          onPressed: _savedConfirmed
              ? () => setState(() => _mode = _Mode.setup)
              : null,
          child: Text(l.identityContinueButton),
        ),
      ],
    );
  }

  Widget _buildRestore(BuildContext context, AppLocalizations l) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l.identityRestoreHint),
        const SizedBox(height: 16),
        // Same filled, rounded field as the display-name field / Edit Profile
        // dialog; multi-line since a seed phrase is 12-24 words.
        ValueListenableBuilder<double>(
          valueListenable: SettingsManager.elementBrightness,
          builder: (_, brightness, __) {
            final cs = Theme.of(context).colorScheme;
            final baseColor =
                SettingsManager.getElementColor(cs.surfaceContainerHighest, brightness);
            return TextField(
              controller: _restoreController,
              autofocus: true,
              minLines: 3,
              maxLines: 5,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              autocorrect: false,
              enableSuggestions: false,
              enableInteractiveSelection: true,
              style: const TextStyle(fontSize: 14, height: 1.4),
              decoration: InputDecoration(
                filled: true,
                fillColor: baseColor.withValues(alpha: 0.5),
                hintText: 'word1 word2 word3 ...',
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                suffixIcon: IconButton(
                  tooltip: 'Paste',
                  icon: const Icon(Icons.content_paste, size: 18),
                  onPressed: () async {
                    final data = await Clipboard.getData(Clipboard.kTextPlain);
                    final text = data?.text;
                    if (text != null && text.isNotEmpty) {
                      _restoreController.text = text.trim();
                      _restoreController.selection = TextSelection.collapsed(
                          offset: _restoreController.text.length);
                    }
                  },
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(22)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide(
                      color: cs.outlineVariant.withValues(alpha: 0.3), width: 0.8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide(color: cs.primary, width: 1.4),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        if (_error != null) ...[
          Text(_error!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 12),
        ],
        FilledButton(
          style: FilledButton.styleFrom(
            padding: kOnyxDialogButtonPadding,
            shape: kOnyxDialogButtonShape,
          ),
          onPressed: _busy ? null : _restore,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l.identityRestoreButton),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            padding: kOnyxDialogButtonPadding,
            shape: kOnyxDialogButtonShape,
          ),
          onPressed: _busy
              ? null
              : () => setState(() {
                    _mode = _Mode.choose;
                    _error = null;
                  }),
          child: Text(l.identityBackButton),
        ),
      ],
    );
  }

  Widget _buildDone(BuildContext context, AppLocalizations l) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _infoRow(l.identityAccountIdLabel, MasterIdentity.accountId,
            l.identityAccountIdExplain),
        const SizedBox(height: 14),
        _infoRow(l.identityFingerprintLabel, MasterIdentity.fingerprint,
            l.identityFingerprintExplain),
        const SizedBox(height: 20),
        FilledButton(
          style: FilledButton.styleFrom(
            padding: kOnyxDialogButtonPadding,
            shape: kOnyxDialogButtonShape,
          ),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.identityDoneButton),
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value, String explain) {
    return Builder(builder: (context) {
      final colorScheme = Theme.of(context).colorScheme;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 2),
          SelectableText(value,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            explain,
            style: TextStyle(
              fontSize: 11.5,
              color: colorScheme.onSurface.withValues(alpha: 0.55),
            ),
          ),
        ],
      );
    });
  }
}
