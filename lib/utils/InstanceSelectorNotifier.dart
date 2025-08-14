import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silkplayer/providers/enums/BackEndConfigs.dart';
import 'package:silkplayer/providers/enums/VideoBackend.dart';

final instanceSelectorProvider =
    StateNotifierProvider<InstanceSelectorNotifier, void>((ref) {
      return InstanceSelectorNotifier(ref);
    });

class InstanceSelectorNotifier extends StateNotifier<void> {
  final Ref ref;

  InstanceSelectorNotifier(this.ref) : super(null);

  void selectPipedInstance(String instance) {
    ref.read(pipedInstanceProvider.notifier).state = instance;
  }

  void selectInvidiousInstance(String instance) {
    ref.read(invidiousInstanceProvider.notifier).state = instance;
  }

  void selectBackend(VideoBackend backend) {
    ref.read(videoBackendProvider.notifier).state = backend;
  }
}
