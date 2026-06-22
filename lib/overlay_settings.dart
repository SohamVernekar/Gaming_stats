import 'dart:async';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

class OverlaySettings extends ChangeNotifier {
  static const _channel = MethodChannel("gaming_stats/native_channel");

  static const _spKeyOffsetX = 'overlayOffsetX';
  static const _spKeyOffsetY = 'overlayOffsetY';
  static const _spKeyFontSize = 'overlayFontSize';
  static const _spKeyFontColor = 'overlayFontColor';
  static const _spKeyBgOpacity = 'overlayBgOpacity';
  static const _spKeyShowFPS = 'showFPS';
  static const _spKeyShowFrametime = 'showFrametime';
  static const _spKeyShowCPUUsage = 'showCPUUsage';
  static const _spKeyShowCPUTemp = 'showCPUTemp';
  static const _spKeyShowGPUUsage = 'showGPUUsage';
  static const _spKeyShowGPUTemp = 'showGPUTemp';
  static const _spKeyShowRAM = 'showRAM';
  static const _spKeyShowVRAM = 'showVRAM';
  static const _spKeyShowBattery = 'showBattery';
  static const _spKeyShowTime = 'showTime';
  static const _spKeyClearBackground = 'clearBackground';
  static const _spKeyAllowDrag = 'allowDragInGhostMode';

  // Configurable Options
  double fontSize = 14.0;
  Color fontColor = const Color(0xFF00FF00); // Neon Green
  double bgOpacity = 0.5;

  bool showFPS = true;
  bool showFrametime = true;
  bool showCPUUsage = true;
  bool showCPUTemp = true;
  bool showGPUUsage = true;
  bool showGPUTemp = true;
  bool showRAM = true;
  bool showVRAM = true;
  bool showBattery = true;
  bool showTime = true;
  bool clearBackground = false;
  bool allowDragInGhostMode = true;

  bool isGhostMode = false;
  Offset overlayOffset = const Offset(10, 10);

  // Live Stats Values
  String fpsCounter = "N/A";
  String frametime = "N/A";
  String cpuUsage = "N/A";
  String cpuTemp = "N/A";
  String gpuUsage = "N/A";
  String gpuTemp = "N/A";
  String ramUsage = "N/A";
  String vramUsage = "N/A";
  String currentTime = "00:00:00";
  int? currentBatteryLevel;

  final Battery _battery = Battery();
  Timer? _statsTimer;
  bool _isRefreshing = false;

  OverlaySettings({bool startTracking = true}) {
    _loadSettings().then((_) {
      if (startTracking) {
        _startLiveTracking();
      }
    });
  }

  Future<void> _loadSettings() async {
    final sp = await SharedPreferences.getInstance();
    
    // Position
    final x = sp.getDouble(_spKeyOffsetX);
    final y = sp.getDouble(_spKeyOffsetY);
    if (x != null && y != null) {
      overlayOffset = Offset(x, y);
    }

    // Text & Opacity
    fontSize = sp.getDouble(_spKeyFontSize) ?? 14.0;
    final colorVal = sp.getInt(_spKeyFontColor);
    if (colorVal != null) {
      fontColor = Color(colorVal);
    }
    bgOpacity = sp.getDouble(_spKeyBgOpacity) ?? 0.5;

    // Toggles
    showFPS = sp.getBool(_spKeyShowFPS) ?? true;
    showFrametime = sp.getBool(_spKeyShowFrametime) ?? true;
    showCPUUsage = sp.getBool(_spKeyShowCPUUsage) ?? true;
    showCPUTemp = sp.getBool(_spKeyShowCPUTemp) ?? true;
    showGPUUsage = sp.getBool(_spKeyShowGPUUsage) ?? true;
    showGPUTemp = sp.getBool(_spKeyShowGPUTemp) ?? true;
    showRAM = sp.getBool(_spKeyShowRAM) ?? true;
    showVRAM = sp.getBool(_spKeyShowVRAM) ?? true;
    showBattery = sp.getBool(_spKeyShowBattery) ?? true;
    showTime = sp.getBool(_spKeyShowTime) ?? true;
    clearBackground = sp.getBool(_spKeyClearBackground) ?? false;
    allowDragInGhostMode = sp.getBool(_spKeyAllowDrag) ?? true;

    notifyListeners();
  }

