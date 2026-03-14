// lib/screens/pin_code_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey, KeyDownEvent, KeyRepeatEvent;
import '../managers/settings_manager.dart';

bool get _isDesktop =>
    !const bool.fromEnvironment('dart.library.html') &&
    (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

class PinCodeScreen extends StatefulWidget {
  final bool isSetup;
  final VoidCallback? onSuccess;
  final ValueChanged<String>? onPinSet;
  final VoidCallback? onCancel;
  final String? headerText;
  
  final VoidCallback? onBiometric;

  const PinCodeScreen.verify({
    Key? key,
    required VoidCallback this.onSuccess,
    this.onBiometric,
  })  : isSetup = false,
        onPinSet = null,
        onCancel = null,
        headerText = null,
        super(key: key);

  const PinCodeScreen.setup({
    Key? key,
    required ValueChanged<String> this.onPinSet,
    required VoidCallback this.onCancel,
  })  : isSetup = true,
        onSuccess = null,
        onBiometric = null,
        headerText = null,
        super(key: key);

  const PinCodeScreen.disable({
    Key? key,
    required VoidCallback this.onSuccess,
    required VoidCallback this.onCancel,
  })  : isSetup = false,
        onPinSet = null,
        onBiometric = null,
        headerText = 'Enter current PIN to disable',
        super(key: key);

  @override
  State<PinCodeScreen> createState() => _PinCodeScreenState();
}

class _PinCodeScreenState extends State<PinCodeScreen>
    with SingleTickerProviderStateMixin {
  String _pin = '';
  String _firstPin = '';
  bool _isConfirming = false;
  String _error = '';

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
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _shakeController.dispose();
    super.dispose();
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
        
        if (event is! KeyRepeatEvent) {
          _onDigit(label);
        }
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

  Future<void> _onPinComplete() async {
    if (widget.isSetup) {
      if (!_isConfirming) {
        setState(() {
          _firstPin = _pin;
          _pin = '';
          _isConfirming = true;
        });
      } else {
        if (_pin == _firstPin) {
          widget.onPinSet?.call(_pin);
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
      final stored = await SettingsManager.getPin();
      if (_pin == stored) {
        widget.onSuccess?.call();
      } else {
        _shake();
        setState(() {
          _pin = '';
          _error = 'Incorrect PIN';
        });
      }
    }
  }

  void _shake() {
    _shakeController.reset();
    _shakeController.forward();
  }

  String get _title {
    if (widget.headerText != null) return widget.headerText!;
    if (widget.isSetup) return _isConfirming ? 'Confirm PIN' : 'Set PIN';
    return 'Enter PIN';
  }

  String get _subtitle {
    if (widget.headerText != null) return 'Enter your 4-digit PIN';
    if (widget.isSetup) {
      return _isConfirming
          ? 'Re-enter your PIN to confirm'
          : 'Choose a 4-digit PIN';
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
            if (widget.onCancel != null)
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8, right: 8),
                  child: TextButton(
                    onPressed: widget.onCancel,
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
                              color: filled ? cs.primary : Colors.transparent,
                              border: Border.all(
                                color:
                                    filled ? cs.primary : cs.outline,
                                width: 2,
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 48),
                    _buildNumpad(cs),
                    if (widget.onBiometric != null) ...[
                      const SizedBox(height: 16),
                      TextButton.icon(
                        onPressed: widget.onBiometric,
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
          .map(
            (d) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: _buildDigitKey(d, cs),
            ),
          )
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