import 'package:ballys_reservation_app/components/watermark.dart';
import 'package:ballys_reservation_app/core/constants.dart';
import 'package:ballys_reservation_app/providers/font_settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final String _selectedFontWeight = 'Normal';

  @override
  Widget build(BuildContext context) {
    final double selectedFontSize = ref.watch(fontSettingsProvider).fontSize;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Stack(
        children: [
          
      
      Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'App Mode',
              style: TextStyle(fontSize: 16.0),
            ),
            const SizedBox(height: 20),
            Row(
  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
  children: [
    _buildAppModeButton(AppMode.myData, 'Show My Data'),
    _buildAppModeButton(AppMode.overallData, 'Show Overall Data'),
  ],
),

            const Text(
              'Font Size Settings',
              style: TextStyle(fontSize: 16.0),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildFontSizeButton(14.0, 'Small'),
                _buildFontSizeButton(16.0, 'Medium'),
                _buildFontSizeButton(18.0, 'Large'),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'Font Weight Settings',
              style: TextStyle(fontSize: 16.0),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildFontWeightButton(FontWeight.normal, 'Normal'),
                _buildFontWeightButton(FontWeight.bold, 'Bold'),
                _buildFontWeightButton(FontWeight.w900, 'Extra Bold'),
              ],
            ),
          ],
        ),
      ),
          const Watermark(),
        ],
      )
    );
  }

  Widget _buildFontSizeButton(double size, String name) {
    return ElevatedButton(
      onPressed: () {
        ref.read(fontSettingsProvider.notifier).setFontSize(size);
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: ref.watch(fontSettingsProvider).fontSize == size
            ? Constants.kSecondaryColor
            : Colors.grey[300],
        foregroundColor: ref.watch(fontSettingsProvider).fontSize == size
            ? Colors.white
            : Colors.black,
      ),
      child: Text(name),
    );
  }

  Widget _buildFontWeightButton(FontWeight weight, String name) {
    return ElevatedButton(
      onPressed: () {
        ref.read(fontSettingsProvider.notifier).setFontWeight(weight);
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: ref.watch(fontSettingsProvider).fontWeight == weight
            ? Constants.kSecondaryColor
            : Colors.grey[300],
        foregroundColor: ref.watch(fontSettingsProvider).fontWeight == weight
            ? Colors.white
            : Colors.black,
      ),
      child: Text(name),
    );
  }

  Widget _buildAppModeButton(AppMode mode, String name) {
  final selectedMode = ref.watch(fontSettingsProvider).appMode;

  return ElevatedButton(
    onPressed: () {
      ref.read(fontSettingsProvider.notifier).setAppMode(mode);
    },
    style: ElevatedButton.styleFrom(
      backgroundColor: selectedMode == mode
          ? Constants.kSecondaryColor
          : Colors.grey[300],
      foregroundColor: selectedMode == mode ? Colors.white : Colors.black,
    ),
    child: Text(name),
  );
}

}
