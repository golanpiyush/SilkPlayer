import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class BlurBanner extends StatefulWidget {
  final VoidCallback? onFinish;

  const BlurBanner({super.key, this.onFinish});

  @override
  State<BlurBanner> createState() => _BlurBannerState();
}

class _BlurBannerState extends State<BlurBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _blurAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
    );

    _blurAnimation = Tween<double>(begin: 0, end: 12).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
    );

    _controller.forward();

    // Auto hide after 4s with fade out
    Future.delayed(const Duration(seconds: 4), () async {
      await _controller.reverse();
      widget.onFinish?.call();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          children: [
            // Full-screen blur effect with smooth animation
            Positioned.fill(
              child: Opacity(
                opacity: _fadeAnimation.value,
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: _blurAnimation.value,
                    sigmaY: _blurAnimation.value,
                  ),
                  child: Container(
                    color: Colors.black.withOpacity(0.3 * _fadeAnimation.value),
                  ),
                ),
              ),
            ),
            // Centered text moved down
            Center(
              child: Transform.translate(
                offset: Offset(0, 60), // Move text down by 60 pixels
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Text(
                    'Checking for updates...',
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
