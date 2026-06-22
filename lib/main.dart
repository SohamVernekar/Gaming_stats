import 'package:flutter/material.dart';
import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';

import 'overlay_settings.dart';
import 'ui_screens.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  const windowOptions = WindowOptions(
    size: Size(450, 620),
    center: true,
    titleBarStyle: TitleBarStyle.normal,
    alwaysOnTop: false,
    skipTaskbar: false,
    backgroundColor: Colors.transparent,
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.setBackgroundColor(Colors.transparent);
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final OverlaySettings _settings = OverlaySettings();
  final SystemTray _systemTray = SystemTray();

  @override
  void initState() {
    super.initState();
    initSystemTray();
  }

  Future<void> initSystemTray() async {
    try {
      await _systemTray.initSystemTray(
        title: "Gaming Stats",
        iconPath: "assets/app_icon.ico",
      );

      final menu = Menu();
      await menu.buildFrom([
        MenuItemLabel(
          label: 'Unlock & Settings Menu',
          onClicked: (_) => _settings.toggleGhostMode(false),
        ),
        MenuSeparator(),
        MenuItemLabel(
          label: 'Exit App',
          onClicked: (_) => windowManager.close(),
        ),
      ]);

      await _systemTray.setContextMenu(menu);
      _systemTray.registerSystemTrayEventHandler((eventName) {
        if (eventName == kSystemTrayEventClick) {
          _settings.toggleGhostMode(false);
        }
      });
    } catch (_) {
      // Keep running even if tray icon fails to initialize.
    }
  }

  @override
  void dispose() {
    _settings.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _settings,
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData.dark(),
          home: Scaffold(
            backgroundColor: Colors.transparent,
            body: _settings.isGhostMode
                ? Align(
                    alignment: Alignment.topLeft,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: StatsOverlay(settings: _settings),
                    ),
                  )
                : ColoredBox(
                    color: const Color(0xFF0F0F13), // Match settings background
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: SafeArea(
                        child: SettingsPanel(settings: _settings),
                      ),
                    ),
                  ),
          ),
        );
      },
    );
  }
}
