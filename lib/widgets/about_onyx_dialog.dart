// lib/widgets/about_onyx_dialog.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../globals.dart';
import '../utils/update_checker.dart';
import 'connection_title.dart';

void showAboutOnyxDialog(BuildContext context) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'About ONYX',
    barrierColor: Colors.black.withValues(alpha: 0.55),
    transitionDuration: const Duration(milliseconds: 280),
    transitionBuilder: (ctx, anim, _, child) {
      final curved =
          CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeIn),
        child: ScaleTransition(scale: Tween<double>(begin: 0.92, end: 1.0).animate(curved), child: child),
      );
    },
    pageBuilder: (ctx, _, __) => const _AboutOnyxContent(),
  );
}

class _AboutOnyxContent extends StatefulWidget {
  const _AboutOnyxContent();

  @override
  State<_AboutOnyxContent> createState() => _AboutOnyxContentState();
}

class _AboutOnyxContentState extends State<_AboutOnyxContent>
    with SingleTickerProviderStateMixin {
  late final AnimationController _logoCtrl;
  late final Animation<double> _logoScale;

  String? _serverCity;
  String? _serverCountry;
  bool _loadingGeo = true;

  String? _releaseNotes;
  bool _loadingNotes = true;

  bool _checkingUpdate = false;
  String? _updateMessage;

  @override
  void initState() {
    super.initState();
    _logoCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _logoScale = CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOutBack);
    _logoCtrl.forward();
    _fetchGeo();
    _fetchReleaseNotes();
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchGeo() async {
    try {
      final host = Uri.parse(serverBase).host;
      final response = await http
          .get(
            Uri.parse(
                'http://ip-api.com/json/$host?fields=status,country,city'),
          )
          .timeout(const Duration(seconds: 6));
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['status'] == 'success') {
          setState(() {
            _serverCity = data['city'] as String?;
            _serverCountry = data['country'] as String?;
          });
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingGeo = false);
  }

  Future<void> _fetchReleaseNotes() async {
    final existing = updateInfoNotifier.value;
    if (existing?.releaseNotes != null && existing!.releaseNotes!.trim().isNotEmpty) {
      if (mounted) {
        setState(() {
          _releaseNotes = existing.releaseNotes;
          _loadingNotes = false;
        });
      }
      return;
    }
    try {
      final response = await http.get(
        Uri.parse(
            'https://api.github.com/repos/wardcore-dev/onyx/releases/latest'),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      ).timeout(const Duration(seconds: 8));
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        setState(() => _releaseNotes = data['body'] as String?);
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingNotes = false);
  }

  Future<void> _checkForUpdates() async {
    setState(() {
      _checkingUpdate = true;
      _updateMessage = null;
    });
    final info = await UpdateChecker.checkForUpdates(kAppVersion);
    if (!mounted) return;
    setState(() {
      _checkingUpdate = false;
      if (info != null) {
        updateInfoNotifier.value = info;
        _updateMessage = 'Update available: ${info.version}';
      } else {
        _updateMessage = 'You\'re up to date!';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final serverHost = Uri.parse(serverBase).host;

    String locationText;
    if (_loadingGeo) {
      locationText = 'Loading location...';
    } else if (_serverCity != null && _serverCountry != null) {
      locationText = '$_serverCity, $_serverCountry';
    } else {
      locationText = serverHost;
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Material(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Header ──────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 36, 24, 28),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.06),
                      border: Border(
                        bottom: BorderSide(
                          color: colorScheme.primary.withValues(alpha: 0.10),
                          width: 0.8,
                        ),
                      ),
                    ),
                    child: Column(
                      children: [
                        ScaleTransition(
                          scale: _logoScale,
                          child: Image.asset(
                            'assets/onyx-512.png',
                            width: 88,
                            height: 88,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ConnectionTitle(
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 5),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            kAppVersion,
                            style: TextStyle(
                              color: colorScheme.primary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Server info ──────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
                    child: Text(
                      'SERVER',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                        color: colorScheme.onSurface.withValues(alpha: 0.38),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: colorScheme.outlineVariant
                              .withValues(alpha: 0.3),
                          width: 0.8,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              ValueListenableBuilder<bool>(
                                valueListenable: wsConnectedNotifier,
                                builder: (_, connected, __) => Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: connected
                                            ? colorScheme.primary
                                            : Colors.orange,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 7),
                                    Text(
                                      connected
                                          ? 'Connected'
                                          : 'Connecting...',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: connected
                                            ? colorScheme.primary
                                            : Colors.orange,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              Text(
                                serverHost,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colorScheme.onSurface
                                      .withValues(alpha: 0.45),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on_outlined,
                                size: 14,
                                color: colorScheme.onSurface
                                    .withValues(alpha: 0.4),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                locationText,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colorScheme.onSurface
                                      .withValues(alpha: 0.5),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  Divider(
                    height: 1,
                    indent: 20,
                    endIndent: 20,
                    color: colorScheme.outlineVariant.withValues(alpha: 0.25),
                  ),

                  // ── What's new ───────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
                    child: Text(
                      'WHAT\'S NEW',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                        color: colorScheme.onSurface.withValues(alpha: 0.38),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    child: _loadingNotes
                        ? Center(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 10),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: colorScheme.primary,
                                ),
                              ),
                            ),
                          )
                        : (_releaseNotes != null &&
                                _releaseNotes!.trim().isNotEmpty)
                            ? ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxHeight: 140),
                                child: SingleChildScrollView(
                                  child: Text(
                                    _releaseNotes!,
                                    style: TextStyle(
                                      fontSize: 13,
                                      height: 1.55,
                                      color: colorScheme.onSurface
                                          .withValues(alpha: 0.65),
                                    ),
                                  ),
                                ),
                              )
                            : Text(
                                'No release notes available.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: colorScheme.onSurface
                                      .withValues(alpha: 0.4),
                                ),
                              ),
                  ),

                  Divider(
                    height: 1,
                    indent: 20,
                    endIndent: 20,
                    color: colorScheme.outlineVariant.withValues(alpha: 0.25),
                  ),

                  // ── Update status message ────────────────────────────
                  if (_updateMessage != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: Text(
                        _updateMessage!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),

                  // ── Buttons ──────────────────────────────────────────
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                        20, _updateMessage != null ? 12 : 20, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FilledButton.icon(
                          onPressed:
                              _checkingUpdate ? null : _checkForUpdates,
                          icon: _checkingUpdate
                              ? SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: colorScheme.onPrimary,
                                  ),
                                )
                              : const Icon(Icons.autorenew_rounded,
                                  size: 18),
                          label: Text(
                            _checkingUpdate
                                ? 'Checking...'
                                : 'Check for updates',
                          ),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
