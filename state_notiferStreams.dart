// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:silkplayer/models/video_model.dart';

// class VideoAccumulator extends StateNotifier<List<VideoModel>> {
//   VideoAccumulator() : super([]);

//   void add(VideoModel video) {
//     // Avoid duplicates based on ID
//     if (!state.any((v) => v.id == video.id)) {
//       state = [...state, video];
//     }
//   }

//   void clear() {
//     state = [];
//   }
// }

// final streamedVideosProvider =
//     StateNotifierProvider<VideoAccumulator, List<VideoModel>>(
//       (ref) => VideoAccumulator(),
//     );

// final relatedVideosProvider =
//     StateNotifierProvider<RelatedVideoNotifier, List<VideoModel>>(
//       (ref) => RelatedVideoNotifier(),
//     );

// class RelatedVideoNotifier extends StateNotifier<List<VideoModel>> {
//   RelatedVideoNotifier() : super([]);

//   void add(VideoModel video, String currentId) {
//     if (video.id != currentId && !state.any((v) => v.id == video.id)) {
//       state = [...state, video];
//     }
//   }

//   void clear() {
//     state = [];
//   }
// }
