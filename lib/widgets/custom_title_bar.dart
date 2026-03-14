// lib/widgets/custom_title_bar.dart
import 'package:ONYX/globals.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

class CustomTitleBar extends StatelessWidget {
  const CustomTitleBar({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onPanStart: (details) {
        windowManager.startDragging();
      },
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(12),
            topRight: Radius.circular(12),
          ),
        ),
        child: Row(
          children: [
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.minimize, size: 18),
              onPressed: () => windowManager.minimize(),
            ),
            IconButton(
              icon: const Icon(Icons.crop_square, size: 18),
              onPressed: () async {
                if (await windowManager.isMaximized()) {
                  await windowManager.unmaximize();
                } else {
                  await windowManager.maximize();
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: () async {
                
                try {
                  
                  rootScreenKey.currentState?.sendPresence('offline');
                } catch (e) { debugPrint('[err] $e'); }
                
                await Future.delayed(const Duration(milliseconds: 250));
                await windowManager.close();
              },
            ),
          ],
        ),
      ),
    );
  }
}