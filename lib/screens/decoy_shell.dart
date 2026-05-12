// lib/screens/decoy_shell.dart
import 'package:flutter/material.dart';
import '../managers/decoy_manager.dart';
import '../l10n/app_localizations.dart';
import '../widgets/cute_bottom_nav.dart';
import 'decoy_setup_screen.dart';

class DecoyShell extends StatefulWidget {
  final VoidCallback onLock;
  const DecoyShell({super.key, required this.onLock});

  @override
  State<DecoyShell> createState() => _DecoyShellState();
}

class _DecoyShellState extends State<DecoyShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final isDesktop = MediaQuery.of(context).size.width > 700;

    final tabs = [
      NavItem(Icons.chat_bubble, l.navChats),
      NavItem(Icons.group, l.navGroups),
      NavItem(Icons.bookmark_outlined, l.navFavorites),
      NavItem(Icons.person, l.navAccounts),
      NavItem(Icons.settings, l.navSettings),
    ];

    final body = IndexedStack(
      index: _index,
      children: [
        _EmptyTab(icon: Icons.chat_bubble_outline, label: l.decoyNoChats),
        _EmptyTab(icon: Icons.group_outlined, label: l.decoyNoGroups),
        _EmptyTab(icon: Icons.bookmark_outline, label: l.decoyNoFavorites),
        _DecoyAccountTab(onLock: widget.onLock),
        _DecoySettingsTab(onLock: widget.onLock),
      ],
    );

    if (isDesktop) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              labelType: NavigationRailLabelType.none,
              destinations: tabs
                  .map((t) => NavigationRailDestination(
                        icon: Icon(t.icon),
                        selectedIcon: Icon(t.icon,
                            color: Theme.of(context).colorScheme.primary),
                        label: Text(t.label),
                      ))
                  .toList(),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      body: body,
      bottomNavigationBar: CuteBottomNav(
        selectedIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: tabs,
      ),
    );
  }
}

class _EmptyTab extends StatelessWidget {
  final IconData icon;
  final String label;
  const _EmptyTab({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: cs.outlineVariant),
          const SizedBox(height: 12),
          Text(label, style: TextStyle(color: cs.outline, fontSize: 15)),
        ],
      ),
    );
  }
}

class _DecoyAccountTab extends StatelessWidget {
  final VoidCallback onLock;
  const _DecoyAccountTab({required this.onLock});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Row(
              children: [
                DecoyAvatarPreview(
                  displayName: DecoyManager.displayName,
                  avatarPath: DecoyManager.avatarPath,
                  size: 64,
                  cs: cs,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DecoyManager.displayName,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 20),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '@${DecoyManager.username}',
                        style: TextStyle(fontSize: 13, color: cs.outline),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 8),
            Text(
              l.decoyOtherAccounts,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: cs.outline),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                l.decoyNoOtherAccounts,
                style: TextStyle(color: cs.outlineVariant, fontSize: 13),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onLock,
                icon: const Icon(Icons.lock_outline, size: 18),
                label: Text(l.lock),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DecoySettingsTab extends StatelessWidget {
  final VoidCallback onLock;
  const _DecoySettingsTab({required this.onLock});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          const SizedBox(height: 8),
          Text(l.navSettings,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                  color: cs.onSurface)),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.palette_outlined),
            title: Text(l.decoyAppearance),
            subtitle: Text(l.decoyAppearanceSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.notifications_outlined),
            title: Text(l.decoyNotifications),
            subtitle: Text(l.decoyNotificationsSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.storage_outlined),
            title: Text(l.decoyStorage),
            subtitle: Text(l.decoyStorageSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          const Divider(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.lock_outline),
            title: Text(l.lock),
            onTap: onLock,
          ),
        ],
      ),
    );
  }
}
