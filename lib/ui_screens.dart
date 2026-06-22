import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'overlay_settings.dart';

class StatsOverlay extends StatelessWidget {
  final OverlaySettings settings;

  const StatsOverlay({super.key, required this.settings});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final showDragHeader = !settings.isGhostMode;
        final hasAnyStat = settings.showFPS ||
            settings.showFrametime ||
            settings.showCPUUsage ||
            settings.showCPUTemp ||
            settings.showGPUUsage ||
            settings.showGPUTemp ||
            settings.showRAM ||
            settings.showVRAM ||
            settings.showBattery ||
            settings.showTime;

        return GestureDetector(
          onPanStart: (_) async {
            final canDrag = !settings.isGhostMode || settings.allowDragInGhostMode;
            if (canDrag) {
              await windowManager.startDragging();
              final pos = await windowManager.getPosition();
              settings.saveOverlayPosition(pos);
            }
          },
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: settings.clearBackground
                    ? Colors.transparent
                    : Colors.black.withOpacity(settings.bgOpacity),
                borderRadius: BorderRadius.circular(6),
                border: showDragHeader
                    ? Border.all(color: settings.fontColor.withOpacity(0.3), width: 1.5)
                    : null,
              ),
              child: IntrinsicWidth(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showDragHeader)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.drag_indicator, size: 12, color: settings.fontColor),
                            const SizedBox(width: 4),
                            Text(
                              "DRAG OVERLAY",
                              style: TextStyle(
                                color: settings.fontColor,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Consolas',
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (!hasAnyStat)
                      _buildOverlayText(
                        'No telemetry active',
                        fontSize: settings.fontSize,
                        color: settings.fontColor,
                      )
                    else ...[
                      if (settings.showFPS)
                        _buildOverlayText(
                          'FPS: ${settings.fpsCounter}',
                          fontSize: settings.fontSize,
                          color: settings.fontColor,
                          bold: true,
                        ),
                      if (settings.showFrametime)
                        _buildOverlayText(
                          'FT : ${settings.frametime}',
                          fontSize: settings.fontSize,
                          color: settings.fontColor,
                        ),
                      if (settings.showCPUUsage || settings.showCPUTemp)
                        _buildCombinedRow(
                          'CPU: ',
                          settings.showCPUUsage ? settings.cpuUsage : null,
                          settings.showCPUTemp ? settings.cpuTemp : null,
                          fontSize: settings.fontSize,
                          color: settings.fontColor,
                        ),
                      if (settings.showGPUUsage || settings.showGPUTemp)
                        _buildCombinedRow(
                          'GPU: ',
                          settings.showGPUUsage ? settings.gpuUsage : null,
                          settings.showGPUTemp ? settings.gpuTemp : null,
                          fontSize: settings.fontSize,
                          color: settings.fontColor,
                        ),
                      if (settings.showRAM)
                        _buildOverlayText(
                          'RAM: ${settings.ramUsage}',
                          fontSize: settings.fontSize,
                          color: settings.fontColor,
                        ),
                      if (settings.showVRAM)
                        _buildOverlayText(
                          'VRM: ${settings.vramUsage}',
                          fontSize: settings.fontSize,
                          color: settings.fontColor,
                        ),
                      if (settings.showBattery && settings.currentBatteryLevel != null)
                        _buildOverlayText(
                          'BAT: ${settings.currentBatteryLevel}%',
                          fontSize: settings.fontSize,
                          color: settings.fontColor,
                        ),
                      if (settings.showTime)
                        _buildOverlayText(
                          'CLK: ${settings.currentTime}',
                          fontSize: settings.fontSize,
                          color: settings.fontColor,
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOverlayText(
    String value, {
    required double fontSize,
    required Color color,
    bool bold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Text(
        value,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: bold ? FontWeight.bold : FontWeight.w600,
          fontFamily: 'Consolas',
          shadows: [
            const Shadow(offset: Offset(-1.2, -1.2), color: Colors.black),
            const Shadow(offset: Offset(1.2, -1.2), color: Colors.black),
            const Shadow(offset: Offset(1.2, 1.2), color: Colors.black),
            const Shadow(offset: Offset(-1.2, 1.2), color: Colors.black),
            Shadow(
              offset: const Offset(0, 2),
              color: Colors.black.withOpacity(0.9),
              blurRadius: 3,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCombinedRow(
    String label,
    String? first,
    String? second, {
    required double fontSize,
    required Color color,
  }) {
    String output = label;
    if (first != null && second != null) {
      output += '$first  $second';
    } else if (first != null) {
      output += first;
    } else if (second != null) {
      output += second;
    }
    return _buildOverlayText(output, fontSize: fontSize, color: color);
  }
}

class SettingsPanel extends StatefulWidget {
  final OverlaySettings settings;

  const SettingsPanel({super.key, required this.settings});

  @override
  State<SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<SettingsPanel> {
  final List<Color> _presetColors = const [
    Color(0xFF00FF00), // Neon Green
    Color(0xFF00FFFF), // Electric Cyan
    Color(0xFFFFEA00), // Bright Yellow
    Color(0xFFFF1493), // Hot Pink
    Color(0xFFFF5722), // Safety Orange
    Color(0xFFFFFFFF), // Pure White
  ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.settings,
      builder: (context, _) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0F0F13),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cyberpunk Title Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.deepPurpleAccent, width: 2),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.videogame_asset, color: Colors.deepPurpleAccent, size: 24),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'GAMING TELEMETRY',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                          Text(
                            'VITAL STATS OVERLAY',
                            style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Scrollable Options Section
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    // Color Settings
                    _buildSectionHeader('FONT COLOR'),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: _presetColors.map((color) {
                        final isSelected = widget.settings.fontColor.value == color.value;
                        return GestureDetector(
                          onTap: () => widget.settings.updateFontColor(color),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? Colors.white : Colors.transparent,
                                width: 2.5,
                              ),
                              boxShadow: [
                                if (isSelected)
                                  BoxShadow(
                                    color: color.withOpacity(0.6),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  ),
                              ],
                            ),
                            child: isSelected
                                ? const Icon(Icons.check, color: Colors.black, size: 16)
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // Sliders for Size & Opacity
                    _buildSectionHeader('VISUAL ADJUSTMENTS'),
                    const SizedBox(height: 10),
                    _buildSliderRow(
                      'Font Size',
                      widget.settings.fontSize,
                      10.0,
                      30.0,
                      '${widget.settings.fontSize.round()}px',
                      (val) => widget.settings.updateFontSize(val),
                    ),
                    const SizedBox(height: 8),
                    _buildSliderRow(
                      'Background Opacity',
                      widget.settings.bgOpacity,
                      0.0,
                      1.0,
                      '${(widget.settings.bgOpacity * 100).round()}%',
                      (val) => widget.settings.updateBgOpacity(val),
                    ),
                    const SizedBox(height: 20),

                    // Telemetry switches
                    _buildSectionHeader('ACTIVE TELEMETRY'),
                    const SizedBox(height: 8),
                    _buildToggleRow('Frames Per Second (FPS)', widget.settings.showFPS,
                        (val) => widget.settings.toggleStat('FPS', val)),
                    _buildToggleRow('Frame Times (Frametime)', widget.settings.showFrametime,
                        (val) => widget.settings.toggleStat('Frametime', val)),
                    _buildToggleRow('CPU Usage', widget.settings.showCPUUsage,
                        (val) => widget.settings.toggleStat('CPUUsage', val)),
                    _buildToggleRow('CPU Temperature', widget.settings.showCPUTemp,
                        (val) => widget.settings.toggleStat('CPUTemp', val)),
                    _buildToggleRow('GPU Utilization', widget.settings.showGPUUsage,
                        (val) => widget.settings.toggleStat('GPUUsage', val)),
                    _buildToggleRow('GPU Temperature', widget.settings.showGPUTemp,
                        (val) => widget.settings.toggleStat('GPUTemp', val)),
                    _buildToggleRow('RAM Usage', widget.settings.showRAM,
                        (val) => widget.settings.toggleStat('RAM', val)),
                    _buildToggleRow('VRAM Usage', widget.settings.showVRAM,
                        (val) => widget.settings.toggleStat('VRAM', val)),
                    _buildToggleRow('System Clock Time', widget.settings.showTime,
                        (val) => widget.settings.toggleStat('Time', val)),
                    _buildToggleRow('Battery Info (Laptops)', widget.settings.showBattery,
                        (val) => widget.settings.toggleStat('Battery', val)),
                    const SizedBox(height: 20),

                    // Window options
                    _buildSectionHeader('OVERLAY CONTROL'),
                    const SizedBox(height: 8),
                    _buildToggleRow(
                      'Allow Dragging in Ghost Mode',
                      widget.settings.allowDragInGhostMode,
                      (val) => widget.settings.toggleAllowDrag(val),
                    ),
                    _buildToggleRow(
                      'Completely Transparent Backplate',
                      widget.settings.clearBackground,
                      (val) => widget.settings.toggleBackground(val),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.deepPurpleAccent.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.deepPurpleAccent.withOpacity(0.2)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline, size: 16, color: Colors.deepPurpleAccent),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "To unlock the overlay later, look for the System Tray Icon in your Taskbar, right-click, and select 'Unlock & Settings Menu'.",
                              style: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 11,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Lock Overlay button
              Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurpleAccent,
                    foregroundColor: Colors.white,
                    shadowColor: Colors.deepPurpleAccent.withOpacity(0.4),
                    elevation: 5,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.lock, size: 18),
                  label: const Text(
                    'LOCK & LAUNCH OVERLAY',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  onPressed: () => widget.settings.toggleGhostMode(true),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.deepPurpleAccent,
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildSliderRow(
    String label,
    double currentValue,
    double min,
    double max,
    String displayValue,
    ValueChanged<double> onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 13, color: Colors.white),
              ),
              Text(
                displayValue,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.deepPurpleAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: Colors.deepPurpleAccent,
              inactiveTrackColor: Colors.white.withOpacity(0.1),
              thumbColor: Colors.deepPurpleAccent,
              overlayColor: Colors.deepPurpleAccent.withOpacity(0.2),
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            ),
            child: Slider(
              value: currentValue,
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleRow(
    String label,
    bool currentValue,
    ValueChanged<bool> onChanged,
  ) {
    return Card(
      color: Colors.white.withOpacity(0.02),
      margin: const EdgeInsets.symmetric(vertical: 2),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
      ),
      child: SwitchListTile(
        title: Text(
          label,
          style: const TextStyle(fontSize: 13, color: Colors.white),
        ),
        value: currentValue,
        onChanged: onChanged,
        activeColor: Colors.deepPurpleAccent,
        activeTrackColor: Colors.deepPurpleAccent.withOpacity(0.3),
        inactiveThumbColor: Colors.grey.shade400,
        inactiveTrackColor: Colors.white.withOpacity(0.1),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        dense: true,
      ),
    );
  }
}
