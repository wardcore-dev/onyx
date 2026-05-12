// lib/screens/decoy_setup_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../managers/decoy_manager.dart';
import '../managers/decoy_data_manager.dart';
import '../managers/settings_manager.dart';
import '../models/group.dart';
import '../models/favorite_chat.dart';
import '../l10n/app_localizations.dart';
import 'pin_code_screen.dart';

Future<void> showDecoySetupSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const _DecoySetupSheet(),
  );
}

class _DecoySetupSheet extends StatefulWidget {
  const _DecoySetupSheet();

  @override
  State<_DecoySetupSheet> createState() => _DecoySetupSheetState();
}

class _DecoySetupSheetState extends State<_DecoySetupSheet> {
  bool _enabled = false;
  bool _loading = true;
  bool _saving = false;
  bool _generating = false;

  late TextEditingController _usernameCtrl;
  late TextEditingController _displayNameCtrl;
  String? _avatarPath;

  List<DecoyContact> _contacts = [];
  List<Group> _fakeGroups = [];
  List<FavoriteChat> _fakeFavorites = [];

  @override
  void initState() {
    super.initState();
    _usernameCtrl = TextEditingController();
    _displayNameCtrl = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _displayNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final enabled = await DecoyManager.isEnabled();
    await DecoyManager.loadConfig();
    await DecoyDataManager.load();
    if (mounted) {
      setState(() {
        _enabled = enabled;
        _usernameCtrl.text = DecoyManager.username;
        _displayNameCtrl.text = DecoyManager.displayName;
        _avatarPath = DecoyManager.avatarPath;
        _contacts = List.of(DecoyDataManager.contacts);
        _fakeGroups = List.of(DecoyDataManager.fakeGroups);
        _fakeFavorites = List.of(DecoyDataManager.fakeFavorites);
        _loading = false;
      });
    }
  }

