// lib/widgets/onyx_dialog.dart
//
// Shared chrome for every ONYX modal dialog: transparent Dialog, 28px
// rounded card on colorScheme.surface, tinted header with a close button,
// and pill-shaped buttons. This is the visual language of the About ONYX
// dialog, extracted so it stops being copy-pasted per screen.
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

const double kOnyxDialogRadius = 28.0;

/// Corner radius of the panels/cards inside the newer file-sync dialogs (and
/// of those dialogs themselves).
const double kOnyxPanelRadius = 27.0;
const kOnyxDialogButtonShape = RoundedRectangleBorder(
  borderRadius: BorderRadius.all(Radius.circular(50)),
);
const EdgeInsets kOnyxDialogButtonPadding = EdgeInsets.symmetric(vertical: 13);

/// The transparent-Dialog + rounded-card + surface-fill chrome shared by
/// every ONYX dialog. Give it a [child] built from [OnyxDialogHeader] plus
/// whatever body/buttons the dialog needs.
class OnyxDialogShell extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsets insetPadding;
  final double radius;

  const OnyxDialogShell({
    super.key,
    required this.child,
    this.maxWidth = 400,
    this.radius = kOnyxDialogRadius,
    this.insetPadding =
        const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // No elevation/shadow and a single clip pass (via Material's own
    // clipBehavior instead of a separate ClipRRect): a PhysicalModel shadow
    // or an extra clip layer sitting inside the scale/fade transition can't
    // be raster-cached across frames, which is what caused the stutter on
    // dialog close.
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: insetPadding,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Material(
          color: colorScheme.surface,
          clipBehavior: Clip.antiAlias,
          borderRadius: BorderRadius.circular(radius),
          child: child,
        ),
      ),
    );
  }
}

/// The tinted header row at the top of every ONYX dialog: optional leading
/// icon/avatar, title (+ optional subtitle), and a close button.
class OnyxDialogHeader extends StatelessWidget {
  final Widget? leading;
  final Widget title;
  final Widget? subtitle;
  final VoidCallback? onClose;
  final EdgeInsets padding;

  const OnyxDialogHeader({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.onClose,
    this.padding = const EdgeInsets.fromLTRB(20, 20, 16, 16),
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: padding,
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
          if (leading != null) ...[leading!, const SizedBox(width: 12)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                title,
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  subtitle!,
                ],
              ],
            ),
          ),
          if (onClose != null)
            GestureDetector(
              onTap: onClose,
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
    );
  }
}

/// Small square icon button for a header's leading slot (e.g. "back"),
/// looking like the close button on the right-hand side.
class OnyxHeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const OnyxHeaderIconButton({super.key, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: colorScheme.onSurface.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon,
            size: 18, color: colorScheme.onSurface.withValues(alpha: 0.55)),
      ),
    );
  }
}

/// Pushes [builder] through the standard ONYX entrance (a plain fade — the
/// same transition used by About ONYX / profile dialogs and every dialog
/// built on this file). Kept deliberately simple: a single fade reads as
/// snappier than a fade+scale combo and has one less curve to keep in sync
/// when a dialog's content size changes mid-transition.
Future<T?> showOnyxDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  String barrierLabel = '',
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: barrierLabel,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    transitionDuration: const Duration(milliseconds: 140),
    transitionBuilder: (ctx, anim, _, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
        child: child,
      );
    },
    pageBuilder: (ctx, _, __) => builder(ctx),
  );
}

/// Drop-in ONYX-styled replacement for a single-button info/alert
/// `AlertDialog` (no cancel action — just an acknowledgement).
Future<void> showOnyxInfoDialog({
  required BuildContext context,
  required String title,
  required String message,
  String? buttonLabel,
  bool isError = false,
  IconData icon = Icons.info_outline_rounded,
  bool barrierDismissible = false,
}) {
  return showOnyxDialog<void>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: title,
    builder: (ctx) {
      final colorScheme = Theme.of(ctx).colorScheme;
      final l = AppLocalizations.of(ctx);
      final accent = isError ? colorScheme.error : colorScheme.primary;
      return OnyxDialogShell(
        maxWidth: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OnyxDialogHeader(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 20, color: accent),
              ),
              title: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              onClose: () => Navigator.of(ctx).pop(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Text(
                message,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: colorScheme.onSurface.withValues(alpha: 0.65),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: FilledButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: FilledButton.styleFrom(
                  padding: kOnyxDialogButtonPadding,
                  shape: kOnyxDialogButtonShape,
                ),
                child: Text(buttonLabel ?? l.ok),
              ),
            ),
          ],
        ),
      );
    },
  );
}

