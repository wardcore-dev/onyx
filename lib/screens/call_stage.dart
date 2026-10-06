// The call screen's background: the app theme's own background with the
// other person's avatar in a circle in the middle and their nickname under
// it. Deliberately nothing else.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../globals.dart' show avatarTokenProvider, serverBase;
import '../widgets/avatar_widget.dart';

class CallStage extends StatelessWidget {
  final String username;

  /// Shown under the name (connecting / through Tor).
  final Widget status;

  const CallStage({super.key, required this.username, required this.status});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final size = (MediaQuery.sizeOf(context).shortestSide * 0.36)
        .clamp(112.0, 168.0);

    return ColoredBox(
      color: colors.surface,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipOval(
              child: AvatarWidget(
                username: username,
                tokenProvider: avatarTokenProvider,
                avatarBaseUrl: serverBase,
                size: size,
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                username,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: colors.onSurface,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            const SizedBox(height: 8),
            status,
          ],
        ),
      ),
    );
  }
}
