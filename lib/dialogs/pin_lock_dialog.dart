import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show LogicalKeyboardKey, KeyDownEvent, KeyRepeatEvent;
import '../managers/lock_manager.dart';

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
    with SingleTickerProviderStateMixin {
  String _pin = '';
  String _firstPin = '';
  bool _isConfirming = false;
  String _error = '';
  bool _biometricsAvailable = false;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 10.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: -10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: -6.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -6.0, end: 0.0), weight: 1),
    ]).animate(_shakeController);

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
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) _tryBiometrics();
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
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
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
          if (mounted) Navigator.of(context).pop(true);
        } else {
          _shake();
          setState(() {
            _pin = '';
            _firstPin = '';
            _isConfirming = false;
            _error = 'PINs do not match. Try again.';
          });
        }
      }
    } else {
      if (LockManager.verifyPin(widget.chatId, _pin)) {
        LockManager.sessionUnlock(widget.chatId);
        if (mounted) Navigator.of(context).pop(true);
      } else {
        _shake();
        setState(() {
          _pin = '';
          _error = 'Incorrect PIN';
        });
      }
    }
  }

  Future<void> _tryBiometrics() async {
    final ok = await LockManager.authenticateWithBiometrics();
    if (ok && mounted) Navigator.of(context).pop(true);
  }

  void _shake() {
    _shakeController.reset();
    _shakeController.forward();
  }

  String get _title {
    if (widget.mode == PinDialogMode.set) {
      return _isConfirming ? 'Confirm PIN' : 'Set PIN';
    }
    return 'Enter PIN';
  }

  String get _subtitle {
    if (widget.mode == PinDialogMode.set) {
      return _isConfirming
          ? 'Re-enter your PIN to confirm'
          : 'Choose a 4-digit PIN for this chat';
    }
    return 'Enter your 4-digit PIN to unlock';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
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
                    child: const Text('Cancel'),
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_rounded, size: 48, color: cs.primary),
                      const SizedBox(height: 24),
                      Text(
                        _title,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_error.isNotEmpty)
                        Text(
                          _error,
                          style:
                              const TextStyle(color: Colors.red, fontSize: 13),
                        )
                      else
                        Text(
                          _subtitle,
                          style: TextStyle(
                            fontSize: 14,
                            color: cs.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      const SizedBox(height: 40),
                      AnimatedBuilder(
                        animation: _shakeAnimation,
                        builder: (_, child) => Transform.translate(
                          offset: Offset(_shakeAnimation.value, 0),
                          child: child,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(4, (i) {
                            final filled = i < _pin.length;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 10),
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: filled
                                    ? cs.primary
                                    : Colors.transparent,
                                border: Border.all(
                                  color: filled ? cs.primary : cs.outline,
                                  width: 2,
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
                        TextButton.icon(
                          onPressed: _tryBiometrics,
                          icon: const Icon(Icons.fingerprint_rounded, size: 22),
                          label: const Text('Use biometrics'),
                          style: TextButton.styleFrom(
                            foregroundColor: cs.primary,
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

  Widget _buildNumpad(ColorScheme cs) {
    return Column(
      children: [
        _buildNumRow(['1', '2', '3'], cs),
        const SizedBox(height: 12),
        _buildNumRow(['4', '5', '6'], cs),
        const SizedBox(height: 12),
        _buildNumRow(['7', '8', '9'], cs),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 80),
            const SizedBox(width: 12),
            _buildDigitKey('0', cs),
            const SizedBox(width: 12),
            _buildDeleteKey(cs),
          ],
        ),
      ],
    );
  }

  Widget _buildNumRow(List<String> digits, ColorScheme cs) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: digits
          .map((d) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: _buildDigitKey(d, cs),
              ))
          .toList(),
    );
  }

  Widget _buildDigitKey(String digit, ColorScheme cs) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(40),
        onTap: () => _onDigit(digit),
        child: Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
          ),
          alignment: Alignment.center,
          child: Text(
            digit,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w500,
              color: cs.onSurface,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteKey(ColorScheme cs) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(40),
        onTap: _onDelete,
        child: Container(
          width: 68,
          height: 68,
          alignment: Alignment.center,
          child: Icon(
            Icons.backspace_outlined,
            color: cs.onSurface,
            size: 24,
          ),
        ),
      ),
    );
  }
}
