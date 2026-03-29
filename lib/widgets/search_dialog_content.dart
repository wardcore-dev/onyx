import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../globals.dart';
import '../managers/account_manager.dart';
import '../managers/settings_manager.dart';
import '../widgets/avatar_widget.dart';

class SearchDialogContent extends StatefulWidget {
  final TextEditingController controller;
  final void Function(String username) onSelect;

  const SearchDialogContent({
    super.key,
    required this.controller,
    required this.onSelect,
  });

  @override
  State<SearchDialogContent> createState() => _SearchDialogContentState();
}

class _SearchDialogContentState extends State<SearchDialogContent>
    with TickerProviderStateMixin {
  final List<String> _results = [];
  Timer? _debounce;
  bool _loading = false;
  String _error = '';
  int _hoveredIndex = -1;
  String? _cachedToken;

  final FocusNode _focusNode = FocusNode();

  late AnimationController _focusAnimController;
  late Animation<double> _focusAnim;

  late AnimationController _hoverAnimController;
  late Animation<double> _hoverAnim;

  @override
  void initState() {
    super.initState();

    _focusAnimController = AnimationController(
      duration: const Duration(milliseconds: 220),
      vsync: this,
    );
    _focusAnim = CurvedAnimation(
      parent: _focusAnimController,
      curve: Curves.easeOut,
    );

    _hoverAnimController = AnimationController(
      duration: const Duration(milliseconds: 160),
      vsync: this,
    );
    _hoverAnim = CurvedAnimation(
      parent: _hoverAnimController,
      curve: Curves.easeOut,
    );

    _loadToken();

    _focusNode.addListener(() {
      if (!mounted) return;
      setState(() {});
      if (_focusNode.hasFocus) {
        _focusAnimController.forward();
      } else {
        _focusAnimController.reverse();
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focusNode.dispose();
    _focusAnimController.dispose();
    _hoverAnimController.dispose();
    super.dispose();
  }

  Future<void> _loadToken() async {
    final acc = await AccountManager.getCurrentAccount();
    if (acc != null) {
      _cachedToken = await AccountManager.getToken(acc);
    }
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 300),
      () => _search(v),
    );
    if (mounted) setState(() {});
  }

  Future<void> _search(String q) async {
    final query = q.trim().replaceFirst('@', '');
    if (query.isEmpty) {
      if (mounted) {
        setState(() {
          _results.clear();
          _error = '';
          _loading = false;
        });
      }
      return;
    }

    if (mounted) setState(() { _loading = true; _error = ''; });

    try {
      if (_cachedToken == null) await _loadToken();
      final res = await http.get(
        Uri.parse('$serverBase/users?query=$query'),
        headers: _cachedToken != null ? {'authorization': 'Bearer $_cachedToken'} : {},
      );

      if (res.statusCode != 200) throw Exception('status ${res.statusCode}');

      final data = jsonDecode(res.body);
      final List list = data is List ? data : (data['results'] as List? ?? []);

      if (mounted) {
        setState(() {
          _results
            ..clear()
            ..addAll(list.map((e) => e['username'].toString()));
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Search error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasQuery = widget.controller.text.trim().isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _searchField(context),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: _loading ? 2 : 0,
          child: _loading
              ? LinearProgressIndicator(
                  borderRadius: BorderRadius.circular(2),
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
                  backgroundColor: Colors.transparent,
                )
              : const SizedBox.shrink(),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child: hasQuery ? _resultsList() : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _searchField(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ValueListenableBuilder<double>(
      valueListenable: SettingsManager.elementBrightness,
      builder: (context, brightness, _) {
        final baseColor = SettingsManager.getElementColor(
          colorScheme.surfaceContainerHighest,
          brightness,
        );

        return Padding(
          padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
          child: AnimatedBuilder(
            animation: Listenable.merge([_focusAnim, _hoverAnim]),
            builder: (context, _) {
              final focusT = _focusAnim.value;
              final hoverT = _hoverAnim.value;

              final borderColor = Color.lerp(
                Color.lerp(
                  colorScheme.outline.withValues(alpha: 0.18),
                  colorScheme.primary.withValues(alpha: 0.50),
                  hoverT,
                )!,
                colorScheme.primary,
                focusT,
              )!;

              final iconColor = Color.lerp(
                Color.lerp(
                  colorScheme.onSurface.withValues(alpha: 0.45),
                  colorScheme.primary.withValues(alpha: 0.75),
                  hoverT,
                )!,
                colorScheme.primary,
                focusT,
              )!;

              final bgColor = Color.lerp(
                baseColor,
                Color.lerp(baseColor, colorScheme.primary, 0.05)!,
                hoverT * (1.0 - focusT),
              )!;

              final shadowAlpha = hoverT * 0.06 + focusT * 0.12;
              final shadowBlur = 8.0 + focusT * 6.0;

              return MouseRegion(
                cursor: SystemMouseCursors.text,
                onEnter: (_) => _hoverAnimController.forward(),
                onExit: (_) => _hoverAnimController.reverse(),
                child: Container(
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: borderColor, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.primary.withValues(alpha: shadowAlpha),
                        blurRadius: shadowBlur,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: widget.controller,
                    focusNode: _focusNode,
                    autofocus: true,
                    onChanged: _onChanged,
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 15,
                    ),
                    cursorColor: colorScheme.primary,
                    decoration: InputDecoration(
                      prefixIcon: Padding(
                        padding: const EdgeInsets.only(left: 2),
                        child: Icon(
                          Icons.search_rounded,
                          color: iconColor,
                          size: 22,
                        ),
                      ),
                      hintText: 'Search @username...',
                      hintStyle: TextStyle(
                        color: colorScheme.onSurface.withValues(alpha: 0.4),
                        fontSize: 15,
                      ),
                      suffixIcon: widget.controller.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.close_rounded,
                                color: colorScheme.onSurface.withValues(alpha: 0.5),
                                size: 18,
                              ),
                              onPressed: () {
                                widget.controller.clear();
                                _onChanged('');
                              },
                            )
                          : null,
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      focusColor: Colors.transparent,
                      hoverColor: Colors.transparent,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 13,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _resultsList() {
    final colorScheme = Theme.of(context).colorScheme;

    if (_loading) return const SizedBox.shrink();

    if (_error.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 18,
              color: colorScheme.error.withValues(alpha: 0.75),
            ),
            const SizedBox(width: 8),
            Text(
              'Search error',
              style: TextStyle(
                color: colorScheme.error.withValues(alpha: 0.75),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    if (_results.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.person_search_rounded,
              size: 34,
              color: colorScheme.onSurface.withValues(alpha: 0.25),
            ),
            const SizedBox(height: 10),
            Text(
              'No users found',
              style: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.45),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 4),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 280),
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: _results.length,
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
          itemBuilder: (_, i) {
            final username = _results[i];
            final isHovered = _hoveredIndex == i;

            return MouseRegion(
              onEnter: (_) => setState(() => _hoveredIndex = i),
              onExit: (_) => setState(() => _hoveredIndex = -1),
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => widget.onSelect(username),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOut,
                  margin: const EdgeInsets.symmetric(vertical: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: isHovered
                        ? colorScheme.primary.withValues(alpha: 0.09)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      AvatarWidget(
                        key: ValueKey('avatar-$username'),
                        username: username,
                        tokenProvider: avatarTokenProvider,
                        avatarBaseUrl: serverBase,
                        size: 40,
                        editable: false,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: '@',
                                style: TextStyle(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              TextSpan(
                                text: username,
                                style: TextStyle(
                                  color: colorScheme.onSurface,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 150),
                        opacity: isHovered ? 1.0 : 0.0,
                        child: Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 13,
                          color: colorScheme.primary.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}