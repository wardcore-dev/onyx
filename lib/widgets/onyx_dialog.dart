// lib/widgets/onyx_dialog.dart
//
// Shared chrome for every ONYX modal dialog: transparent Dialog, 28px
// rounded card on colorScheme.surface, tinted header with a close button,
// and pill-shaped buttons. This is the visual language of the About ONYX
// dialog, extracted so it stops being copy-pasted per screen.
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

const double kOnyxDialogRadius = 28.0;
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

  const OnyxDialogShell({
    super.key,
    required this.child,
    this.maxWidth = 400,
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
          borderRadius: BorderRadius.circular(kOnyxDialogRadius),
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

/// Pushes [builder] through the standard ONYX scale+fade entrance (the same
/// transition used by About ONYX / profile dialogs).
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
    transitionDuration: const Duration(milliseconds: 187),
    transitionBuilder: (ctx, anim, _, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeIn),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1.0).animate(curved),
          child: child,
        ),
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
