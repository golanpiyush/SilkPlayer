import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:silkplayer/providers/interest_provider.dart';
import 'package:silkplayer/providers/provider.dart';
import 'package:silkplayer/utils/update_checker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/theme_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 🎯 All available quality options
const List<String> videoQualityOptions = [
  'Auto',
  '4K',
  '2K',
  '1080p',
  '720p',
  '480p',
  '360p',
  '240p',
  '144p',
];

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  // static const String _qualityKey = 'silk_selected_video_quali/ty';
  //
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeNotifier = ref.read(themeProvider.notifier);
    final currentTheme = themeNotifier.currentTheme;
    final seekbarColor = themeNotifier.seekbarColor;
    final List<String> countries = [
      'India',
      'United States',
      'Japan',
      'Germany',
      'Brazil',
      'United Kingdom',
      'France',
      'Canada',
      'Australia',
      'Russia',
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        titleSpacing: 12,
        title: Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Text(
            'Settings',
            style: GoogleFonts.permanentMarker(
              color: Colors.redAccent,
              fontSize: 28,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
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
          _buildSection('Your Interests', [_buildInterestSelector(ref)]),
          const SizedBox(height: 24),
          _buildSection('Video', [
            _buildSettingsTile(
              icon: Icons.hd,
              title: 'Default Quality',
              subtitle: ref.watch(qualityProvider), // Shows current quality
              onTap: () => showQualityDialog(context, ref),
            ),
            _buildSettingsTile(
              icon: Icons.history,
              title: 'Auto-delete History',
              subtitle: 'After 30 days',
              onTap: () => _showHistoryDialog(context),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 12,
              ),
              child: Row(
                children: [
                  const Icon(Icons.language, color: Colors.grey),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Consumer(
                      builder: (context, ref, _) {
                        final selected = ref.watch(selectedCountryProvider);
                        return DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'Content Country',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                          value: selected,
                          items: countries.map((c) {
                            return DropdownMenuItem(value: c, child: Text(c));
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              ref.read(selectedCountryProvider.notifier).state =
                                  value;
                            }
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 24),
          _buildSection('About', [
            _buildSettingsTile(
              icon: Icons.info_outline,
              title: 'Version',
              subtitle: '2.4.9',
              onTap: () => checkForUpdate(context),
            ),
            _buildSettingsTile(
              icon: Icons.code,
              title: 'Open Source',
              subtitle: 'View on GitHub',
              onTap: () async {
                final url = Uri.parse(
                  'https://github.com/golanpiyush/SilkPlayer',
                );
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                } else {
                  // optional: show error
                  debugPrint('Could not launch $url');
                }
              },
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildInterestSelector(WidgetRef ref) {
    final interests = [
      'Coding',
      'Codemy',
      'Music',
      'Movies',
      'Gaming',
      'Tech Reviews',
      'Vlogs',
      'Fitness',
      'News',
      'Science',
    ];
    final selected = ref.watch(interestProvider);
    final notifier = ref.read(interestProvider.notifier);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select your interests',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: interests.map((interest) {
              final isSelected = selected.contains(interest);
              return ChoiceChip(
                label: Text(interest),
                selected: isSelected,
                onSelected: (_) => notifier.toggleInterest(interest),
                selectedColor: Theme.of(
                  ref.context,
                ).primaryColor.withOpacity(0.8),
              );
            }).toList(),
          ),
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
      leading: Icon(icon, color: Colors.white),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      subtitle: Text(subtitle, style: TextStyle(color: Colors.grey[400])),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
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

  // 🎯 Modular Quality Dialog Method
  void showQualityDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, child) {
          final selectedQuality = ref.watch(qualityProvider);

          return AlertDialog(
            backgroundColor: Colors.black,
            insetPadding: const EdgeInsets.symmetric(horizontal: 20),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey[800]!, width: 1),
            ),
            content: SizedBox(
              width: MediaQuery.of(context).size.width * 0.9,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.high_quality,
                          color: Colors.white,
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Video Quality',
                          style: GoogleFonts.preahvihear(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Quality options
                  ...videoQualityOptions.map((quality) {
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () async {
                          await ref
                              .read(qualityProvider.notifier)
                              .setQuality(quality);
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Quality set to $quality',
                                  style: GoogleFonts.preahvihear(
                                    color: Colors.white,
                                  ),
                                ),
                                backgroundColor: Colors.green,
                                duration: const Duration(seconds: 1),
                                behavior: SnackBarBehavior.floating,
                                margin: const EdgeInsets.only(
                                  bottom: 20,
                                  left: 20,
                                  right: 20,
                                ),
                              ),
                            );
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 12,
                          ),
                          margin: const EdgeInsets.only(bottom: 4),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: selectedQuality == quality
                                ? Colors.grey[900]
                                : Colors.transparent,
                            border: Border.all(
                              color: selectedQuality == quality
                                  ? Colors.red
                                  : Colors.grey[800]!,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                selectedQuality == quality
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_unchecked,
                                color: selectedQuality == quality
                                    ? Colors.red
                                    : Colors.grey[600],
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      quality,
                                      style: GoogleFonts.preahvihear(
                                        color: Colors.white,
                                        fontWeight: selectedQuality == quality
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                    ),
                                    // If you want to add a description later:
                                    // Padding(
                                    //   padding: const EdgeInsets.only(top: 4),
                                    //   child: Text(
                                    //     _getQualityDescription(quality),
                                    //     style: GoogleFonts.preahvihear(
                                    //       color: Colors.grey[500],
                                    //       fontSize: 12,
                                    //     ),
                                    //   ),
                                    // ),
                                  ],
                                ),
                              ),
                              _getQualityIcon(quality),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          );
        },
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

  Widget _getQualityIcon(String quality) {
    IconData icon;
    Color color;

    switch (quality) {
      case 'Auto':
        icon = Icons.auto_awesome;
        color = Colors.blue;
        break;
      case '4K':
        icon = Icons.hd_rounded;
        color = Colors.red;
        break;
      case '2K':
        icon = Icons.hdr_auto_rounded;
        color = Colors.orange;
        break;
      case '1080p':
        icon = Icons.hd;
        color = Colors.green;
        break;
      case '720p':
        icon = Icons.hd;
        color = Colors.lightGreen;
        break;
      case '480p':
        icon = Icons.sd;
        color = Colors.amber;
        break;
      case '360p':
        icon = Icons.sd;
        color = Colors.orange;
        break;
      case '240p':
        icon = Icons.sd;
        color = Colors.deepOrange;
        break;
      case '144p':
        icon = Icons.sd;
        color = Colors.red;
        break;
      default:
        icon = Icons.video_settings;
        color = Colors.grey;
    }

    return Icon(icon, size: 16, color: color);
  }

  Widget? _getQualityDescription(String quality) {
    String description;

    switch (quality) {
      case 'Auto':
        description = 'Automatically adjusts based on connection';
        break;
      case '4K':
        description = 'Ultra HD (2160p) - Best quality, high data usage';
        break;
      case '2K':
        description = 'Quad HD (1440p) - Excellent quality';
        break;
      case '1080p':
        description = 'Full HD - High quality, balanced usage';
        break;
      case '720p':
        description = 'HD - Good quality, moderate usage';
        break;
      case '480p':
        description = 'SD - Basic quality, low usage';
        break;
      case '360p':
        description = 'Low - Minimal quality, very low usage';
        break;
      case '240p':
        description = 'Very low - Poor quality, minimal data';
        break;
      case '144p':
        description = 'Lowest - Audio focus, minimal video';
        break;
      default:
        return null;
    }

    return Text(
      description,
      style: const TextStyle(fontSize: 11, color: Colors.grey),
    );
  }
}

class QualityNotifier extends StateNotifier<String> {
  static const String _qualityKey = 'selected_video_quality';

  QualityNotifier() : super('720p') {
    _loadQuality();
  }

  Future<void> _loadQuality() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedQuality = prefs.getString(_qualityKey);
      if (savedQuality != null && videoQualityOptions.contains(savedQuality)) {
        state = savedQuality;
      }
    } catch (e) {
      print('Error loading quality preference: $e');
    }
  }

  Future<void> setQuality(String quality) async {
    if (videoQualityOptions.contains(quality)) {
      state = quality;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_qualityKey, quality);
        print('✅ Quality saved: $quality');
      } catch (e) {
        print('Error saving quality preference: $e');
      }
    }
  }
}

// 🎯 Updated Provider
final qualityProvider = StateNotifierProvider<QualityNotifier, String>((ref) {
  return QualityNotifier();
});
