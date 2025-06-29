import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:animated_icon/animated_icon.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';

// Future<bool> _checkDeviceArchitecture() async {
//   final deviceInfo = DeviceInfoPlugin();
//   if (Platform.isAndroid) {
//     final androidInfo = await deviceInfo.androidInfo;
//     return androidInfo.supportedAbis?.contains('arm64-v8a') ?? false;
//   }
//   return true; // Default to ARM64 if detection fails
// }

Future<String> getDeviceArchitecture() async {
  try {
    if (Platform.isAndroid) {
      // Try the official method first
      try {
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        final supportedAbis = androidInfo.supportedAbis;

        if (supportedAbis?.contains('arm64-v8a') ?? false) {
          return 'ARM64-v8a';
        } else if (supportedAbis?.contains('armeabi-v7a') ?? false) {
          return 'ARMv7a';
        }
      } catch (e) {
        debugPrint('Official method failed: $e');
      }

      // Fallback to platform properties
      try {
        final abi = await const MethodChannel(
          'flutter/native',
        ).invokeMethod<String>('getAbi');
        if (abi?.contains('arm64') ?? false) return 'ARM64-v8a';
        if (abi?.contains('armeabi') ?? false) return 'ARMv7a';
        return abi ?? 'Unknown';
      } catch (e) {
        debugPrint('Fallback method failed: $e');
      }
    }
    return 'Unknown';
  } catch (e) {
    debugPrint('Error detecting architecture: $e');
    return 'Unknown';
  }
}

Future<void> checkForUpdate(BuildContext context) async {
  const apiUrl =
      'https://api.github.com/repos/golanpiyush/SilkPlayer/releases/latest';
  const timeoutDuration = Duration(seconds: 10);

  try {
    // Show loading indicator with Rive animation
    final completer = Completer<void>();
    _showLoadingDialog(context, completer);

    final response = await http
        .get(Uri.parse(apiUrl))
        .timeout(
          timeoutDuration,
          onTimeout: () {
            throw TimeoutException('Connection timed out');
          },
        );

    if (!context.mounted) return;
    completer.complete();

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final latestVersion = data['tag_name']?.toString().trim() ?? '';
      final releaseUrl = data['html_url'] ?? '';
      final releaseNotes = data['body']?.toString() ?? '';

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version.trim();

      if (_isNewVersionAvailable(currentVersion, latestVersion)) {
        _showModernUpdateDialog(
          context,
          latestVersion,
          releaseUrl,
          releaseNotes,
        );
      } else {
        _showUpToDateToast();
      }
    } else {
      _showErrorToast('Failed to check for updates');
      debugPrint('GitHub API returned status ${response.statusCode}');
    }
  } on TimeoutException {
    if (context.mounted) {
      _showErrorToast('Connection timed out');
    }
  } catch (e) {
    if (context.mounted) {
      _showErrorToast('Update check failed');
    }
    debugPrint('Error checking for update: $e');
  }
}

