// providers/miniplayer_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:miniplayer/miniplayer.dart';
import '../models/video_model.dart';

final miniplayerControllerProvider = Provider((ref) => MiniplayerController());

final currentVideoProvider = StateProvider<VideoModel?>((ref) => null);