  // ── Chats ──────────────────────────────────────────────────────────────────
  Future<void> _addChat() async {
    final l = AppLocalizations.of(context);
    final nameCtrl = TextEditingController();
    final userCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.addDecoyContact),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(labelText: l.decoyContactDisplayName),
              textCapitalization: TextCapitalization.words,
              autofocus: true,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: userCtrl,
              decoration: InputDecoration(
                labelText: l.decoyContactUsername,
                hintText: l.decoyUsernameHint,
                prefixText: '@',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.add)),
        ],
      ),
    );

    final displayName = nameCtrl.text.trim();
    String username = userCtrl.text
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_]'), '_');
    nameCtrl.dispose();
    userCtrl.dispose();

    if (confirmed != true || displayName.isEmpty) return;
    if (username.isEmpty) {
      username = 'user_${DateTime.now().millisecondsSinceEpoch % 10000}';
    }
    if (_contacts.any((c) => c.username == username)) {
      if (mounted) _showSnack(l.decoyContactExists);
      return;
    }

    await DecoyDataManager.addContact(username: username, displayName: displayName);
    if (mounted) setState(() => _contacts = List.of(DecoyDataManager.contacts));
  }

  Future<void> _removeChat(String username) async {
    await DecoyDataManager.removeContact(username);
    if (mounted) setState(() => _contacts = List.of(DecoyDataManager.contacts));
  }

  // ── Groups ─────────────────────────────────────────────────────────────────
  Future<void> _addGroup(bool isChannel) async {
    final l = AppLocalizations.of(context);
    final nameCtrl = TextEditingController();

    final label = isChannel ? l.addFakeChannel : l.addFakeGroup;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${l.add} $label'),
        content: TextField(
          controller: nameCtrl,
          decoration: InputDecoration(labelText: l.groupNameHint),
          textCapitalization: TextCapitalization.sentences,
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.add)),
        ],
      ),
    );

    final name = nameCtrl.text.trim();
    nameCtrl.dispose();
    if (confirmed != true || name.isEmpty) return;

    await DecoyDataManager.addGroup(name: name, isChannel: isChannel);
    if (mounted) setState(() => _fakeGroups = List.of(DecoyDataManager.fakeGroups));
  }

  Future<void> _removeGroup(int id) async {
    await DecoyDataManager.removeGroup(id);
    if (mounted) setState(() => _fakeGroups = List.of(DecoyDataManager.fakeGroups));
  }

  // ── Favorites ──────────────────────────────────────────────────────────────
  Future<void> _addFavorite() async {
    final l = AppLocalizations.of(context);
    final titleCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.addFakeFavorite),
        content: TextField(
          controller: titleCtrl,
          decoration: InputDecoration(labelText: l.favTitleHint),
          textCapitalization: TextCapitalization.sentences,
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.add)),
        ],
      ),
    );

    final title = titleCtrl.text.trim();
    titleCtrl.dispose();
    if (confirmed != true || title.isEmpty) return;

    await DecoyDataManager.addFavorite(title: title);
    if (mounted) setState(() => _fakeFavorites = List.of(DecoyDataManager.fakeFavorites));
  }

  Future<void> _removeFavorite(String id) async {
    await DecoyDataManager.removeFavorite(id);
    if (mounted) setState(() => _fakeFavorites = List.of(DecoyDataManager.fakeFavorites));
  }

  // ── Generate all ───────────────────────────────────────────────────────────
  Future<void> _generateAll() async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.generateAll),
        content: Text(l.generateAllConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.generateAll)),
        ],
      ),
    );
    if (confirmed != true) return;

    final ownerUsername = _usernameCtrl.text.trim().isNotEmpty
        ? _usernameCtrl.text.trim()
        : 'user';
    setState(() => _generating = true);
    await DecoyDataManager.generateAll(ownerUsername: ownerUsername);
    if (mounted) {
      setState(() {
        _contacts = List.of(DecoyDataManager.contacts);
        _fakeGroups = List.of(DecoyDataManager.fakeGroups);
        _fakeFavorites = List.of(DecoyDataManager.fakeFavorites);
        _generating = false;
      });
    }
  }

  // ── Account ────────────────────────────────────────────────────────────────
  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    final username = _usernameCtrl.text.trim();
    final displayName = _displayNameCtrl.text.trim();
    if (username.isEmpty || displayName.isEmpty) {
      _showSnack(l.decoyFieldsRequired);
      return;
    }
    setState(() => _saving = true);
    await DecoyManager.saveConfig(
      newUsername: username,
      newDisplayName: displayName,
      newAvatarPath: _avatarPath,
    );
    if (mounted) {
      setState(() => _saving = false);
      _showSnack(l.decoyAccountSaved);
    }
  }

  // ── PIN ────────────────────────────────────────────────────────────────────
  Future<void> _enableFakePin() async {
    final l = AppLocalizations.of(context);
    final realPin = await SettingsManager.getPin();
    if (!mounted) return;
    final nav = Navigator.of(context);

    final fakePin = await nav.push<String>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (ctx) => PinCodeScreen.setup(
          onPinSet: (pin) => Navigator.pop(ctx, pin),
          onCancel: () => Navigator.pop(ctx),
        ),
      ),
    );

    if (fakePin == null || fakePin.length != 4) return;
    if (fakePin == realPin) {
      if (mounted) _showSnack(l.fakePinCannotMatchReal);
      return;
    }
    await DecoyManager.setPin(fakePin);
    await DecoyManager.setEnabled(true);
    if (mounted) {
      setState(() => _enabled = true);
      _showSnack(l.fakePinEnabledSnack);
    }
  }

  Future<void> _disableFakePin() async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.disableFakePinTitle),
        content: Text(l.disableFakePinContent),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.disableFakePin)),
        ],
      ),
    );
    if (confirmed != true) return;
    await DecoyManager.disable();
    if (mounted) {
      setState(() => _enabled = false);
      _showSnack(l.fakePinDisabledSnack);
    }
  }

  // ── Avatar ─────────────────────────────────────────────────────────────────
  Future<void> _pickAvatar() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final srcPath = result.files.first.path;
    if (srcPath == null) return;

    final dir = await getApplicationDocumentsDirectory();
    final dest = p.join(dir.path, 'decoy_avatar.jpg');
    await File(srcPath).copy(dest);
    if (mounted) setState(() => _avatarPath = dest);
  }

  Future<void> _removeAvatar() async {
    await DecoyManager.saveConfig(
      newUsername: _usernameCtrl.text.trim(),
      newDisplayName: _displayNameCtrl.text.trim(),
      clearAvatar: true,
    );
    if (mounted) setState(() => _avatarPath = null);
  }

  // ── Snack ──────────────────────────────────────────────────────────────────
  void _showSnack(String msg) {
    if (!mounted) return;
    final cs = Theme.of(context).colorScheme;
    final backgroundColor = SettingsManager.getElementColor(
      cs.surfaceContainerHighest,
      SettingsManager.elementBrightness.value,
    ).withValues(alpha: SettingsManager.elementOpacity.value);
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: TextStyle(
            color: cs.onSurfaceVariant,
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

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.theater_comedy_outlined, color: cs.primary, size: 20),
                const SizedBox(width: 8),
                Text(l.fakePinSheetTitle,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                        color: cs.onSurface)),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: _loading
                ? const Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  )
                : ListView(
                    padding: const EdgeInsets.all(20),
                    shrinkWrap: true,
                    children: [
                      _buildPinSection(l, cs),
                      const SizedBox(height: 16),
                      _buildAccountSection(l, cs),
                      const SizedBox(height: 16),
                      _buildFakeChatsSection(l, cs),
                      const SizedBox(height: 16),
                      _buildFakeGroupsSection(l, cs),
                      const SizedBox(height: 16),
                      _buildFakeFavoritesSection(l, cs),
                      const SizedBox(height: 16),
                      _buildGenerateAllButton(l, cs),
                      const SizedBox(height: 16),
                      _buildSecurityNote(l, cs),
                      const SizedBox(height: 8),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // ── Section builders ───────────────────────────────────────────────────────

  Widget _buildPinSection(AppLocalizations l, ColorScheme cs) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.security,
                  color: _enabled ? cs.primary : cs.outline, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(l.fakePinTitle,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: cs.onSurface)),
              ),
              _StatusChip(
                label: _enabled ? l.fakePinStatusActive : l.fakePinStatusOff,
                color: _enabled ? Colors.green : cs.outline,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(l.fakePinDescription,
              style: TextStyle(fontSize: 12, color: cs.outline)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: _enabled
                ? OutlinedButton.icon(
                    onPressed: _disableFakePin,
                    icon: const Icon(Icons.lock_open, size: 16),
                    label: Text(l.disableFakePin),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: cs.error,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  )
                : FilledButton.icon(
                    onPressed: _enableFakePin,
                    icon: const Icon(Icons.add, size: 16),
                    label: Text(l.setFakePin),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
          ),
          if (_enabled) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _enableFakePin,
                icon: const Icon(Icons.edit, size: 16),
                label: Text(l.changeFakePin),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAccountSection(AppLocalizations l, ColorScheme cs) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person_outline, color: cs.primary, size: 18),
              const SizedBox(width: 8),
              Text(l.decoyAccountSection,
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: cs.onSurface)),
            ],
          ),
          const SizedBox(height: 4),
          Text(l.decoyAccountSubtitle,
              style: TextStyle(fontSize: 12, color: cs.outline)),
          const SizedBox(height: 16),

          Center(
            child: GestureDetector(
              onTap: _pickAvatar,
              child: Stack(
                children: [
                  DecoyAvatarPreview(
                    avatarPath: _avatarPath,
                    displayName: _displayNameCtrl.text.isNotEmpty
                        ? _displayNameCtrl.text
                        : 'U',
                    size: 68,
                    cs: cs,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                          color: cs.primary, shape: BoxShape.circle),
                      child:
                          const Icon(Icons.edit, size: 13, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_avatarPath != null) ...[
            const SizedBox(height: 6),
            Center(
              child: TextButton.icon(
                onPressed: _removeAvatar,
                icon: const Icon(Icons.delete_outline, size: 15),
                label: Text(l.removeAvatar),
                style: TextButton.styleFrom(
                  foregroundColor: cs.error,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                ),
              ),
            ),
          ],

          const SizedBox(height: 14),

          TextField(
            controller: _displayNameCtrl,
            decoration: InputDecoration(
              labelText: l.decoyDisplayNameLabel,
              hintText: l.decoyDisplayNameHint,
              filled: true,
              fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.3),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: cs.primary, width: 1.5)),
              isDense: true,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),

          TextField(
            controller: _usernameCtrl,
            decoration: InputDecoration(
              labelText: l.decoyUsernameLabel,
              hintText: l.decoyUsernameHint,
              prefixText: '@',
              filled: true,
              fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.3),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: cs.primary, width: 1.5)),
              isDense: true,
            ),
          ),
          const SizedBox(height: 14),

          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(l.saveDecoyAccount),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFakeChatsSection(AppLocalizations l, ColorScheme cs) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.chat_outlined, color: cs.primary, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(l.decoyContactsSection,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: cs.onSurface)),
              ),
              if (_contacts.isNotEmpty) _CountChip(count: _contacts.length, cs: cs),
            ],
          ),
          const SizedBox(height: 4),
          Text(l.decoyChatsSubtitle,
              style: TextStyle(fontSize: 12, color: cs.outline)),
          const SizedBox(height: 10),

          if (_contacts.isEmpty)
            _EmptyHint(text: l.decoyNoContacts, cs: cs)
          else
            ..._contacts.map((c) => _ItemRow(
                  title: c.displayName,
                  subtitle: '@${c.username} · ${c.messages.length} ${l.messagesCount}',
                  cs: cs,
                  onDelete: () => _removeChat(c.username),
                )),

          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _addChat,
              icon: const Icon(Icons.person_add_outlined, size: 15),
              label: Text(l.addDecoyContact,
                  style: const TextStyle(fontSize: 13)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFakeGroupsSection(AppLocalizations l, ColorScheme cs) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.group_outlined, color: cs.primary, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(l.decoyGroupsSection,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: cs.onSurface)),
              ),
              if (_fakeGroups.isNotEmpty)
                _CountChip(count: _fakeGroups.length, cs: cs),
            ],
          ),
          const SizedBox(height: 4),
          Text(l.decoyGroupsSubtitle,
              style: TextStyle(fontSize: 12, color: cs.outline)),
          const SizedBox(height: 10),

          if (_fakeGroups.isEmpty)
            _EmptyHint(text: l.noFakeGroups, cs: cs)
          else
            ..._fakeGroups.map((g) => _ItemRow(
                  title: g.name,
                  subtitle: g.isChannel ? l.channelType : l.groupType,
                  icon: g.isChannel
                      ? Icons.campaign_outlined
                      : Icons.group_outlined,
                  cs: cs,
                  onDelete: () => _removeGroup(g.id),
                )),

          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _addGroup(false),
                  icon: const Icon(Icons.group_add_outlined, size: 15),
                  label: Text(l.addFakeGroup,
                      style: const TextStyle(fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _addGroup(true),
                  icon: const Icon(Icons.campaign_outlined, size: 15),
                  label: Text(l.addFakeChannel,
                      style: const TextStyle(fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFakeFavoritesSection(AppLocalizations l, ColorScheme cs) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.star_outline, color: cs.primary, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(l.decoyFavoritesSection,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: cs.onSurface)),
              ),
              if (_fakeFavorites.isNotEmpty)
                _CountChip(count: _fakeFavorites.length, cs: cs),
            ],
          ),
          const SizedBox(height: 4),
          Text(l.decoyFavoritesSubtitle,
              style: TextStyle(fontSize: 12, color: cs.outline)),
          const SizedBox(height: 10),

          if (_fakeFavorites.isEmpty)
            _EmptyHint(text: l.noFakeFavorites, cs: cs)
          else
            ..._fakeFavorites.map((f) => _ItemRow(
                  title: f.title,
                  cs: cs,
                  onDelete: () => _removeFavorite(f.id),
                )),

          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _addFavorite,
              icon: const Icon(Icons.star_border, size: 15),
              label: Text(l.addFakeFavorite,
                  style: const TextStyle(fontSize: 13)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenerateAllButton(AppLocalizations l, ColorScheme cs) {
    return OutlinedButton.icon(
      onPressed: _generating ? null : _generateAll,
      icon: _generating
          ? SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: cs.primary),
            )
          : const Icon(Icons.auto_awesome, size: 15),
      label: Text(
        _generating ? '...' : l.generateAll,
        style: const TextStyle(fontSize: 13),
      ),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        minimumSize: const Size(double.infinity, 0),
      ),
    );
  }

  Widget _buildSecurityNote(AppLocalizations l, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 15, color: cs.outline),
          const SizedBox(width: 8),
          Expanded(
            child: Text(l.fakePinSecurityNote,
                style: TextStyle(fontSize: 12, color: cs.outline)),
          ),
        ],
      ),
    );
  }
}