void _showLoadingDialog(BuildContext context, Completer<void> completer) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => WillPopScope(
      onWillPop: () async => false,
      child: AlertDialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        content: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              Text(
                'Checking for updates...',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  completer.future.then((_) {
    if (context.mounted) {
      Navigator.of(context).pop();
    }
  });
}

// Usage in your dialog
void _showArchitectureDialog(BuildContext context) async {
  final architecture = await getDeviceArchitecture();
  final isArm64 = architecture.contains('64');

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(
        "Device found to be based on",
        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // const Text('Detected device architecture:'),
          // const SizedBox(height: 8),
          Chip(
            label: Text(
              architecture,
              style: GoogleFonts.montserrat(fontWeight: FontWeight.w800),
            ),
            backgroundColor: const Color.fromARGB(255, 105, 38, 29),
          ),

          const SizedBox(height: 16),
          Text(
            'Recommended APP:',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              style: GoogleFonts.poppins(
                color: Colors.black, // base text color
                fontSize: 16,
              ),
              children: [
                TextSpan(
                  text: isArm64
                      ? '"silkplayer-app-arm64-v8a.apk"'
                      : '"sinkplayer-app-armeabi-v7a.apk"',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontStyle: FontStyle.italic,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Universal APK will work but may be larger',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w100),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'OK',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

void _showModernUpdateDialog(
  BuildContext context,
  String version,
  String url,
  String releaseNotes,
) {
  // Color pulse animation controller
  final AnimationController colorController = AnimationController(
    vsync: Navigator.of(context),
    duration: const Duration(milliseconds: 1500),
  )..repeat(reverse: true);

  final ColorTween colorTween = ColorTween(
    begin: const Color.fromARGB(255, 37, 16, 73),
    end: Colors.deepPurple[800],
  );

  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black54,
    barrierLabel: "Update Available",
    transitionDuration: const Duration(milliseconds: 500),
    pageBuilder: (_, __, ___) => const SizedBox.shrink(),
    transitionBuilder: (context, anim, __, ___) {
      final tween = Tween<double>(
        begin: 0,
        end: 1,
      ).chain(CurveTween(curve: Curves.easeOutBack));

      return FadeTransition(
        opacity: anim,
        child: ScaleTransition(
          scale: anim.drive(tween),
          child: AlertDialog(
            backgroundColor: Theme.of(context).dialogBackgroundColor,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            actionsPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            title: Stack(
              children: [
                Column(
                  children: [
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: AnimateIcon(
                        key: UniqueKey(),
                        onTap: () {},
                        iconType: IconType.continueAnimation,
                        height: 170,
                        width: 170,
                        color: Colors.deepPurple,
                        animateIcon: AnimateIcons.download,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'New Build Available!',
                      style: GoogleFonts.preahvihear(
                        textStyle: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                      ),
                    ),
                  ],
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: IconButton(
                    icon: Icon(Icons.info_outline, color: Colors.deepPurple),
                    onPressed: () {
                      Navigator.of(context).pop();
                      _showArchitectureDialog(context);
                    },
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Build version: $version',
                    style: GoogleFonts.preahvihear(
                      textStyle: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(
                            color: const Color.fromARGB(255, 157, 167, 17),
                          ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (releaseNotes.isNotEmpty) ...[
                    Text(
                      'What\'s New:',
                      style: GoogleFonts.preahvihear(
                        textStyle: Theme.of(context).textTheme.bodyMedium,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.left,
                    ),
                    const SizedBox(height: 8),
                    MarkdownBody(
                      data: releaseNotes,
                      styleSheet: MarkdownStyleSheet(
                        p: GoogleFonts.preahvihear(
                          textStyle: Theme.of(context).textTheme.bodyMedium,
                        ),
                        h2: GoogleFonts.preahvihear(
                          textStyle: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        strong: const TextStyle(fontWeight: FontWeight.bold),
                        del: const TextStyle(
                          decoration: TextDecoration.lineThrough,
                        ),
                        code: const TextStyle(
                          fontFamily: 'monospace',
                          backgroundColor: Color(0xFF1E1E1E),
                          color: Color(0xFFB5CEA8),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).textTheme.bodyLarge?.color,
                  side: BorderSide(color: Theme.of(context).dividerColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  _showWarningToast();
                },
                child: const Text('Later'),
              ),
              AnimatedBuilder(
                animation: colorController,
                builder: (context, child) {
                  return ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorTween.evaluate(colorController),
                      foregroundColor: Colors.white,
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shadowColor: Colors.deepPurple.withOpacity(0.5),
                    ),
                    onPressed: () async {
                      colorController.dispose();
                      Navigator.of(context).pop();
                      final uri = Uri.parse(url);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                          webViewConfiguration: const WebViewConfiguration(
                            enableJavaScript: true,
                          ),
                        );
                      } else {
                        _showErrorToast('Could not launch browser');
                      }
                    },
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.update_rounded, size: 20),
                        SizedBox(width: 8),
                        Text('Update Now'),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}

void _showUpToDateToast() {
  Fluttertoast.showToast(
    msg: "You're using the latest build/version",
    toastLength: Toast.LENGTH_SHORT,
    gravity: ToastGravity.TOP,
    backgroundColor: Colors.green,
    textColor: Colors.white,
    fontSize: 14.0,
    webShowClose: true,
    webBgColor: "linear-gradient(to right, #00b09b, #96c93d)",
  );
}

void _showErrorToast(String message) {
  Fluttertoast.showToast(
    msg: message,
    toastLength: Toast.LENGTH_SHORT,
    gravity: ToastGravity.BOTTOM,
    backgroundColor: Colors.red,
    textColor: Colors.white,
    fontSize: 14.0,
    webShowClose: true,
    webBgColor: "linear-gradient(to right, #ff416c, #ff4b2b)",
  );
}

void _showWarningToast() {
  Fluttertoast.showToast(
    msg: "⚠️ App may break anytime! 💀",
    toastLength: Toast.LENGTH_LONG,
    gravity: ToastGravity.CENTER,
    backgroundColor: Colors.orange[800],
    textColor: Colors.white,
    fontSize: 16.0,
    webShowClose: true,
    webBgColor: "linear-gradient(to right, #f12711, #f5af19)",
  );
}

bool _isNewVersionAvailable(String current, String latest) {
  List<int> parse(String v) => v
      .replaceAll(RegExp(r'[^\d.]'), '')
      .split('.')
      .map(int.tryParse)
      .whereType<int>()
      .toList();

  final cur = parse(current);
  final lat = parse(latest);

  for (int i = 0; i < lat.length; i++) {
    if (i >= cur.length || lat[i] > cur[i]) return true;
    if (lat[i] < cur[i]) return false;
  }
  return false;
}
