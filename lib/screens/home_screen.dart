import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'package:silkplayer/models/video_model.dart';
import 'package:silkplayer/providers/provider.dart';
import '../widgets/video_card.dart';
import '../widgets/loading_shimmer.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedCountry = ref.watch(selectedCountryProvider);
    final videosAsync = ref.watch(randomVideosStreamProvider);
    const targetCount = 60; // Target number of videos to load

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        titleSpacing: 12,
        title: Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: TextButton(
            onPressed: () => _handleRefresh(ref),
            child: Text(
              'SilkPlayer',
              style: GoogleFonts.permanentMarker(
                color: Colors.blueAccent,
                fontSize: 28,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                shadows: [
                  Shadow(
                    color: Colors.blueAccent.withOpacity(0.5),
                    offset: const Offset(7, 5),
                    blurRadius: 10,
                  ),
                  Shadow(
                    color: Colors.blueAccent.withOpacity(0.5),
                    offset: const Offset(1, 4),
                    blurRadius: 10,
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () => showSearch(
              context: context,
              delegate: AnimatedVideoSearchDelegate(ref),
            ),
          ),
        ],
      ),
      body: videosAsync.when(
        loading: () =>
            const LoadingShimmer(targetCount: targetCount, opacity: 0.3),
        error: (error, stack) => _buildErrorWidget(error, ref, selectedCountry),
        data: (loadedVideos) {
          return _buildVideoListWithProgress(
            loadedVideos,
            targetCount,
            ref,
            selectedCountry,
          );
        },
      ),
    );
  }

  Future<void> _handleRefresh(WidgetRef ref) async {
    final videoService = ref.watch(videoServiceProvider);
    await videoService.forceRefreshAllCaches(ref);

    _showToast("Cache refreshed successfully");
  }

  void _showToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      backgroundColor: Colors.grey[800],
      textColor: Colors.white,
      fontSize: 14.0,
    );
  }

  Widget _buildVideoListWithProgress(
    List<VideoModel> loadedVideos,
    int targetCount,
    WidgetRef ref,
    String selectedCountry,
  ) {
    return RefreshIndicator(
      onRefresh: () async {
        if (selectedCountry.toLowerCase() != 'india') {
          ref.invalidate(geoTargetedVideosStreamProvider(selectedCountry));
        } else {
          ref.invalidate(randomVideosProvider);
          ref.invalidate(randomVideosStreamProvider);
        }
      },
      child: CustomScrollView(
        slivers: [
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              if (index < loadedVideos.length) {
                return VideoCard(video: loadedVideos[index]);
              }
              return _buildShimmerItem(context);
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerItem(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Shimmer.fromColors(
        baseColor: Colors.grey[800]!,
        highlightColor: Colors.grey[700]!,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            SizedBox(height: 12), // Fixed - removed const
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 12), // Also fixed this one
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 16,
                        width: double.infinity,
                        color: Colors.white,
                      ),
                      SizedBox(height: 8), // And this one
                      Container(
                        height: 14,
                        width: MediaQuery.of(context).size.width * 0.6,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget(
    Object error,
    WidgetRef ref,
    String selectedCountry,
  ) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            'Error loading videos',
            style: GoogleFonts.montserrat(
              fontSize: 18,
              color: Colors.grey[600],
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error.toString(),
            style: GoogleFonts.montserrat(
              fontSize: 14,
              color: Colors.grey[500],
              letterSpacing: 0.25,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              if (selectedCountry.toLowerCase() != 'india') {
                ref.invalidate(
                  geoTargetedVideosStreamProvider(selectedCountry),
                );
              } else {
                ref.invalidate(randomVideosProvider);
                ref.invalidate(randomVideosStreamProvider);
              }
            },
            child: Text(
              'Retry',
              style: GoogleFonts.montserrat(letterSpacing: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}

class AnimatedVideoSearchDelegate extends SearchDelegate<String> {
  final WidgetRef ref;
  AnimatedVideoSearchDelegate(this.ref);

  final List<String> _searchHistory = [];

  @override
  ThemeData appBarTheme(BuildContext context) {
    return Theme.of(context).copyWith(
      inputDecorationTheme: const InputDecorationTheme(
        border: InputBorder.none,
      ),
    );
  }

  Future<void> _loadSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList('searchHistory') ?? [];
    _searchHistory.clear();
    _searchHistory.addAll(history);
  }

  Future<void> _saveSearchHistory(String term) async {
    final prefs = await SharedPreferences.getInstance();
    if (!_searchHistory.contains(term)) {
      _searchHistory.insert(0, term);
      if (_searchHistory.length > 10) {
        _searchHistory.removeRange(10, _searchHistory.length);
      }
      await prefs.setStringList('searchHistory', _searchHistory);
    }
  }

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
          showSuggestions(context);
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, '');
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    if (query.trim().isEmpty) {
      return const Center(child: Text('Please enter a search term'));
    }

    _saveSearchHistory(query);

    return Consumer(
      builder: (context, ref, child) {
        final searchResultsAsync = ref.watch(videoSearchProvider(query));

        return searchResultsAsync.when(
          data: (videos) {
            if (videos.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.search_off, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text(
                      'No results found for "$query"',
                      style: GoogleFonts.montserrat(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: videos.length,
              itemBuilder: (context, index) {
                return VideoCard(video: videos[index]);
              },
            );
          },
          loading: () => const LoadingShimmer(),
          error: (error, stackTrace) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Error loading search results',
                  style: GoogleFonts.montserrat(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(videoSearchProvider(query)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return FutureBuilder(
      future: _loadSearchHistory(),
      builder: (context, snapshot) {
        if (query.isNotEmpty) {
          final filteredHistory = _searchHistory
              .where((term) => term.toLowerCase().contains(query.toLowerCase()))
              .take(5)
              .toList();

          if (filteredHistory.isNotEmpty) {
            return ListView.builder(
              itemCount: filteredHistory.length,
              itemBuilder: (context, index) {
                final term = filteredHistory[index];
                return ListTile(
                  title: RichText(
                    text: TextSpan(
                      children: _highlightMatch(term, query),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  leading: const Icon(Icons.history, color: Colors.grey),
                  onTap: () {
                    query = term;
                    showResults(context);
                  },
                );
              },
            );
          }
        }

        if (_searchHistory.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.search, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  'Search for videos',
                  style: GoogleFonts.montserrat(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: _searchHistory.length,
          itemBuilder: (context, index) {
            final term = _searchHistory[index];
            return ListTile(
              title: Text(term),
              leading: const Icon(Icons.history, color: Colors.grey),
              trailing: IconButton(
                icon: const Icon(Icons.close, color: Colors.grey),
                onPressed: () async {
                  _searchHistory.removeAt(index);
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setStringList('searchHistory', _searchHistory);
                  showSuggestions(context);
                },
              ),
              onTap: () {
                query = term;
                showResults(context);
              },
            );
          },
        );
      },
    );
  }

  List<TextSpan> _highlightMatch(String text, String query) {
    if (query.isEmpty) return [TextSpan(text: text)];

    final matches = query.toLowerCase();
    final textLower = text.toLowerCase();

    if (!textLower.contains(matches)) return [TextSpan(text: text)];

    final List<TextSpan> spans = [];
    int start = 0;
    int indexOfHighlight = textLower.indexOf(matches, start);

    while (indexOfHighlight >= 0) {
      if (indexOfHighlight > start) {
        spans.add(TextSpan(text: text.substring(start, indexOfHighlight)));
      }
      spans.add(
        TextSpan(
          text: text.substring(
            indexOfHighlight,
            indexOfHighlight + query.length,
          ),
          style: const TextStyle(
            backgroundColor: Colors.lightGreen,
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
      start = indexOfHighlight + query.length;
      indexOfHighlight = textLower.indexOf(matches, start);
    }

    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start)));
    }

    return spans;
  }
}
