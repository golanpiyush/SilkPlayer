import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:silkplayer/providers/provider.dart';
import '../widgets/video_card.dart';
import '../widgets/loading_shimmer.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedCountry = ref.watch(selectedCountryProvider);

    final videosAsync = selectedCountry.toLowerCase() != 'india'
        ? (() {
            debugPrint('🗺️ Loading geo-targeted videos for $selectedCountry');
            return ref.watch(geoTargetedVideosProvider(selectedCountry));
          })()
        : (() {
            debugPrint('🎲 Loading random videos (country: $selectedCountry)');
            return ref.watch(randomVideosProvider);
          })();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: AppBar(
          backgroundColor: Colors.black,
          elevation: 0,
          titleSpacing: 12,
          title: Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: TextButton(
              onPressed: () {
                if (selectedCountry.toLowerCase() != 'india') {
                  ref.invalidate(geoTargetedVideosProvider(selectedCountry));
                  Fluttertoast.showToast(
                    msg: "Refreshing videos for $selectedCountry 🇮🇳",
                    toastLength: Toast.LENGTH_SHORT,
                    backgroundColor: Colors.grey[800],
                    textColor: Colors.white,
                    fontSize: 14.0,
                  );
                } else {
                  ref.read(forceRandomVideosReloadProvider.notifier).state =
                      true;
                  ref.invalidate(randomVideosProvider);
                  Fluttertoast.showToast(
                    msg: "Refreshing random trending videos 🔄",
                    toastLength: Toast.LENGTH_SHORT,
                    backgroundColor: Colors.grey[800],
                    textColor: Colors.white,
                    fontSize: 14.0,
                  );
                  Future.delayed(const Duration(milliseconds: 500), () {
                    ref.read(forceRandomVideosReloadProvider.notifier).state =
                        false;
                  });
                }
              },
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'SilkPlayer',
                style: GoogleFonts.permanentMarker(
                  color: Colors.blueAccent,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  shadows: [
                    // Core glow (brightest)
                    Shadow(
                      color: Colors.blueAccent.withOpacity(0.5),
                      offset: Offset(7, 5),
                      blurRadius: 10,
                    ),
                    // Primary glow
                    // Shadow(
                    //   color: Colors.blueAccent,
                    //   offset: Offset(7, 5),
                    //   blurRadius: 20,
                    // ),
                    // Outer glow (more diffuse)
                    // Shadow(
                    //   color: Colors.blueAccent.withOpacity(0.7),
                    //   offset: Offset(7, 5),
                    //   blurRadius: 10,
                    // ),
                    // X+2, Y+4 offset shadow as requested
                    Shadow(
                      color: Colors.blueAccent.withOpacity(0.5),
                      offset: Offset(1, 4),
                      blurRadius: 10,
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey.shade900,
                ),
                child: IconButton(
                  icon: const Icon(Icons.search, color: Colors.white),
                  onPressed: () async {
                    await showSearch(
                      context: context,
                      delegate: AnimatedVideoSearchDelegate(ref),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      body: videosAsync.when(
        data: (videos) {
          if (videos.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Lottie.asset(
                    'assets/animations/not_found.json',
                    width: 320,
                    height: 320,
                    repeat: true,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No videos found',
                    style: GoogleFonts.montserrat(
                      fontSize: 18,
                      color: Colors.grey,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              selectedCountry.toLowerCase() != 'india'
                  ? ref.invalidate(geoTargetedVideosProvider(selectedCountry))
                  : ref.invalidate(randomVideosProvider);
            },
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: videos.length,
              itemBuilder: (context, index) {
                return VideoCard(video: videos[index]);
              },
            ),
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
                  selectedCountry.toLowerCase() != 'india'
                      ? ref.invalidate(
                          geoTargetedVideosProvider(selectedCountry),
                        )
                      : ref.invalidate(randomVideosStreamProvider);
                },
                child: Text(
                  'Retry',
                  style: GoogleFonts.montserrat(letterSpacing: 0.4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AnimatedVideoSearchDelegate extends SearchDelegate<String> {
  final WidgetRef ref;
  AnimatedVideoSearchDelegate(this.ref);

  List<String> _searchHistory = [];

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
    _searchHistory = prefs.getStringList('searchHistory') ?? [];
  }

  Future<void> _saveSearchHistory(String term) async {
    final prefs = await SharedPreferences.getInstance();
    if (!_searchHistory.contains(term)) {
      _searchHistory.insert(0, term);
      if (_searchHistory.length > 10)
        _searchHistory = _searchHistory.sublist(0, 10);
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

    // Use Consumer to force rebuild when provider changes
    return Consumer(
      builder: (context, ref, child) {
        final searchResultsAsync = ref.watch(videoSearchProvider(query));

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: searchResultsAsync.when(
            data: (videos) {
              if (videos.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.search_off,
                        size: 64,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No results found for "$query"',
                        style: GoogleFonts.montserrat(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }
              return ListView.builder(
                key: ValueKey(query), // Key to force rebuild
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
                    onPressed: () {
                      // Force refresh the provider
                      ref.invalidate(videoSearchProvider(query));
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
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
          // Show filtered search history based on current query
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
                  // Force rebuild of suggestions
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

  // Helper method to highlight matching text in suggestions
  List<TextSpan> _highlightMatch(String text, String query) {
    if (query.isEmpty) {
      return [TextSpan(text: text)];
    }

    final matches = query.toLowerCase();
    final textLower = text.toLowerCase();

    if (!textLower.contains(matches)) {
      return [TextSpan(text: text)];
    }

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
            backgroundColor: Colors.yellow,
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
