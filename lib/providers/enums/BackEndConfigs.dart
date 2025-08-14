import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silkplayer/providers/enums/VideoBackend.dart';

enum NewPipeFallbackMode { enabled, disabled }

class BackendConfig {
  static const List<String> pipedInstances = [
    "https://pipedapi.adminforge.de",
    "https://piapi.ggtyler.dev",
    "https://pipedapi.drgns.space",
    "https://pipedapi.kavin.rocks",
    "https://pipedapi.reallyaweso.me",
    "https://api.piped.private.coffee",
    "https://pipedapi.ducks.party",
  ];

  static const List<String> invidiousInstances = [
    'https://inv.nadeko.net',
    'https://yewtu.be/',
    'https://yt.artemislena.eu',
  ];
}

final videoBackendProvider = StateProvider<VideoBackend>(
  (ref) => VideoBackend.explode,
);
final pipedInstanceProvider = StateProvider<String>(
  (ref) => BackendConfig.pipedInstances.first,
);
final invidiousInstanceProvider = StateProvider<String>(
  (ref) => BackendConfig.invidiousInstances.first,
);

// Add this provider
final newPipeFallbackProvider = StateProvider<NewPipeFallbackMode>((ref) {
  return NewPipeFallbackMode.enabled; // Default to enabled
});
