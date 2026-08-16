// lib/widgets/onyx_reminder_picker.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../l10n/app_localizations.dart';
import 'onyx_dialog.dart';

/// Asks the user for a future date + time. The default flow is plain
/// keyboard HH:MM entry (no scrolling wheels), prefilled with "now + 5
/// minutes" — if the entered time has already passed today, it silently
/// rolls to tomorrow, same as a phone alarm clock. An optional "choose
/// date" step (compact calendar picker) lets the user target a specific
/// future day instead of relying on that auto-rollover.
Future<DateTime?> showOnyxReminderPicker(BuildContext context) {
  return showOnyxDialog<DateTime>(
    context: context,
    builder: (ctx) => const _ReminderTimeDialog(),
  );
}

class _ReminderTimeDialog extends StatefulWidget {
  const _ReminderTimeDialog();

  @override
  State<_ReminderTimeDialog> createState() => _ReminderTimeDialogState();
}

class _ReminderTimeDialogState extends State<_ReminderTimeDialog> {
  late final DateTime _now;
  late final TextEditingController _hourCtrl;
  late final TextEditingController _minuteCtrl;
  final FocusNode _hourFocus = FocusNode();
  final FocusNode _minuteFocus = FocusNode();

  // Set only via the "choose date" calendar picker below — while null, a
  // submitted time is assumed to mean "today, or tomorrow if that's already
  // passed" (see _submit).
  DateTime? _pickedDate;
  String? _error;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    final def = _now.add(const Duration(minutes: 5));
    _hourCtrl =
        TextEditingController(text: def.hour.toString().padLeft(2, '0'));
    _minuteCtrl =
        TextEditingController(text: def.minute.toString().padLeft(2, '0'));
  }

  @override
  void dispose() {
    _hourCtrl.dispose();
    _minuteCtrl.dispose();
    _hourFocus.dispose();
    _minuteFocus.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final l = AppLocalizations.of(context);
    final today = DateTime(_now.year, _now.month, _now.day);
    final date = await showDatePicker(
      context: context,
      initialDate: _pickedDate ?? today,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
      helpText: l.reminderPickDate,
      // Lock to the calendar grid — calendarOnly also removes the header's
      // pencil icon that toggles to manual text-entry mode.
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      // Match the app's own dialog chrome (OnyxDialogShell: rounded-28 card,
      // tinted header) instead of the stock Material date picker look.
      builder: (ctx, child) {
        final colorScheme = Theme.of(ctx).colorScheme;
        return Theme(
          data: Theme.of(ctx).copyWith(
            dialogTheme: DialogThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
            datePickerTheme: DatePickerThemeData(
              backgroundColor: colorScheme.surface,
              headerBackgroundColor: colorScheme.primary.withValues(alpha: 0.06),
              headerForegroundColor: colorScheme.onSurface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (date != null && mounted) {
      setState(() {
        _pickedDate = date;
        _error = null;
      });
    }
  }

  void _clearDate() {
    setState(() {
      _pickedDate = null;
      _error = null;
    });
  }

  void _submit() {
    final l = AppLocalizations.of(context);
    final hour = int.tryParse(_hourCtrl.text);
    final minute = int.tryParse(_minuteCtrl.text);
    if (hour == null || minute == null || hour > 23 || minute > 59) {
      setState(() => _error = l.reminderInvalidTime);
      return;
    }

    DateTime result;
    if (_pickedDate != null) {
      // An explicit date was chosen — respect it exactly, including
      // rejecting a time that's already passed on that day (silently
      // rolling to the next day, like the auto-date branch does, would be
      // surprising once the user has deliberately picked a day).
      result = DateTime(
          _pickedDate!.year, _pickedDate!.month, _pickedDate!.day, hour, minute);
      if (!result.isAfter(_now)) {
        setState(() => _error = l.reminderPastTime);
        return;
      }
    } else {
      final today = DateTime(_now.year, _now.month, _now.day, hour, minute);
      result =
          today.isAfter(_now) ? today : today.add(const Duration(days: 1));
    }

    Navigator.of(context).pop(result);
  }

  String _formatPickedDate(DateTime d) {
    final l = AppLocalizations.of(context);
    final today = DateTime(_now.year, _now.month, _now.day);
    final diff = DateTime(d.year, d.month, d.day).difference(today).inDays;
    if (diff == 0) return l.reminderDateToday;
    if (diff == 1) return l.reminderDateTomorrow;
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '$dd.$mm.${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);

    return OnyxDialogShell(
      maxWidth: 380,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OnyxDialogHeader(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.alarm_add_rounded,
                  size: 20, color: colorScheme.primary),
            ),
            title: Text(
              l.setReminder,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            onClose: () => Navigator.of(context).pop(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TimeField(
                  controller: _hourCtrl,
                  focusNode: _hourFocus,
                  label: l.reminderHourLabel,
                  maxValue: 23,
                  autofocus: true,
                  onFilled: () => _minuteFocus.requestFocus(),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    ':',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ),
                _TimeField(
                  controller: _minuteCtrl,
                  focusNode: _minuteFocus,
                  label: l.reminderMinuteLabel,
                  maxValue: 59,
                  onFilled: () => _minuteFocus.unfocus(),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: Center(
              child: _pickedDate == null
                  ? TextButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.event_rounded, size: 18),
                      label: Text(l.reminderPickDate),
                    )
                  : InputChip(
                      avatar: const Icon(Icons.event_rounded, size: 18),
                      label: Text(_formatPickedDate(_pickedDate!)),
                      onPressed: _pickDate,
                      onDeleted: _clearDate,
                    ),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: colorScheme.error),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton(
                  onPressed: _submit,
                  style: FilledButton.styleFrom(
                    padding: kOnyxDialogButtonPadding,
                    shape: kOnyxDialogButtonShape,
                  ),
                  child: Text(l.setReminder),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    padding: kOnyxDialogButtonPadding,
                    shape: kOnyxDialogButtonShape,
                  ),
                  child: Text(l.cancel),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A single HH or MM box: centered big digits, digit-only keyboard, and an
/// [onFilled] callback (used to auto-advance focus from hour to minute) once
/// two digits have been typed.
class _TimeField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String label;
  final int maxValue;
  final bool autofocus;
  final VoidCallback onFilled;

  const _TimeField({
    required this.controller,
    required this.focusNode,
    required this.label,
    required this.maxValue,
    required this.onFilled,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        SizedBox(
          width: 76,
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            autofocus: autofocus,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 2,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(2),
              _MaxValueTextInputFormatter(maxValue),
            ],
            decoration: InputDecoration(
              counterText: '',
              filled: true,
              fillColor: colorScheme.onSurface.withValues(alpha: 0.05),
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (value) {
              if (value.length == 2) onFilled();
            },
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: colorScheme.onSurface.withValues(alpha: 0.55),
          ),
        ),
      ],
    );
  }
}

/// Rejects a keystroke that would push the field's numeric value above
/// [maxValue] (e.g. typing "9" after "2" in the hour field) — keeps the
/// field always holding a valid hour/minute rather than letting the user
/// land on "29" and only catching it at submit time.
class _MaxValueTextInputFormatter extends TextInputFormatter {
  final int maxValue;
  _MaxValueTextInputFormatter(this.maxValue);

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;
    final n = int.tryParse(newValue.text);
    if (n == null || n > maxValue) return oldValue;
    return newValue;
  }
}