  Future<void> saveSettings() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setDouble(_spKeyFontSize, fontSize);
    await sp.setInt(_spKeyFontColor, fontColor.value);
    await sp.setDouble(_spKeyBgOpacity, bgOpacity);
    await sp.setBool(_spKeyShowFPS, showFPS);
    await sp.setBool(_spKeyShowFrametime, showFrametime);
    await sp.setBool(_spKeyShowCPUUsage, showCPUUsage);
    await sp.setBool(_spKeyShowCPUTemp, showCPUTemp);
    await sp.setBool(_spKeyShowGPUUsage, showGPUUsage);
    await sp.setBool(_spKeyShowGPUTemp, showGPUTemp);
    await sp.setBool(_spKeyShowRAM, showRAM);
    await sp.setBool(_spKeyShowVRAM, showVRAM);
    await sp.setBool(_spKeyShowBattery, showBattery);
    await sp.setBool(_spKeyShowTime, showTime);
    await sp.setBool(_spKeyClearBackground, clearBackground);
    await sp.setBool(_spKeyAllowDrag, allowDragInGhostMode);
  }

  Future<void> saveOverlayPosition(Offset offset) async {
    overlayOffset = offset;
    final sp = await SharedPreferences.getInstance();
    await sp.setDouble(_spKeyOffsetX, offset.dx);
    await sp.setDouble(_spKeyOffsetY, offset.dy);
  }

  void _startLiveTracking() {
    unawaited(_refreshStats());
    _statsTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      unawaited(_refreshStats());
    });
  }

  Future<void> _refreshStats() async {
    if (_isRefreshing) return;
    _isRefreshing = true;

    try {
      // Get clock time
      final now = DateTime.now();
      currentTime = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";

      // Get battery status if enabled
      if (showBattery) {
        try {
          currentBatteryLevel = await _battery.batteryLevel;
        } catch (_) {
          currentBatteryLevel = null;
        }
      }

      // Query native telemetry map
      final dynamic stats = await _channel.invokeMethod("getSystemStats");
      if (stats is Map) {
        // CPU
        final cpuUseVal = stats["cpu_usage"];
        if (cpuUseVal is double && cpuUseVal >= 0) {
          cpuUsage = "${cpuUseVal.round()}%";
        }
        final cpuTempVal = stats["cpu_temp"];
        if (cpuTempVal is double) {
          cpuTemp = cpuTempVal >= 0 ? "${cpuTempVal.round()}°C" : "N/A";
        }

        // RAM
        final ramUsedVal = stats["ram_used"];
        final ramTotalVal = stats["ram_total"];
        if (ramUsedVal is double && ramTotalVal is double && ramUsedVal >= 0) {
          ramUsage = "${ramUsedVal.toStringAsFixed(1)} / ${ramTotalVal.toStringAsFixed(1)} GB";
        }

        // GPU
        final gpuUseVal = stats["gpu_usage"];
        if (gpuUseVal is double && gpuUseVal >= 0) {
          gpuUsage = "${gpuUseVal.round()}%";
        }
        final gpuTempVal = stats["gpu_temp"];
        if (gpuTempVal is double) {
          gpuTemp = gpuTempVal >= 0 ? "${gpuTempVal.round()}°C" : "N/A";
        }

        // VRAM
        final vramUsedVal = stats["vram_used"];
        final vramTotalVal = stats["vram_total"];
        if (vramUsedVal is double && vramTotalVal is double && vramUsedVal >= 0) {
          vramUsage = "${vramUsedVal.toStringAsFixed(1)} / ${vramTotalVal.toStringAsFixed(1)} GB";
        }

        // FPS & Frametime
        final fpsVal = stats["fps"];
        if (fpsVal is double) {
          if (fpsVal >= 0) {
            fpsCounter = "${fpsVal.round()} FPS";
            frametime = "${(1000.0 / (fpsVal > 0 ? fpsVal : 1.0)).toStringAsFixed(1)} ms";
          } else {
            fpsCounter = "N/A";
            frametime = "N/A";
          }
        }
      }
    } catch (_) {
      // Fallback if native communication fails
    } finally {
      _isRefreshing = false;
      notifyListeners();
    }
  }

  Future<void> toggleGhostMode(bool enable) async {
    isGhostMode = enable;

    if (enable) {
      await windowManager.setHasShadow(false);
      await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
      await windowManager.setAlwaysOnTop(true);
      await windowManager.setSkipTaskbar(true);
      await windowManager.setResizable(false);
      
      // Position and size for overlay
      await windowManager.setSize(const Size(240, 320));
      await windowManager.setPosition(overlayOffset);

      final ignoreMouse = !allowDragInGhostMode;
      await windowManager.setIgnoreMouseEvents(ignoreMouse);
    } else {
      await windowManager.setIgnoreMouseEvents(false);
      await windowManager.setHasShadow(true);
      await windowManager.setTitleBarStyle(TitleBarStyle.normal);
      await windowManager.setAlwaysOnTop(false);
      await windowManager.setSkipTaskbar(false);
      await windowManager.setResizable(true);
      await windowManager.setSize(const Size(450, 620));
      await windowManager.setAlignment(Alignment.center);
    }

    notifyListeners();
  }

  void updateFontSize(double size) {
    fontSize = size;
    saveSettings();
    notifyListeners();
  }

  void updateFontColor(Color color) {
    fontColor = color;
    saveSettings();
    notifyListeners();
  }

  void updateBgOpacity(double opacity) {
    bgOpacity = opacity;
    saveSettings();
    notifyListeners();
  }

  void toggleBackground(bool value) {
    clearBackground = value;
    saveSettings();
    notifyListeners();
  }

  void toggleAllowDrag(bool value) async {
    allowDragInGhostMode = value;
    saveSettings();
    if (isGhostMode) {
      await windowManager.setIgnoreMouseEvents(!value);
    }
    notifyListeners();
  }

  void toggleStat(String stat, bool value) {
    switch (stat) {
      case 'FPS':
        showFPS = value;
        break;
      case 'Frametime':
        showFrametime = value;
        break;
      case 'CPUUsage':
        showCPUUsage = value;
        break;
      case 'CPUTemp':
        showCPUTemp = value;
        break;
      case 'GPUUsage':
        showGPUUsage = value;
        break;
      case 'GPUTemp':
        showGPUTemp = value;
        break;
      case 'RAM':
        showRAM = value;
        break;
      case 'VRAM':
        showVRAM = value;
        break;
      case 'Battery':
        showBattery = value;
        break;
      case 'Time':
        showTime = value;
        break;
    }

    saveSettings();
    notifyListeners();
    unawaited(_refreshStats());
  }

  @override
  void dispose() {
    _statsTimer?.cancel();
    super.dispose();
  }
}
