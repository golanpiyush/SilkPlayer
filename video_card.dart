import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../models/video_model.dart';
import '../providers/saved_videos_provider.dart';
import '../screens/player_screen.dart';

class VideoCard extends ConsumerWidget {
  final VideoModel video;
  final bool showTrendingBadge;

  const VideoCard({
    super.key,
    required this.video,
    this.showTrendingBadge = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedVideos = ref.watch(savedVideosProvider);
    final isSaved = savedVideos.any((v) => v.id == video.id);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: GestureDetector(
        onTap: () async {
          // Navigate to the player screen first
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => PlayerScreen(video: video)),
          );

          // Start playback in the background
          // await _startPlayback(context, ref);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildThumbnail(context),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _buildVideoRow(context, ref, isSaved),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail(BuildContext context) {
    return Stack(
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CachedNetworkImage(
              imageUrl: video.thumbnailUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: Colors.grey[900],
                child: const Center(child: CircularProgressIndicator()),
              ),
              errorWidget: (context, url, error) =>
                  const Icon(Icons.error, size: 50),
            ),
          ),
        ),
        if (video.duration != null)
          Positioned(
            bottom: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                video.durationString,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildVideoRow(BuildContext context, WidgetRef ref, bool isSaved) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: Colors.grey[300],
          backgroundImage:
              video.uploaderAvatarUrl != null &&
                  video.uploaderAvatarUrl!.isNotEmpty
              ? NetworkImage(video.uploaderAvatarUrl!)
              : null,
          child:
              (video.uploaderAvatarUrl == null ||
                  video.uploaderAvatarUrl!.isEmpty)
              ? const Icon(Icons.person, size: 20, color: Colors.black54)
              : null,
        ),

        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                video.title,
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    video.author,
                    style: const TextStyle(color: Colors.grey, fontSize: 13.5),
                  ),

                  Text(
                    "• ${video.viewCountString}",
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  Text(
                    "• ${video.uploadDate != null ? timeago.format(video.uploadDate!) : 'Unknown'}",
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () {
            ref.read(savedVideosProvider.notifier).toggleVideo(video);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  isSaved ? 'Removed from saved videos' : 'Saved video',
                ),
              ),
            );
          },
          icon: Icon(
            isSaved ? Icons.check_circle : Icons.bookmark_add_outlined,
            color: isSaved ? Colors.redAccent : Colors.grey,
            size: 22,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.more_vert, color: Colors.grey),
          onPressed: () => _showMoreOptions(context, ref),
        ),
      ],
    );
  }

  void _showMoreOptions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      backgroundColor: Colors.grey[900],
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[700],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.share, color: Colors.white),
            title: const Text('Share', style: TextStyle(color: Colors.white)),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.playlist_add, color: Colors.white),
            title: const Text(
              'Add to playlist',
              style: TextStyle(color: Colors.white),
            ),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.download, color: Colors.white),
            title: const Text(
              'Download',
              style: TextStyle(color: Colors.white),
            ),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.flag_outlined, color: Colors.white),
            title: const Text('Report', style: TextStyle(color: Colors.white)),
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}