Future<bool?> showOnyxConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  String? confirmLabel,
  String? cancelLabel,
  bool isDestructive = false,
  IconData icon = Icons.help_outline_rounded,
}) {
  return showOnyxDialog<bool>(
    context: context,
    barrierLabel: title,
    builder: (ctx) {
      final colorScheme = Theme.of(ctx).colorScheme;
      final l = AppLocalizations.of(ctx);
      final accent = isDestructive ? colorScheme.error : colorScheme.primary;
      return OnyxDialogShell(
        maxWidth: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OnyxDialogHeader(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 20, color: accent),
              ),
              title: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              onClose: () => Navigator.of(ctx).pop(false),
            ),
            if (message.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Text(
                  message,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: colorScheme.onSurface.withValues(alpha: 0.65),
                  ),
                ),
              ),
            Padding(
              padding:
                  EdgeInsets.fromLTRB(20, message.isNotEmpty ? 16 : 20, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    style: FilledButton.styleFrom(
                      padding: kOnyxDialogButtonPadding,
                      shape: kOnyxDialogButtonShape,
                      backgroundColor: isDestructive ? colorScheme.error : null,
                      foregroundColor:
                          isDestructive ? colorScheme.onError : null,
                    ),
                    child: Text(confirmLabel ?? l.yes),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    style: OutlinedButton.styleFrom(
                      padding: kOnyxDialogButtonPadding,
                      shape: kOnyxDialogButtonShape,
                    ),
                    child: Text(cancelLabel ?? l.cancel),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// Rounded panel used inside the media-send dialogs: a small caption plus
/// label/value rows (file name, size, duration ...).
class OnyxDetailsPanel extends StatelessWidget {
  final String title;
  final List<(String, String)> rows;

  const OnyxDetailsPanel({super.key, required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.onSurface.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
              color: cs.onSurface.withValues(alpha: 0.55),
            ),
          ),
          for (final (label, value) in rows) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color: cs.onSurface.withValues(alpha: 0.55),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    value,
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Header leading badge: round tinted icon, as in the other ONYX dialogs.
class OnyxHeaderBadge extends StatelessWidget {
  final IconData icon;
  const OnyxHeaderBadge(this.icon, {super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 20, color: cs.primary),
    );
  }
}

/// Bold 16px header title.
class OnyxHeaderTitle extends StatelessWidget {
  final String text;
  const OnyxHeaderTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      );
}

/// Footer of a confirm dialog: full-width pill "confirm" + pill "cancel".
class OnyxConfirmButtons extends StatelessWidget {
  final String confirmLabel;
  final VoidCallback onConfirm;
  final String cancelLabel;
  final VoidCallback onCancel;
  final IconData? confirmIcon;

  const OnyxConfirmButtons({
    super.key,
    required this.confirmLabel,
    required this.onConfirm,
    required this.cancelLabel,
    required this.onCancel,
    this.confirmIcon,
  });

  @override
  Widget build(BuildContext context) {
    final style = FilledButton.styleFrom(
      padding: kOnyxDialogButtonPadding,
      shape: kOnyxDialogButtonShape,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          confirmIcon == null
              ? FilledButton(
                  onPressed: onConfirm, style: style, child: Text(confirmLabel))
              : FilledButton.icon(
                  onPressed: onConfirm,
                  style: style,
                  icon: Icon(confirmIcon, size: 18),
                  label: Text(confirmLabel)),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: onCancel,
            style: OutlinedButton.styleFrom(
              padding: kOnyxDialogButtonPadding,
              shape: kOnyxDialogButtonShape,
            ),
            child: Text(cancelLabel),
          ),
        ],
      ),
    );
  }
}
