// lib/dialogs/profile_presets_dialog.dart
import 'dart:math';
import 'package:flutter/material.dart';
import '../globals.dart';
import '../managers/profile_preset_manager.dart';
import '../managers/settings_manager.dart';
import '../models/app_themes.dart';
import '../models/profile_preset.dart';
import '../widgets/adaptive_glass_card.dart';
import '../widgets/onyx_dialog.dart';
import '../l10n/app_localizations.dart';

/// Single modal for managing saved username/password presets used when
/// joining external group/channel servers — list, create, and edit all live
/// in one dialog (no separate screens), switching between a list view and
/// an inline editor view.
class ProfilePresetsDialog extends StatefulWidget {
  const ProfilePresetsDialog({super.key});

  @override
  State<ProfilePresetsDialog> createState() => _ProfilePresetsDialogState();
}

class _ProfilePresetsDialogState extends State<ProfilePresetsDialog> {
  bool _showForm = false;
  ProfilePreset? _editing;

  final _labelController = TextEditingController();
  final _noteController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  int _colorIndex = 0;
  bool _obscurePassword = true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _labelController.dispose();
    _noteController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _startCreate() {
    setState(() {
      _editing = null;
      _labelController.clear();
      _noteController.clear();
      _usernameController.clear();
      _passwordController.clear();
      _colorIndex = 0;
      _error = null;
      _showForm = true;
    });
  }

  void _startEdit(ProfilePreset preset) {
    setState(() {
      _editing = preset;
      _labelController.text = preset.label;
      _noteController.text = preset.note;
      _usernameController.text = preset.username;
      _passwordController.text = preset.password;
      _colorIndex = preset.colorIndex;
      _error = null;
      _showForm = true;
    });
  }

