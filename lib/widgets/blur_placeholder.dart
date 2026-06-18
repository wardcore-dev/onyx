// lib/widgets/blur_placeholder.dart
//
// Telegram-style placeholder shown while a remote image is still downloading:
//   • a blurred low-res preview rendered from the message's BlurHash, and
//   • a circular button with an icon (loading / cancel / retry) on top.
//
// If no BlurHash is available (e.g. images sent before this feature existed)
// a neutral surface colour is used instead of the blur.
import 'package:flutter/material.dart';
import 'package:flutter_blurhash/flutter_blurhash.dart';

class BlurPlaceholder extends StatelessWidget {
  /// BlurHash string from the message metadata, or null when unavailable.
  final String? blurHash;

  /// Icon drawn inside the centre circle when [loading] is false (e.g. retry).
  final IconData icon;

  /// Optional tap handler for the centre button (e.g. cancel / retry).
  final VoidCallback? onTap;

  /// When true, shows an animated spinner instead of a static icon, so the
  /// placeholder reads as "downloading" rather than a dead/empty cell.
  final bool loading;

  const BlurPlaceholder({
    super.key,
    required this.blurHash,
    this.icon = Icons.close,
    this.onTap,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final hash = blurHash;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (hash != null && hash.isNotEmpty)
          Image(
            image: BlurHashImage(hash),
            fit: BoxFit.cover,
            gaplessPlayback: true,
          )
        else
          // No blurhash: a subtle gradient instead of a flat grey, so an
          // unloaded cell still looks intentional rather than empty.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.55),
                  Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.30),
                ],
              ),
            ),
          ),
        Center(
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withOpacity(0.42),
              ),
              child: loading
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(icon, color: Colors.white, size: 22),
            ),
          ),
        ),
      ],
    );
  }
}
