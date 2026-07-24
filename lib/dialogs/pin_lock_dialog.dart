import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show
        LogicalKeyboardKey,
        KeyDownEvent,
        KeyRepeatEvent,
        HapticFeedback;
import '../l10n/app_localizations.dart';
import '../managers/lock_manager.dart';
import '../widgets/pin_keypad.dart';

enum PinDialogMode { set, verify }

bool get _isDesktop =>
    !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

Future<bool> showPinDialog(
    BuildContext context, PinDialogMode mode, String chatId) async {
  final result = await Navigator.of(context).push<bool>(
    PageRouteBuilder(
      opaque: true,
      pageBuilder: (_, __, ___) =>
          _ChatPinScreen(mode: mode, chatId: chatId),
      transitionsBuilder: (_, animation, __, child) => FadeTransition(
        opacity: animation,
        child: child,
      ),
      transitionDuration: const Duration(milliseconds: 180),
    ),
  );
  return result ?? false;
}

class _ChatPinScreen extends StatefulWidget {
  final PinDialogMode mode;
  final String chatId;
  const _ChatPinScreen({required this.mode, required this.chatId});

  @override
  State<_ChatPinScreen> createState() => _ChatPinScreenState();
}

class _ChatPinScreenState extends State<_ChatPinScreen>
    with TickerProviderStateMixin {
  String _pin = '';
  String _firstPin = '';
  bool _isConfirming = false;
  String _error = '';
  bool _biometricsAvailable = false;
  // Brief green "confirmed" flash before popping — mirrors pin_code_screen.dart.
  bool _success = false;

  // Drives the per-dot wave shake on a wrong PIN (see _dotShakeOffset).
  late AnimationController _shakeController;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );

    if (widget.mode == PinDialogMode.verify) _checkBiometrics();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _checkBiometrics() async {
    final ok = await LockManager.biometricsAvailable();
    if (!mounted) return;
    setState(() => _biometricsAvailable = ok);
    if (ok) {
      // Fire right after this frame paints — matches the main lock screen's
      // addPostFrameCallback approach (main.dart _tryBiometric) instead of an
      // extra fixed sleep on top of the route's own fade-in, which made the
      // OS prompt feel noticeably slower to appear here than on the main lock.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _tryBiometrics();
      });
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final label = key.keyLabel;
    if (label.length == 1) {
      final code = label.codeUnitAt(0);
      if (code >= 48 && code <= 57) {
        if (event is! KeyRepeatEvent) _onDigit(label);
        return KeyEventResult.handled;
      }
    }
    if (key == LogicalKeyboardKey.backspace ||
        key == LogicalKeyboardKey.delete) {
      _onDelete();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _onDigit(String digit) {
    if (_pin.length >= 4) return;
    setState(() {
      _pin += digit;
      _error = '';
    });
    if (_pin.length == 4) {
      Future.delayed(const Duration(milliseconds: 80), _onPinComplete);
    }
  }

  void _onDelete() {
    if (_pin.isEmpty) return;
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
    });
  }

  Future<void> _succeed() async {
    HapticFeedback.mediumImpact();
    setState(() => _success = true);
    // Long enough for the screen's fly-up launch (see PinRevealSlot) to read
    // clearly before we pop this screen.
    await Future.delayed(const Duration(milliseconds: 380));
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  void _fail(String message, {bool resetConfirm = false}) {
    HapticFeedback.heavyImpact();
    setState(() => _error = message);
    _shakeController
      ..reset()
      ..forward();
    Future.delayed(const Duration(milliseconds: 550), () {
      if (!mounted) return;
      setState(() {
        _pin = '';
        if (resetConfirm) {
          _firstPin = '';
          _isConfirming = false;
        }
      });
    });
  }

  Future<void> _onPinComplete() async {
    if (widget.mode == PinDialogMode.set) {
      if (!_isConfirming) {
        setState(() {
          _firstPin = _pin;
          _pin = '';
          _isConfirming = true;
        });
      } else {
        if (_pin == _firstPin) {
          await LockManager.setPin(widget.chatId, _pin);
          if (mounted) await _succeed();
        } else {
          if (!mounted) return;
          _fail(AppLocalizations.of(context).pinScreenMismatchError,
              resetConfirm: true);
        }
      }
    } else {
      if (LockManager.verifyPin(widget.chatId, _pin)) {
        LockManager.sessionUnlock(widget.chatId);
        await _succeed();
      } else {
        _fail(AppLocalizations.of(context).pinScreenIncorrectError);
      }
    }
  }

  Future<void> _tryBiometrics() async {
    final ok = await LockManager.authenticateWithBiometrics();
    if (ok && mounted) {
      LockManager.sessionUnlock(widget.chatId);
      await _succeed();
    }
  }

  // Per-dot phase-shifted decaying wave: dot i starts its shake a little
  // after dot i-1, so the row ripples left-to-right instead of jerking as a
  // single rigid block.
  double _dotShakeOffset(double t, int index) {
    const perDotDelay = 0.07;
    final local = (t - index * perDotDelay).clamp(0.0, 1.0);
    if (local <= 0) return 0;
    final decay = 1 - local;
    return math.sin(local * math.pi * 5) * 9 * decay;
  }

  String get _title {
    final l = AppLocalizations.of(context);
    if (widget.mode == PinDialogMode.set) {
      return _isConfirming ? l.pinScreenConfirmTitle : l.pinScreenSetTitle;
    }
    return l.pinScreenEnterTitle;
  }

  String get _subtitle {
    final l = AppLocalizations.of(context);
    if (widget.mode == PinDialogMode.set) {
      return _isConfirming
          ? l.pinScreenReenterSubtitle
          : l.pinScreenChooseChatSubtitle;
    }
    return l.pinScreenUnlockSubtitle;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    return Focus(
      focusNode: _focusNode,
      autofocus: _isDesktop,
      onKeyEvent: _isDesktop ? _handleKeyEvent : null,
      child: Scaffold(
        backgroundColor: cs.surface,
        body: SafeArea(
          child: Column(
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8, right: 8),
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text(l.cancel),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        PinRevealSlot(
                          index: 0,
                          exit: _success,
                          child: Builder(builder: (context) {
                            final lockColor = _error.isNotEmpty
                                ? Colors.red.shade400
                                : (_success
                                    ? Colors.green.shade400
                                    : cs.primary);
                            return AnimatedSwitcher(
                              duration: const Duration(milliseconds: 220),
                              child: Icon(Icons.lock_rounded,
                                  key: ValueKey(lockColor),
                                  size: 48,
                                  color: lockColor),
                            );
                          }),
                        ),
                        const SizedBox(height: 24),
                        PinRevealSlot(
                          index: 1,
                          exit: _success,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            child: Text(
                              _title,
                              key: ValueKey(_title),
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                                color: cs.onSurface,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        PinRevealSlot(
                          index: 2,
                          exit: _success,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            child: _error.isNotEmpty
                                ? Text(
                                    _error,
                                    key: const ValueKey('error'),
                                    style: const TextStyle(
                                        color: Colors.red, fontSize: 13),
                                  )
                                : Text(
                                    _subtitle,
                                    key: ValueKey(_subtitle),
                                    style: TextStyle(
                                      fontSize: 14,
                                      color:
                                          cs.onSurface.withValues(alpha: 0.6),
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 40),
                        PinRevealSlot(
                          index: 3,
                          exit: _success,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(4, (i) {
                              final filled = i < _pin.length;
                              final dotColor = _error.isNotEmpty
                                  ? Colors.red.shade400
                                  : (_success
                                      ? Colors.green.shade400
                                      : cs.primary);
                              return AnimatedBuilder(
                                animation: _shakeController,
                                builder: (_, child) => Transform.translate(
                                  offset: Offset(
                                      _dotShakeOffset(
                                          _shakeController.value, i),
                                      0),
                                  child: child,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10),
                                  child: PinDot(
                                    filled: filled,
                                    color: dotColor,
                                    emptyBorderColor: cs.outline,
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                        const SizedBox(height: 48),
                        _buildNumpad(cs),
                        if (_biometricsAvailable &&
                            widget.mode == PinDialogMode.verify) ...[
                          const SizedBox(height: 16),
                          PinRevealSlot(
                            index: 15,
                            exit: _success,
                            child: TextButton.icon(
                              onPressed: _tryBiometrics,
                              icon: const Icon(Icons.fingerprint_rounded,
                                  size: 22),
                              label: Text(l.useBiometrics),
                              style: TextButton.styleFrom(
                                foregroundColor: cs.primary,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
    );
  }

  // Indices 4-14: continues the whole-screen reveal order after the lock
  // icon (0), title (1), subtitle (2) and dot row (3) — see PinRevealSlot.
  Widget _buildNumpad(ColorScheme cs) {
    return Column(
      children: [
        _buildNumRow(['1', '2', '3'], cs, 4),
        const SizedBox(height: 12),
        _buildNumRow(['4', '5', '6'], cs, 7),
        const SizedBox(height: 12),
        _buildNumRow(['7', '8', '9'], cs, 10),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 80),
            const SizedBox(width: 12),
            _buildDigitKey('0', cs, 13),
            const SizedBox(width: 12),
            _buildDeleteKey(cs, 14),
          ],
        ),
      ],
    );
  }

  Widget _buildNumRow(List<String> digits, ColorScheme cs, int startIndex) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: digits
          .asMap()
          .entries
          .map((e) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: _buildDigitKey(e.value, cs, startIndex + e.key),
              ))
          .toList(),
    );
  }

  Widget _buildDigitKey(String digit, ColorScheme cs, int index) {
    return PinRevealSlot(
      index: index,
      exit: _success,
      child: PinKey(
        onTap: () => _onDigit(digit),
        background: cs.surfaceContainerHighest.withValues(alpha: 0.55),
        pressedBackground: cs.surfaceContainerHighest.withValues(alpha: 0.85),
        child: Text(
          digit,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w500,
            color: cs.onSurface,
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteKey(ColorScheme cs, int index) {
    return PinRevealSlot(
      index: index,
      exit: _success,
      child: PinKey(
        onTap: _onDelete,
        background: Colors.transparent,
        pressedBackground: cs.onSurface.withValues(alpha: 0.08),
        child: Icon(
          Icons.backspace_outlined,
          color: cs.onSurface,
          size: 24,
        ),
      ),
    );
  }
}
