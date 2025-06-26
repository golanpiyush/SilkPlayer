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

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => PlayerScreen(video: video)),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildThumbnail(context),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildVideoTitle(),
                  const SizedBox(height: 8),
                  _buildVideoInfo(context, ref, isSaved),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail(BuildContext context) {
    return Stack(
      children: [
        Container(
          height: 200,
          width: double.infinity,
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: CachedNetworkImage(
              imageUrl: video.thumbnailUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: Colors.grey[300],
                child: const Center(child: CircularProgressIndicator()),
              ),
              errorWidget: (context, url, error) => Container(
                color: Colors.grey[300],
                child: const Icon(Icons.error, size: 50, color: Colors.grey),
              ),
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
        if (showTrendingBadge)
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.trending_up, color: Colors.white, size: 14),
                  SizedBox(width: 4),
                  Text(
                    'TRENDING',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildVideoTitle() {
    return Text(
      video.title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.3,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildVideoInfo(BuildContext context, WidgetRef ref, bool isSaved) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                video.author,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  if (video.viewCount != null) ...[
                    Text(
                      video.viewCountString,
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                    Text(
                      ' • ',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                  Text(
                    video.uploadDate != null
                        ? timeago.format(video.uploadDate!)
                        : 'Unknown',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
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
                  isSaved
                      ? 'Removed from saved videos'
                      : 'Added to saved videos',
                ),
                duration: const Duration(seconds: 2),
              ),
            );
          },
          icon: Icon(
            isSaved ? Icons.bookmark : Icons.bookmark_outline,
            color: isSaved ? Theme.of(context).primaryColor : Colors.grey,
          ),
        ),
        IconButton(
          onPressed: () => _showMoreOptions(context, ref),
          icon: const Icon(Icons.more_vert, color: Colors.grey),
        ),
      ],
    );
  }

  void _showMoreOptions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Share'),
              onTap: () {
                Navigator.pop(context);
                // Implement share functionality
              },
            ),
            ListTile(
              leading: const Icon(Icons.playlist_add),
              title: const Text('Add to playlist'),
              onTap: () {
                Navigator.pop(context);
                // Implement add to playlist functionality
              },
            ),
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('Download'),
              onTap: () {
                Navigator.pop(context);
                // Implement download functionality
              },
            ),
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: const Text('Report'),
              onTap: () {
                Navigator.pop(context);
                // Implement report functionality
              },
            ),
          ],
        ),
      ),
    );
  }
}
