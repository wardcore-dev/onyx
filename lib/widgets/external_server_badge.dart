// lib/widgets/external_server_badge.dart
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

class ExternalServerBadge extends StatelessWidget {
  final bool isChannel;
  const ExternalServerBadge({super.key, this.isChannel = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Text(
        isChannel ? AppLocalizations.of(context).externalChannel : AppLocalizations.of(context).externalGroup,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: Colors.orange.shade700,
        ),
      ),
    );
  }
}