// ── Shared helper widgets ─────────────────────────────────────────────────────

class _ItemRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final ColorScheme cs;
  final VoidCallback onDelete;

  const _ItemRow({
    required this.title,
    this.subtitle,
    this.icon,
    required this.cs,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: cs.outline),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                        color: cs.onSurface)),
                if (subtitle != null)
                  Text(subtitle!,
                      style: TextStyle(fontSize: 11, color: cs.outline)),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, size: 16, color: cs.outline),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final String text;
  final ColorScheme cs;
  const _EmptyHint({required this.text, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Text(text,
            style: TextStyle(fontSize: 13, color: cs.outlineVariant)),
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  final int count;
  final ColorScheme cs;
  const _CountChip({required this.count, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('$count',
          style: TextStyle(
              fontSize: 11,
              color: cs.primary,
              fontWeight: FontWeight.w600)),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.2)),
      ),
      child: child,
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    );
  }
}

// Public — used also by decoy_shell.dart
class DecoyAvatarPreview extends StatelessWidget {
  final String? avatarPath;
  final String displayName;
  final double size;
  final ColorScheme? cs;

  const DecoyAvatarPreview({
    super.key,
    this.avatarPath,
    required this.displayName,
    this.size = 48,
    this.cs,
  });

  @override
  Widget build(BuildContext context) {
    if (avatarPath != null) {
      final file = File(avatarPath!);
      if (file.existsSync()) {
        return ClipOval(
          child: Image.file(file, width: size, height: size, fit: BoxFit.cover),
        );
      }
    }
    final colorScheme = cs ?? Theme.of(context).colorScheme;
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.bold,
          fontSize: size * 0.42,
        ),
      ),
    );
  }
}
