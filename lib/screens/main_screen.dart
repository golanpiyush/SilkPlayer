import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:silkplayer/utils/update_checker.dart';
import 'home_screen.dart';
import 'trending_screen.dart';
import 'saved_video_screen.dart';
import 'settings_screen.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  late List<AnimationController> _animationControllers;
  late List<Animation<double>> _scaleAnimations;
  late List<Animation<double>> _fadeAnimations;
  late List<Animation<Offset>> _slideAnimations;

  final List<Widget> _screens = [
    const HomeScreen(),
    const TrendingScreen(),
    const SavedVideosScreen(),
    const SettingsScreen(),
  ];

  final List<Map<String, dynamic>> _navItems = [
    {'icon': Icons.home_outlined, 'activeIcon': Icons.home, 'label': 'Home'},
    {
      'icon': Icons.local_fire_department_outlined,
      'activeIcon': Icons.local_fire_department,
      'label': 'Trending',
    },
    {
      'icon': Icons.bookmark_outline,
      'activeIcon': Icons.bookmark,
      'label': 'Saved',
    },
    {'icon': Icons.settings, 'activeIcon': Icons.settings, 'label': 'Settings'},
  ];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();

    // Check for updates after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        checkForUpdate(context);
      }
    });
  }

  void _initializeAnimations() {
    // Initialize animation controllers with shorter duration for better performance
    _animationControllers = List.generate(
      _navItems.length,
      (index) => AnimationController(
        duration: const Duration(milliseconds: 1400),
        vsync: this,
      ),
    );

    // Initialize scale animations with more subtle scaling
    _scaleAnimations = _animationControllers
        .map(
          (controller) => Tween<double>(begin: 1.0, end: 1.05).animate(
            CurvedAnimation(parent: controller, curve: Curves.easeOutCubic),
          ),
        )
        .toList();

    // Initialize fade animations
    _fadeAnimations = _animationControllers
        .map(
          (controller) => Tween<double>(
            begin: 0.0,
            end: 1.0,
          ).animate(CurvedAnimation(parent: controller, curve: Curves.easeOut)),
        )
        .toList();

    // In _initializeAnimations() method, replace the slide animations part:

    // Initialize slide animations with right to left movement
    _slideAnimations = _animationControllers
        .map(
          (controller) =>
              Tween<Offset>(
                begin: const Offset(-0.6, 0), // Start from right (positive X)
                end: Offset.zero, // End at center
              ).animate(
                CurvedAnimation(parent: controller, curve: Curves.easeOutQuart),
              ),
        )
        .toList();

    // Start animation for the initial selected tab
    _animationControllers[0].forward();
  }

  @override
  void dispose() {
    // Properly dispose all animation controllers
    for (var controller in _animationControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onTabTapped(int index) {
    if (_currentIndex != index && mounted) {
      // Reverse animation for current tab
      _animationControllers[_currentIndex].reverse();

      setState(() {
        _currentIndex = index;
      });

      // Forward animation for new tab
      _animationControllers[index].forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: _buildAnimatedBottomBar(),
    );
  }

  Widget _buildAnimatedBottomBar() {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(124),
        topRight: Radius.circular(24),
      ),
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color:
              Theme.of(context).bottomAppBarTheme.color ??
              Theme.of(context).scaffoldBackgroundColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              spreadRadius: 0,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 12.0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(
                _navItems.length,
                (index) => Expanded(
                  flex: _currentIndex == index ? 2 : 1,
                  child: _buildAnimatedTabItem(index),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedTabItem(int index) {
    final isSelected = _currentIndex == index;
    final item = _navItems[index];

    return AnimatedBuilder(
      animation: _animationControllers[index],
      builder: (context, child) {
        final color = isSelected
            ? Colors.green
            : Theme.of(context).unselectedWidgetColor;

        return GestureDetector(
          onTap: () => _onTabTapped(index),
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon container with background
                AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutCubic,
                  padding: EdgeInsets.symmetric(
                    horizontal: isSelected ? 16 : 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.blueAccent.withOpacity(0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(25),
                  ),

                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ScaleTransition(
                        scale: isSelected
                            ? _scaleAnimations[index]
                            : const AlwaysStoppedAnimation(1.0),
                        child: Icon(
                          isSelected ? item['activeIcon'] : item['icon'],
                          size: 28,
                          color: color,
                        ),
                      ),
                      if (isSelected) ...[
                        const SizedBox(width: 8),
                        Flexible(
                          child: SlideTransition(
                            position: _slideAnimations[index],
                            child: FadeTransition(
                              opacity: _fadeAnimations[index],
                              child: Text(
                                item['label'],
                                style: GoogleFonts.preahvihear(
                                  color: Colors
                                      .green, // or use `color` to inherit selected/unselected state
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
