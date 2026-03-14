// lib/widgets/security_warning_card.dart
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

class SecurityWarningCard extends StatelessWidget {
  const SecurityWarningCard({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 20),
              const SizedBox(width: 8),
              Text(
                AppLocalizations.of(context).thirdPartyServer,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.amber.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            AppLocalizations.of(context).thirdPartyWarning,
            style: TextStyle(fontSize: 12, color: colorScheme.onSurface.withValues(alpha: 0.8)),
          ),
          const SizedBox(height: 12),
          Text(
            AppLocalizations.of(context).serverWillKnow,
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: colorScheme.onSurface),
          ),
          const SizedBox(height: 4),
          _bulletPoint(context, AppLocalizations.of(context).knowIpAddress),
          _bulletPoint(context, AppLocalizations.of(context).knowUsername),
          _bulletPoint(context, AppLocalizations.of(context).knowMessages),
          const SizedBox(height: 10),
          Text(
            AppLocalizations.of(context).serverWillNotReceive,
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.green.shade700),
          ),
          const SizedBox(height: 4),
          _bulletPoint(context, AppLocalizations.of(context).notReceiveAccount, safe: true),
          _bulletPoint(context, AppLocalizations.of(context).notReceiveContacts, safe: true),
          _bulletPoint(context, AppLocalizations.of(context).notReceiveKeys, safe: true),
        ],
      ),
    );
  }

  Widget _bulletPoint(BuildContext context, String text, {bool safe = false}) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, top: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(safe ? '  ' : '  ', style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: safe
                    ? Colors.green.shade600
                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }
}