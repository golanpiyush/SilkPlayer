import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';

Future<String> getDeviceArchitecture() async {
  try {
    if (Platform.isAndroid) {
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
    final response = await http
        .get(Uri.parse(apiUrl))
        .timeout(
          timeoutDuration,
          onTimeout: () => throw TimeoutException('Connection timed out'),
        );

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
    _showErrorToast('Connection timed out');
  } catch (e) {
    _showErrorToast('Update check failed');
    debugPrint('Error checking for update: $e');
  }
}

void _showArchitectureDialog(BuildContext context) async {
  final architecture = await getDeviceArchitecture();
  final isArm64 = architecture.contains('64');

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(
        "Device Architecture",
        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Chip(
            label: Text(
              architecture,
              style: GoogleFonts.montserrat(fontWeight: FontWeight.w800),
            ),
            backgroundColor: const Color.fromARGB(255, 105, 38, 29),
          ),
          const SizedBox(height: 16),
          Text(
            'Recommended App:',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            isArm64
                ? '"silkplayer-app-arm64-v8a.apk"'
                : '"sinkplayer-app-armeabi-v7a.apk"',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              fontStyle: FontStyle.italic,
              color: Colors.red,
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
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Column(
        children: [
          const Icon(Icons.update, size: 50, color: Colors.deepPurple),
          const SizedBox(height: 16),
          Text(
            'Update Available!',
            style: GoogleFonts.preahvihear(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.red,
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
              'Version: $version',
              style: GoogleFonts.preahvihear(
                fontSize: 18,
                color: const Color.fromARGB(255, 157, 167, 17),
              ),
            ),
            const SizedBox(height: 16),
            if (releaseNotes.isNotEmpty) ...[
              Text(
                'Release Notes:',
                style: GoogleFonts.preahvihear(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              MarkdownBody(
                data: releaseNotes,
                styleSheet: MarkdownStyleSheet(
                  p: GoogleFonts.preahvihear(fontSize: 14),
                  h2: GoogleFonts.preahvihear(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Procrastinates'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
          ),
          onPressed: () async {
            Navigator.pop(context);
            final uri = Uri.parse(url);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri);
            } else {
              _showErrorToast('Could not launch browser');
            }
          },
          child: const Text('Update Now'),
        ),
      ],
    ),
  );
}

void _showUpToDateToast() {
  Fluttertoast.showToast(
    msg: "You're at the latest build",
    toastLength: Toast.LENGTH_SHORT,
    gravity: ToastGravity.BOTTOM,
    backgroundColor: const Color.fromARGB(31, 76, 175, 79),
    textColor: Colors.white,
  );
}

void _showErrorToast(String message) {
  Fluttertoast.showToast(
    msg: message,
    toastLength: Toast.LENGTH_SHORT,
    gravity: ToastGravity.BOTTOM,
    backgroundColor: Colors.red,
    textColor: Colors.white,
  );
}

bool _isNewVersionAvailable(String current, String latest) {
  final currentParts = current.split('.');
  final latestParts = latest.split('.');

  for (int i = 0; i < latestParts.length; i++) {
    final latestNum = int.tryParse(latestParts[i]) ?? 0;
    final currentNum = i < currentParts.length
        ? int.tryParse(currentParts[i]) ?? 0
        : 0;

    if (latestNum > currentNum) return true;
    if (latestNum < currentNum) return false;
  }
  return false;
}
