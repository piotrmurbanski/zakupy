import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zakupy_mobile/app.dart';
import 'package:zakupy_mobile/core/theme/theme_mode_menu.dart';

void main() {
  test('buildDarkTheme uses a dark color scheme', () {
    final theme = buildDarkTheme();

    expect(theme.brightness, Brightness.dark);
    expect(theme.colorScheme.brightness, Brightness.dark);
    expect(theme.useMaterial3, true);
  });

  test('buildLightTheme uses a light color scheme', () {
    final theme = buildLightTheme();

    expect(theme.brightness, Brightness.light);
    expect(theme.colorScheme.brightness, Brightness.light);
    expect(theme.useMaterial3, true);
  });

  testWidgets('theme mode menu selects dark mode', (tester) async {
    var currentThemeMode = ThemeMode.system;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            actions: [
              ThemeModeMenuButton(
                currentThemeMode: currentThemeMode,
                onSelected: (themeMode) {
                  currentThemeMode = themeMode;
                },
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.brightness_6_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    expect(currentThemeMode, ThemeMode.dark);
  });
}
