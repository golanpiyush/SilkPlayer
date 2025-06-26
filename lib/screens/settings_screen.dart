import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/theme_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeNotifier = ref.read(themeProvider.notifier);
    final currentTheme = themeNotifier.currentTheme;
    final seekbarColor = themeNotifier.seekbarColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection('Appearance', [
            _buildThemeSelector(context, ref, currentTheme),
            const SizedBox(height: 16),
            _buildSeekbarColorSelector(context, ref, seekbarColor),
          ]),
          const SizedBox(height: 24),
          _buildSection('Video', [
            _buildSettingsTile(
              icon: Icons.hd,
              title: 'Default Quality',
              subtitle: '720p',
              onTap: () => _showQualityDialog(context),
            ),
            _buildSettingsTile(
              icon: Icons.history,
              title: 'Auto-delete History',
              subtitle: 'After 30 days',
              onTap: () => _showHistoryDialog(context),
            ),
          ]),
          const SizedBox(height: 24),
          _buildSection('About', [
            _buildSettingsTile(
              icon: Icons.info_outline,
              title: 'Version',
              subtitle: '1.0.0',
              onTap: () {},
            ),
            _buildSettingsTile(
              icon: Icons.code,
              title: 'Open Source',
              subtitle: 'View on GitHub',
              onTap: () {},
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        ...children,
      ],
    );
  }

  Widget _buildThemeSelector(
    BuildContext context,
    WidgetRef ref,
    AppTheme currentTheme,
  ) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.palette, size: 24),
                SizedBox(width: 12),
                Text(
                  'Theme',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          ...AppTheme.values.map((theme) {
            final isSelected = theme == currentTheme;
            return RadioListTile<AppTheme>(
              title: Text(_getThemeName(theme)),
              subtitle: Text(_getThemeDescription(theme)),
              value: theme,
              groupValue: currentTheme,
              onChanged: (AppTheme? value) {
                if (value != null) {
                  ref.read(themeProvider.notifier).setTheme(value);
                }
              },
              activeColor: Theme.of(context).primaryColor,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSeekbarColorSelector(
    BuildContext context,
    WidgetRef ref,
    Color currentColor,
  ) {
    final colors = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.pink,
      Colors.teal,
      Colors.indigo,
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.color_lens, size: 24),
              SizedBox(width: 12),
              Text(
                'Seekbar Color',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: colors.map((color) {
              final isSelected = color.value == currentColor.value;
              return GestureDetector(
                onTap: () {
                  ref.read(themeProvider.notifier).setSeekbarColor(color);
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? Colors.white : Colors.transparent,
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white, size: 20)
                      : null,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  String _getThemeName(AppTheme theme) {
    switch (theme) {
      case AppTheme.light:
        return 'Light';
      case AppTheme.dark:
        return 'Dark';
      case AppTheme.amoled:
        return 'Pure AMOLED Black';
    }
  }

  String _getThemeDescription(AppTheme theme) {
    switch (theme) {
      case AppTheme.light:
        return 'Light theme with white background';
      case AppTheme.dark:
        return 'Dark theme with grey background';
      case AppTheme.amoled:
        return 'Pure black for AMOLED displays';
    }
  }

  void _showQualityDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Default Quality'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['1080p', '720p', '480p', '360p', 'Auto']
              .map(
                (quality) => RadioListTile<String>(
                  title: Text(quality),
                  value: quality,
                  groupValue: '720p',
                  onChanged: (value) {
                    Navigator.pop(context);
                  },
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  void _showHistoryDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Auto-delete History'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['Never', 'After 7 days', 'After 30 days', 'After 90 days']
              .map(
                (option) => RadioListTile<String>(
                  title: Text(option),
                  value: option,
                  groupValue: 'After 30 days',
                  onChanged: (value) {
                    Navigator.pop(context);
                  },
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}