  String _generatePassword16() {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%&*()-_=+[]{};:,.<>?';
    final rnd = Random.secure();
    return String.fromCharCodes(
      Iterable.generate(16, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))),
    );
  }

  void _cancelForm() {
    setState(() {
      _showForm = false;
      _error = null;
    });
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    final label = _labelController.text.trim();
    if (label.isEmpty) {
      setState(() => _error = l.presetLabelRequired);
      return;
    }

    setState(() { _saving = true; _error = null; });

    final username = _usernameController.text.trim();
    final note = _noteController.text.trim();
    final password = _passwordController.text;

    if (_editing != null) {
      await ProfilePresetManager.updatePreset(_editing!.copyWith(
        label: label,
        colorIndex: _colorIndex,
        note: note,
        username: username,
        password: password,
      ));
    } else {
      await ProfilePresetManager.addPreset(
        label: label,
        colorIndex: _colorIndex,
        note: note,
        username: username,
        password: password,
      );
    }

    if (mounted) {
      setState(() { _saving = false; _showForm = false; });
      rootScreenKey.currentState?.showSnack(l.presetSaved);
    }
  }

  Future<void> _delete(ProfilePreset preset) async {
    final l = AppLocalizations.of(context);
    final confirmed = await showOnyxConfirmDialog(
      context: context,
      title: l.deletePreset,
      message: l.deletePresetConfirm(preset.label),
      confirmLabel: l.delete,
      isDestructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (confirmed == true) {
      await ProfilePresetManager.removePreset(preset.id);
      if (mounted) {
        rootScreenKey.currentState?.showSnack(l.presetDeleted);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);

    return OnyxDialogShell(
      maxWidth: 420,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.78,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OnyxDialogHeader(
              leading: _showForm
                  ? GestureDetector(
                      onTap: _cancelForm,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.arrow_back_rounded,
                            size: 20, color: colorScheme.primary),
                      ),
                    )
                  : Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.badge_outlined,
                          size: 20, color: colorScheme.primary),
                    ),
              title: Text(
                _showForm
                    ? (_editing != null ? l.editPreset : l.newPreset)
                    : l.profilePresets,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              subtitle: !_showForm
                  ? Text(
                      l.profilePresetsSubtitle,
                      style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurface.withValues(alpha: 0.6)),
                    )
                  : null,
              onClose: () => Navigator.of(context).pop(),
            ),
            Flexible(
              child: _showForm ? _buildForm(context) : _buildList(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);

    return ValueListenableBuilder<List<ProfilePreset>>(
      valueListenable: ProfilePresetManager.presets,
      builder: (context, presets, __) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: AdaptiveGlassCard(
                borderRadius: 22,
                padding: EdgeInsets.zero,
                onTap: _startCreate,
                child: Container(
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Icon(
                    Icons.add,
                    size: 20,
                    color: colorScheme.primary,
                  ),
                ),
              ),
            ),
            if (presets.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
                child: Column(
                  children: [
                    Icon(Icons.badge_outlined,
                        size: 40,
                        color: colorScheme.onSurface.withValues(alpha: 0.3)),
                    const SizedBox(height: 10),
                    Text(
                      l.noPresetsYet,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l.noPresetsYetSubtitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurface.withValues(alpha: 0.6)),
                    ),
                  ],
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  itemCount: presets.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final preset = presets[index];
                    final tagColor = AppTheme
                        .values[preset.colorIndex % AppTheme.values.length]
                        .color;
                    return InkWell(
                      borderRadius: BorderRadius.circular(28),
                      onTap: () => _startEdit(preset),
                      child: AdaptiveGlassCard(
                        borderRadius: 28,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 8, horizontal: 10),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: tagColor.withValues(alpha: 0.18),
                                child: Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: tagColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      preset.label,
                                      style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                          color: colorScheme.onSurface,
                                          fontSize: 15),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      preset.note.isNotEmpty
                                          ? '@${preset.username} · ${preset.note}'
                                          : '@${preset.username}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: colorScheme.onSurface
                                              .withValues(alpha: 0.6)),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.delete_outline,
                                    size: 20,
                                    color: colorScheme.onSurface
                                        .withValues(alpha: 0.5)),
                                onPressed: () => _delete(preset),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildForm(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _labelController,
            decoration: _fieldDecoration(
              context,
              labelText: l.presetLabel,
              hintText: l.presetLabelHint,
              icon: Icons.label_outline,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l.presetColor,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: List.generate(AppTheme.values.length, (i) {
              final theme = AppTheme.values[i];
              final isSelected = _colorIndex == i;
              return GestureDetector(
                onTap: () => setState(() => _colorIndex = i),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.color,
                    border: Border.all(
                      color: isSelected ? Colors.white : Colors.transparent,
                      width: isSelected ? 3 : 0,
                    ),
                    boxShadow: [
                      if (isSelected)
                        BoxShadow(
                          color: theme.color.withValues(alpha: 0.5),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                    ],
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _usernameController,
            decoration: _fieldDecoration(
              context,
              labelText: l.usernameLabel,
              icon: Icons.person_outline,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: _fieldDecoration(
              context,
              labelText: l.passwordLabel,
              icon: Icons.lock_outline,
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.vpn_key_outlined, size: 18),
                    tooltip: l.generatePasswordTooltip,
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                    onPressed: () =>
                        _passwordController.text = _generatePassword16(),
                  ),
                  IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                      size: 18,
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _noteController,
            maxLines: 2,
            decoration: _fieldDecoration(
              context,
              labelText: l.presetNote,
              hintText: l.presetNoteHint,
              icon: Icons.sticky_note_2_outlined,
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _error!,
                style: TextStyle(color: Colors.red.shade700, fontSize: 12),
              ),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              padding: kOnyxDialogButtonPadding,
              shape: kOnyxDialogButtonShape,
            ),
            icon: _saving
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check, size: 18),
            label: Text(l.save),
          ),
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration(
    BuildContext context, {
    required String labelText,
    String? hintText,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = SettingsManager.elementBrightness.value;
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      labelStyle: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.7)),
      prefixIcon: Icon(icon, color: colorScheme.onSurface.withValues(alpha: 0.6)),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: SettingsManager.getElementColor(
              colorScheme.surfaceContainerHighest, brightness)
          .withValues(alpha: 0.5),
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide:
            BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.15), width: 1.0),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide:
            BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.15), width: 1.0),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: BorderSide(color: colorScheme.primary, width: 1.4),
      ),
    );
  }
}
