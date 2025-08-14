import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silkplayer/providers/ytdlpServicesProvider.dart';

final qualitySelectorProvider =
    StateNotifierProvider<QualitySelectorNotifier, String>((ref) {
      return QualitySelectorNotifier(ref);
    });

class QualitySelectorNotifier extends StateNotifier<String> {
  final Ref ref;

  QualitySelectorNotifier(this.ref)
    : super(ref.read(ytdlpServicesProvider).videoQuality);

  void selectQuality(String quality) {
    // Update both the local state and the persistent YT-DLP settings
    state = quality;
    ref.read(ytdlpServicesProvider.notifier).setVideoQuality(quality);
  }

  // Optional: Add method to sync with current YT-DLP settings
  void syncWithCurrentQuality() {
    state = ref.read(ytdlpServicesProvider).videoQuality;
  }
}
