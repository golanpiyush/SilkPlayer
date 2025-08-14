import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silkplayer/providers/ytdlpServicesProvider.dart'; // Make sure this path is correct

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the provider
    final provider = ref.watch(ytdlpServicesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings'), elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Video Settings'),
            const SizedBox(height: 16),
            _buildVideoQualitySelector(provider),
            const SizedBox(height: 16),
            _buildVideoCodecSelector(provider),
            const SizedBox(height: 32),

            _buildSectionHeader('Audio Settings'),
            const SizedBox(height: 16),
            _buildAudioBitrateSelector(provider),
            const SizedBox(height: 16),
            _buildAudioCodecSelector(provider),
            const SizedBox(height: 32),

            _buildSectionHeader('Playback Settings'),
            const SizedBox(height: 16),
            _buildBackgroundPlaybackToggle(provider),
            const SizedBox(height: 32),

            _buildResetButton(context, provider),
          ],
        ),
      ),
    );
  }
}

Widget _buildSectionHeader(String title) {
  return Text(
    title,
    style: const TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.bold,
      color: Colors.blue,
    ),
  );
}

Widget _buildVideoQualitySelector(YtdlpServicesProvider provider) {
  return Card(
    child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Video Quality',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: provider.videoQuality,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: provider.videoQualities.map((quality) {
              return DropdownMenuItem(value: quality, child: Text(quality));
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                provider.setVideoQuality(value);
              }
            },
          ),
        ],
      ),
    ),
  );
}

Widget _buildVideoCodecSelector(YtdlpServicesProvider provider) {
  return Card(
    child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Video Codec',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: provider.videoCodec,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: provider.videoCodecs.map((codec) {
              return DropdownMenuItem(
                value: codec,
                child: Text(codec.toUpperCase()),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                provider.setVideoCodec(value);
              }
            },
          ),
        ],
      ),
    ),
  );
}

Widget _buildAudioBitrateSelector(YtdlpServicesProvider provider) {
  return Card(
    child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Audio Bitrate',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            value: provider.audioBitrate,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: provider.audioBitrates.map((bitrate) {
              return DropdownMenuItem(
                value: bitrate,
                child: Text('${bitrate}kbps'),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                provider.setAudioBitrate(value);
              }
            },
          ),
        ],
      ),
    ),
  );
}

Widget _buildAudioCodecSelector(YtdlpServicesProvider provider) {
  return Card(
    child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Audio Codec',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: provider.audioCodec,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: provider.audioCodecs.map((codec) {
              return DropdownMenuItem(
                value: codec,
                child: Text(codec.toUpperCase()),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                provider.setAudioCodec(value);
              }
            },
          ),
        ],
      ),
    ),
  );
}

Widget _buildBackgroundPlaybackToggle(YtdlpServicesProvider provider) {
  return Card(
    child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Background Playback',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                SizedBox(height: 4),
                Text(
                  'Continue playing audio when app is minimized',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          Switch(
            value: provider.backgroundPlayback,
            onChanged: (value) {
              provider.setBackgroundPlayback(value);
            },
          ),
        ],
      ),
    ),
  );
}

Widget _buildResetButton(BuildContext context, YtdlpServicesProvider provider) {
  return SizedBox(
    width: double.infinity,
    child: OutlinedButton.icon(
      onPressed: () {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Reset Settings'),
              content: const Text(
                'Are you sure you want to reset all settings to default values?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    provider.setVideoQuality('1080p');
                    provider.setAudioBitrate(192);
                    provider.setAudioCodec('opus');
                    provider.setVideoCodec('avc1');
                    provider.setBackgroundPlayback(false);
                    Navigator.of(context).pop();

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Settings reset to default values'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                  child: const Text('Reset'),
                ),
              ],
            );
          },
        );
      },
      icon: const Icon(Icons.refresh),
      label: const Text('Reset to Default'),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
    ),
  );
}
