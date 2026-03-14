// lib/managers/onyx_tray_manager.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'package:path/path.dart' as path;
import '../globals.dart';

class OnyxTrayManager with TrayListener {
  static final OnyxTrayManager _instance = OnyxTrayManager._internal();
  factory OnyxTrayManager() => _instance;
  OnyxTrayManager._internal();

  bool _isInitialized = false;
  Function()? _onDisconnect;
  Function()? _onConnect;
  Future<void> Function()? _onBeforeClose;
  Function()? _onShowWindow;

  Future<void> initialize({
    Function()? onDisconnect,
    Function()? onConnect,
    Future<void> Function()? onBeforeClose,
    Function()? onShowWindow,
  }) async {
    if (_isInitialized) {
      debugPrint('[TrayManager] Already initialized, skipping');
      return;
    }

    debugPrint('[TrayManager] Starting initialization...');
    _onDisconnect = onDisconnect;
    _onConnect = onConnect;
    _onBeforeClose = onBeforeClose;
    _onShowWindow = onShowWindow;

    try {
      
      String iconPath;

      if (Platform.isWindows) {
        
        final exeDir = path.dirname(Platform.resolvedExecutable);
        final trayIconPath = path.join(exeDir, 'tray_icon.ico');

        debugPrint('[TrayManager] Executable dir: $exeDir');
        debugPrint('[TrayManager] Looking for icon at: $trayIconPath');

        final iconExists = await File(trayIconPath).exists();
        debugPrint('[TrayManager] Icon exists: $iconExists');

        if (iconExists) {
          iconPath = trayIconPath;
        } else {
          
          final assetPath = path.join(
              exeDir, 'data', 'flutter_assets', 'assets', 'tray_icon.ico');
          if (await File(assetPath).exists()) {
            debugPrint('[TrayManager] Using flutter_assets icon: $assetPath');
            iconPath = assetPath;
          } else {
            
            debugPrint('[TrayManager] Using exe icon as fallback');
            iconPath = Platform.resolvedExecutable;
          }
        }
      } else if (Platform.isMacOS) {
        iconPath = 'assets/tray_icon.png';
      } else {
        
        iconPath = 'assets/tray_icon.png';
      }

      debugPrint('[TrayManager] Setting tray icon: $iconPath');
      await trayManager.setIcon(iconPath);

      debugPrint('[TrayManager] Updating menu...');
      await _updateMenu();

      debugPrint('[TrayManager] Adding listener...');
      trayManager.addListener(this);

      _isInitialized = true;
      debugPrint('[TrayManager]  Initialized successfully');

      wsConnectedNotifier.addListener(_onConnectionStateChanged);
    } catch (e) {
      debugPrint('[TrayManager]  Failed to initialize: $e');
      debugPrint('[TrayManager] Stack trace: ${StackTrace.current}');
      
    }
  }

  void _onConnectionStateChanged() {
    final isConnected = wsConnectedNotifier.value;
    debugPrint('[TrayManager] Connection state changed: $isConnected');
    _updateMenu();
  }

  Future<void> _updateMenu() async {
    final isConnected = wsConnectedNotifier.value;
    debugPrint('[TrayManager] Updating menu - isConnected: $isConnected');

    await trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(
            key: 'open',
            label: 'Open',
          ),
          MenuItem.separator(),
          MenuItem(
            key: isConnected ? 'disconnect' : 'connect',
            label: isConnected ? 'Disconnect' : 'Connect',
          ),
          MenuItem.separator(),
          MenuItem(
            key: 'close',
            label: 'Close',
          ),
        ],
      ),
    );
    debugPrint('[TrayManager] Menu updated successfully');
  }

  Future<void> updateMenuAfterDisconnect() async {
    debugPrint('[TrayManager] Force updating menu after disconnect');
    
    await Future.delayed(const Duration(milliseconds: 100));
    await _updateMenu();
  }

  Future<void> showWindow() async {
    await windowManager.show();
    await windowManager.focus();
    debugPrint('[TrayManager] Window shown and focused');

    if (_onShowWindow != null) {
      debugPrint('[TrayManager] Calling onShowWindow to send online status...');
      try {
        _onShowWindow!();
      } catch (e) {
        debugPrint('[TrayManager] Failed to send online status: $e');
      }
    }
  }

  Future<void> hideToTray() async {
    await windowManager.hide();
    debugPrint('[TrayManager] Window hidden to tray');
  }

  Future<void> closeApp() async {
    debugPrint('[TrayManager] Closing application...');

    if (_onBeforeClose != null) {
      debugPrint('[TrayManager] Calling onBeforeClose to send offline status...');
      try {
        await _onBeforeClose!();
        await Future.delayed(const Duration(milliseconds: 200));
        debugPrint('[TrayManager] Offline status sent successfully');
      } catch (e) {
        debugPrint('[TrayManager] Failed to send offline status: $e');
      }
    }

    debugPrint('[TrayManager] Destroying window and exiting...');
    await windowManager.destroy();
    exit(0);
  }

  @override
  void onTrayIconMouseDown() {
    
    showWindow();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    debugPrint('[TrayManager] Menu item clicked: ${menuItem.key}');

    switch (menuItem.key) {
      case 'open':
        showWindow();
        break;

      case 'connect':
        if (_onConnect != null) {
          _onConnect!();
        }
        break;

      case 'disconnect':
        if (_onDisconnect != null) {
          _onDisconnect!();
        }
        break;

      case 'close':
        closeApp();
        break;

      default:
        debugPrint('[TrayManager] Unknown menu item: ${menuItem.key}');
    }
  }

  void dispose() {
    wsConnectedNotifier.removeListener(_onConnectionStateChanged);
    trayManager.removeListener(this);
    _isInitialized = false;
  }
}