import 'package:flutter/material.dart';

class ThemeModeMenuButton extends StatelessWidget {
  const ThemeModeMenuButton({
    required this.currentThemeMode,
    required this.onSelected,
    super.key,
  });

  final ThemeMode currentThemeMode;
  final ValueChanged<ThemeMode> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<ThemeMode>(
      tooltip: 'Wygląd',
      onSelected: onSelected,
      icon: const Icon(Icons.brightness_6_outlined),
      itemBuilder: (context) => [
        PopupMenuItem<ThemeMode>(
          value: ThemeMode.system,
          child: _MenuItem(
            label: 'Systemowy',
            selected: currentThemeMode == ThemeMode.system,
          ),
        ),
        PopupMenuItem<ThemeMode>(
          value: ThemeMode.light,
          child: _MenuItem(
            label: 'Jasny',
            selected: currentThemeMode == ThemeMode.light,
          ),
        ),
        PopupMenuItem<ThemeMode>(
          value: ThemeMode.dark,
          child: _MenuItem(
            label: 'Ciemny',
            selected: currentThemeMode == ThemeMode.dark,
          ),
        ),
      ],
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.label,
    required this.selected,
  });

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (selected) const Icon(Icons.check, size: 18),
        if (selected) const SizedBox(width: 8),
        Text(label),
      ],
    );
  }
}
