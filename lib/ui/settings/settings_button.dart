import 'package:flutter/material.dart';

import 'settings_page.dart';

/// Gear icon used in the page app bars.
class SettingsButton extends StatelessWidget {
  const SettingsButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Settings',
      icon: const Icon(Icons.settings_outlined),
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const SettingsPage()),
      ),
    );
  }
}
