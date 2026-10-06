// lib/screens/pin_code_screen.dart
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
import '../managers/settings_manager.dart';
import '../managers/decoy_manager.dart';
import '../managers/fallback_storage.dart';
import '../widgets/pin_keypad.dart';

bool get _isDesktop =>
    !const bool.fromEnvironment('dart.library.html') &&
    (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

class PinCodeScreen extends StatefulWidget {
  final bool isSetup;
  final VoidCallback? onSuccess;
  final VoidCallback? onFakePin;
  final ValueChanged<String>? onPinSet;
  final VoidCallback? onCancel;
  final bool isDisableMode;

  final VoidCallback? onBiometric;

  /// [onCancel]: when given, a "Cancel" button appears in the top right (and
  /// the back gesture works) -- for a PIN asked before a one-off action such
  /// as switching accounts. Leave it out for the app's own lock screen, which
  /// must not be dismissible.
  const PinCodeScreen.verify({
    Key? key,
    required VoidCallback this.onSuccess,
    this.onFakePin,
    this.onBiometric,
    this.onCancel,
  })  : isSetup = false,
        onPinSet = null,
        isDisableMode = false,
        super(key: key);

  const PinCodeScreen.setup({
    Key? key,
    required ValueChanged<String> this.onPinSet,
    required VoidCallback this.onCancel,
  })  : isSetup = true,
        onSuccess = null,
        onFakePin = null,
        onBiometric = null,
        isDisableMode = false,
        super(key: key);

  const PinCodeScreen.disable({
    Key? key,
    required VoidCallback this.onSuccess,
    required VoidCallback this.onCancel,
  })  : isSetup = false,
        onFakePin = null,
        onPinSet = null,
        onBiometric = null,
        isDisableMode = true,
        super(key: key);

  @override
  State<PinCodeScreen> createState() => _PinCodeScreenState();
}

class _PinCodeScreenState extends State<PinCodeScreen>
    with TickerProviderStateMixin {
  String _pin = '';
  String _firstPin = '';
  bool _isConfirming = false;
  String _error = '';
  // True for the brief green "confirmed" flash between a correct PIN and the
  // success callback firing — gives the fluid/playful design its positive
  // feedback beat instead of jumping straight to the next screen.
  bool _success = false;

  // Drives the per-dot wave shake on a wrong PIN (see _dotShakeOffset). No
  // longer a single TweenSequence shared by the whole row — each dot samples
  // this at a phase-shifted offset so the shake reads as a wave instead of
  // the whole row jerking in unison.
  late AnimationController _shakeController;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
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

  /// Brief green confirmation flash before handing off to [cb] — the
  /// "positive" half of the fluid/playful feedback pair (see [_fail] for the
  /// negative half). Safe to await even when [cb] itself unmounts this
  /// screen, since the delay always runs first.
  Future<void> _succeed(VoidCallback? cb) async {
    if (cb == null) return;
    HapticFeedback.mediumImpact();
    setState(() => _success = true);
    // Long enough for the screen's fly-up launch (see PinRevealSlot) to read
    // clearly before we hand off and this screen goes away.
    await Future.delayed(const Duration(milliseconds: 380));
    if (!mounted) return;
    cb();
  }

  /// Keeps the (now-red) filled dots on screen through the wave-shake instead
  /// of clearing them immediately, so the shake actually reads as "these 4
  /// digits were wrong" rather than shaking an already-empty row. Clears the
  /// PIN — and, for the setup-mismatch case, resets the confirm step — only
  /// after the animation has had time to play.
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
    if (widget.isSetup) {
      if (!_isConfirming) {
        setState(() {
          _firstPin = _pin;
          _pin = '';
          _isConfirming = true;
        });
      } else {
        if (_pin == _firstPin) {
          await _succeed(() => widget.onPinSet?.call(_pin));
        } else {
          _fail(AppLocalizations.of(context).pinScreenMismatchError,
              resetConfirm: true);
        }
      }
    } else {
      final isDesktop = !kIsWeb &&
          (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

      if (isDesktop) {
        // Ensure FallbackStorage knows its state before we check isLocked.
        await FallbackStorage.main.initialize();

        if (FallbackStorage.main.isLocked) {
          // v3, locked at startup: PIN is the decryption key.
          if (await FallbackStorage.main.unlockWithPin(_pin)) {
            // Backfill the biometric PIN stash for users who enabled biometrics
            // before it was wired up (or after a keychain reset).
            if (SettingsManager.biometricEnabled.value) {
              await SettingsManager.storeBiometricPin(_pin);
            }
            await _succeed(widget.onSuccess);
            return;
          }
          if (widget.onFakePin != null && await DecoyManager.isEnabled()) {
            if (await FallbackStorage.decoy.unlockWithPin(_pin)) {
              await _succeed(widget.onFakePin);
              return;
            }
          }
          if (!mounted) return;
          _fail(AppLocalizations.of(context).pinScreenIncorrectError);
          return;
        }

        if (FallbackStorage.main.isV3) {
          // v3, already unlocked mid-session (account switch, disable PIN, etc.).
          if (FallbackStorage.main.verifyPin(_pin)) {
            await _succeed(widget.onSuccess);
            return;
          }
          if (widget.onFakePin != null && await DecoyManager.isEnabled()) {
            if (FallbackStorage.decoy.verifyPin(_pin)) {
              await _succeed(widget.onFakePin);
              return;
            }
          }
          if (!mounted) return;
          _fail(AppLocalizations.of(context).pinScreenIncorrectError);
          return;
        }

        // v2 mode: compare with stored PIN, then migrate to v3 on success.
        final stored = await SettingsManager.getPin();
        if (_pin == stored) {
          await FallbackStorage.main.migrateToV3(_pin);
          await _succeed(widget.onSuccess);
          return;
        }
        if (widget.onFakePin != null && await DecoyManager.isEnabled()) {
          final fakeStored = await DecoyManager.getPin();
          if (fakeStored != null && _pin == fakeStored) {
            await FallbackStorage.decoy.createWithPin(_pin);
            await _succeed(widget.onFakePin);
            return;
          }
        }
        if (!mounted) return;
        _fail(AppLocalizations.of(context).pinScreenIncorrectError);
        return;
      }

      // Mobile: unchanged flow (platform keychain handles security).
      final stored = await SettingsManager.getPin();
      if (_pin == stored) {
        await _succeed(widget.onSuccess);
        return;
      }
      if (widget.onFakePin != null && await DecoyManager.isEnabled()) {
        final fakeStored = await DecoyManager.getPin();
        if (fakeStored != null && _pin == fakeStored) {
          await _succeed(widget.onFakePin);
          return;
        }
      }
      if (!mounted) return;
      _fail(AppLocalizations.of(context).pinScreenIncorrectError);
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
    if (widget.isDisableMode) return l.pinScreenDisableHeader;
    if (widget.isSetup) {
      return _isConfirming ? l.pinScreenConfirmTitle : l.pinScreenSetTitle;
    }
    return l.pinScreenEnterTitle;
  }

  String get _subtitle {
    final l = AppLocalizations.of(context);
    if (widget.isDisableMode) return l.pinScreenGenericSubtitle;
    if (widget.isSetup) {
      return _isConfirming
          ? l.pinScreenReenterSubtitle
          : l.pinScreenChooseSubtitle;
    }
    return l.pinScreenUnlockSubtitle;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    // Lock-verification screens (no Cancel button) must never be dismissible
    // via the Android back button/gesture — that would bypass PIN entry
    // entirely and expose the app's content.
    return PopScope(
      canPop: widget.onCancel != null,
      child: Focus(
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
                            : (_success ? Colors.green.shade400 : cs.primary);
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
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            _title,
                            key: ValueKey(_title),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              color: cs.onSurface,
                            ),
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
                                  color: cs.onSurface.withValues(alpha: 0.6),
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
                                  _dotShakeOffset(_shakeController.value, i),
                                  0),
                              child: child,
                            ),
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10),
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
                    if (widget.onBiometric != null) ...[
                      const SizedBox(height: 16),
                      PinRevealSlot(
                        index: 15,
                        exit: _success,
                        child: TextButton.icon(
                          onPressed: widget.onBiometric,
                          icon:
                              const Icon(Icons.fingerprint_rounded, size: 22),
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
          .map(
            (e) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: _buildDigitKey(e.value, cs, startIndex + e.key),
            ),
          )
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
