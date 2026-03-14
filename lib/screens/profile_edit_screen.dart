import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../globals.dart';
import '../managers/account_manager.dart';
import '../managers/settings_manager.dart';

class ProfileEditScreen extends StatefulWidget {
  final String currentUsername;
  final String currentDisplayName;
  
  const ProfileEditScreen({
    Key? key,
    required this.currentUsername,
    required this.currentDisplayName,
  }) : super(key: key);

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  late final TextEditingController _displayNameCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _displayNameCtrl = TextEditingController(text: widget.currentDisplayName);
  }

  @override
  void dispose() {
    _displayNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveDisplayName() async {
    final newName = _displayNameCtrl.text.trim();
    if (newName.isEmpty || newName.length > 16) {
      rootScreenKey.currentState?.showSnack('Display name must be 1-16 characters');
      return;
    }

    setState(() => _saving = true);

    final token = await AccountManager.getToken(widget.currentUsername);
    if (token == null) {
      rootScreenKey.currentState?.showSnack('Not logged in');
      setState(() => _saving = false);
      return;
    }

    try {
      final res = await http.post(
        Uri.parse('$serverBase/profile/display_name'),
        headers: {
          'authorization': 'Bearer $token',
          'content-type': 'application/json',
        },
        body: jsonEncode({'display_name': newName}),
      );

      if (res.statusCode == 200) {
        
        rootScreenKey.currentState?.setState(() {
          rootScreenKey.currentState!.currentDisplayName = newName;
        });
        
        rootScreenKey.currentState?.showSnack(' Display name updated');
        Navigator.of(context).pop();
      } else {
        rootScreenKey.currentState?.showSnack(' Failed to update');
      }
    } catch (e) {
      rootScreenKey.currentState?.showSnack(' Network error: $e');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ValueListenableBuilder<double>(
      valueListenable: SettingsManager.elementOpacity,
      builder: (_, elemOpacity, __) {
        return ValueListenableBuilder<double>(
          valueListenable: SettingsManager.elementBrightness,
          builder: (context, brightness, child) {
            final baseColor = SettingsManager.getElementColor(
              colorScheme.surfaceContainerHighest,
              brightness,
            );
            return Scaffold(
              appBar: AppBar(
                title: const Text('Edit Profile'),
                backgroundColor: Colors.transparent,
                elevation: 0,
              ),
              body: Stack(
                children: [
                  
                  Positioned.fill(
                    child: ColoredBox(
                      color: baseColor.withValues(alpha: elemOpacity),
                    ),
                  ),
              
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: baseColor.withValues(alpha: 0.5 * elemOpacity),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.2 * elemOpacity),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '@${widget.currentUsername}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Your unique username (cannot be changed)',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurface.withValues(alpha: 0.6 * elemOpacity),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                Text(
                  'Display Name',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _displayNameCtrl,
                  maxLength: 16,
                  decoration: InputDecoration(
                    hintText: 'Enter your display name',
                    helperText: '1–16 characters, emoji and any language supported',
                    helperStyle: TextStyle(
                      fontSize: 11,
                      color: colorScheme.onSurface.withValues(alpha: 0.5 * elemOpacity),
                    ),
                    filled: true,
                    fillColor: baseColor.withValues(alpha: 0.3 * elemOpacity),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    counterStyle: TextStyle(
                      fontSize: 11,
                      color: colorScheme.onSurface.withValues(alpha: 0.5 * elemOpacity),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _saving ? null : _saveDisplayName,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Save', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
            );
          },
        );
      },
    );
  }
}