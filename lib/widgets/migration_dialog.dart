// lib/widgets/migration_dialog.dart
//
// Shows when old JSON files are detected. Guides the user through the
// one-time migration to SQLite storage.

import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../managers/settings_manager.dart';
import '../services/migration/migration_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Entry point — call this from main app after DB is initialized.
// Returns true if migration completed or was already done.
// ─────────────────────────────────────────────────────────────────────────────

Future<bool> showMigrationDialogIfNeeded(BuildContext context) async {
  final status = await MigrationService.getStatus();

  if (status == MigrationStatus.done ||
      status == MigrationStatus.notNeeded) {
    return true;
  }

  if (!context.mounted) return false;

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _MigrationDialog(),
  );

  return result == true;
}

// ─────────────────────────────────────────────────────────────────────────────
// Dialog
// ─────────────────────────────────────────────────────────────────────────────

class _MigrationDialog extends StatefulWidget {
  const _MigrationDialog();

  @override
  State<_MigrationDialog> createState() => _MigrationDialogState();
}

class _MigrationDialogState extends State<_MigrationDialog> {
  _Screen _screen = _Screen.loading;
  MigrationSizeInfo? _sizeInfo;
  MigrationProgress? _progress;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final info = await MigrationService.calculateSize();
      if (mounted) {
        setState(() {
          _sizeInfo = info;
          _screen = _Screen.prompt;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _screen = _Screen.error);
    }
  }

  Future<void> _startMigration() async {
    setState(() => _screen = _Screen.progress);
    try {
      await MigrationService.runFullMigration(
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      if (mounted) {
        setState(() => _screen = _Screen.done);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _screen = _Screen.error;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // prevent back-button dismiss during migration
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: SizedBox(
          width: 420,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _buildScreen(context),
          ),
        ),
      ),
    );
  }

  Widget _buildScreen(BuildContext context) {
    final l = AppLocalizations.of(context);
    return switch (_screen) {
      _Screen.loading => const _LoadingView(),
      _Screen.prompt => _PromptView(
          sizeInfo: _sizeInfo!,
          l: l,
          onStart: _startMigration,
          onSkip: () {
            MigrationService.markSkipped();
            Navigator.of(context).pop(false);
          },
        ),
      _Screen.progress => _ProgressView(progress: _progress, l: l),
      _Screen.done => _DoneView(
          l: l,
          onClose: () => Navigator.of(context).pop(true),
        ),
      _Screen.error => _ErrorView(
          error: _error,
          l: l,
          onClose: () => Navigator.of(context).pop(false),
        ),
    };
  }
}

enum _Screen { loading, prompt, progress, done, error }

// ─────────────────────────────────────────────────────────────────────────────
// Sub-screens
// ─────────────────────────────────────────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _PromptView extends StatelessWidget {
  final MigrationSizeInfo sizeInfo;
  final AppLocalizations l;
  final VoidCallback onStart;
  final VoidCallback onSkip;

  const _PromptView({
    required this.sizeInfo,
    required this.l,
    required this.onStart,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final locale = SettingsManager.appLocale.value;
    final sizeMb = (sizeInfo.totalBytes / (1024 * 1024)).toStringAsFixed(1);
    final sizeLabel = locale.languageCode == 'ru' ? '$sizeMb МБ' : '$sizeMb MB';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(Icons.storage_rounded, color: cs.primary, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Text(l.migrationTitle,
                style: Theme.of(context).textTheme.titleLarge),
          ),
        ]),
        const SizedBox(height: 16),
        Text(l.migrationBody),
        const SizedBox(height: 12),
        _InfoRow(
          icon: Icons.person_outline,
          label: l.migrationAccounts,
          value: '${sizeInfo.accountCount}',
        ),
        _InfoRow(
          icon: Icons.storage_outlined,
          label: l.migrationDataSize,
          value: sizeLabel,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 16, color: cs.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l.migrationBackupNote,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (!sizeInfo.hasEnoughSpace)
              TextButton(
                onPressed: onSkip,
                child: Text(l.migrationSkip),
              ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: onStart,
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(l.migrationStart),
            ),
          ],
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: cs.onSurfaceVariant),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(fontSize: 13)),
          Text(value,
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: cs.primary)),
        ],
      ),
    );
  }
}

class _ProgressView extends StatelessWidget {
  final MigrationProgress? progress;
  final AppLocalizations l;

  const _ProgressView({required this.progress, required this.l});

  @override
  Widget build(BuildContext context) {
    final p = progress;
    final phaseLabel = switch (p?.phase) {
      'backup' => l.migrationPhaseBackup,
      'import' => l.migrationPhaseImport,
      'verify' => l.migrationPhaseVerify,
      _ => l.migrationPhasePreparing,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(phaseLabel,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: p?.fraction,
            minHeight: 6,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 8),
          if (p != null)
            Text(
              '${p.current} / ${p.total}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          const SizedBox(height: 6),
          if (p?.currentItem != null)
            Text(
              p!.currentItem,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          const SizedBox(height: 12),
          Text(
            l.migrationDontClose,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _DoneView extends StatelessWidget {
  final AppLocalizations l;
  final VoidCallback onClose;

  const _DoneView({required this.l, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        Icon(Icons.check_circle_outline_rounded,
            size: 56, color: cs.primary),
        const SizedBox(height: 12),
        Text(l.migrationDoneTitle,
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          l.migrationDoneBody,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          l.migrationDoneNote,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: onClose,
          child: Text(l.migrationDoneButton),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  final Object? error;
  final AppLocalizations l;
  final VoidCallback onClose;

  const _ErrorView({required this.error, required this.l, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        Icon(Icons.error_outline_rounded, size: 48, color: cs.error),
        const SizedBox(height: 12),
        Text(l.migrationErrorTitle,
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          l.migrationErrorBody,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        TextButton(
          onPressed: onClose,
          child: Text(l.migrationErrorButton),
        ),
      ],
    );
  }
}
