// lib/widgets/external_server_badge.dart
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

class ExternalServerBadge extends StatelessWidget {
  final bool isChannel;
  const ExternalServerBadge({super.key, this.isChannel = false});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: primary.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Text(
        isChannel ? AppLocalizations.of(context).externalChannel : AppLocalizations.of(context).externalGroup,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: primary,
        ),
      ),
    );
  }
}