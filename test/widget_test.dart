import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gaming_stats/overlay_settings.dart';
import 'package:gaming_stats/ui_screens.dart';

void main() {
  testWidgets('settings panel renders current overlay controls', (
    WidgetTester tester,
  ) async {
    final settings = OverlaySettings(startTracking: false);
    addTearDown(settings.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingsPanel(settings: settings),
        ),
      ),
    );

    expect(find.text('Overlay Configurations'), findsOneWidget);
    expect(find.text('Show FPS Counter'), findsOneWidget);
    expect(find.text('Show CPU Utilization'), findsOneWidget);
    expect(find.text('Show GPU Utilization'), findsOneWidget);
    expect(find.text('Show Remaining Battery'), findsOneWidget);
    expect(find.text('Show System Clock'), findsOneWidget);
  });
}
