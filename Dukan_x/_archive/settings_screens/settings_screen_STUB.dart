import 'package:flutter/material.dart';
import 'package:dukanx/core/responsive/responsive.dart';
import '../../../splash/splash_audio_controller.dart';

/// FIXED: Compile-safe settings entry screen.
/// Main legacy settings file has path-resolution issue in current analyzer context.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: BoundedBox(
        maxWidth: 800,
        child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.print),
              title: const Text('Printer Settings'),
              subtitle: const Text('Thermal printer, width, test print'),
              onTap: () => Navigator.pushNamed(context, '/printer-settings'),
            ),
          ),
          StatefulBuilder(
            builder: (context, setState) {
              return FutureBuilder<bool>(
                future: SplashAudioController.getEnabled(),
                builder: (context, snapshot) {
                  final isEnabled = snapshot.data ?? false;
                  return Card(
                    child: SwitchListTile(
                      secondary: const Icon(Icons.volume_up_rounded),
                      title: const Text('Startup Sound'),
                      subtitle: const Text('Play sound when app opens'),
                      value: isEnabled,
                      onChanged: (value) async {
                        await SplashAudioController.setEnabled(value);
                        setState(() {});
                      },
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
      ),
    );
  }
}

