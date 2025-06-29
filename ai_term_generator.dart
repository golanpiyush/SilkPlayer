// ai_term_generator.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class AIGeoKeywordGenerator {
  static const String _baseUrl = 'https://openrouter.ai/api/v1';
  static const String _apiKey = 'sexy';
  static const String _cacheFileName = 'ai_geo_term_cache.json';

  static Map<String, String> get _headers => {
    'Authorization': 'Bearer $_apiKey',
    'Content-Type': 'application/json',
    'HTTP-Referer': 'https://sinkplayer.com',
    'X-Title': 'Sink Player',
  };

  static Future<List<String>> generateUniqueTerms(String countryName) async {
    final cache = await _loadFromCache();
    final usedTerms = cache[countryName] ?? <String>[];

    final prompt =
        '''
Generate 5 new popular YouTube search terms used by people in $countryName.
These terms must be:
- Between 2 to 5 words
- Related to music, tech, education, fitness, gaming, or culture
- Different from these previously used terms:
${usedTerms.join(', ')}
Return the list in raw format without numbers or formatting.
''';

    final response = await http.post(
      Uri.parse('$_baseUrl/chat/completions'),
      headers: _headers,
      body: jsonEncode({
        "model": "google/gemma-3n-e4b-it:free",
        "messages": [
          {"role": "user", "content": prompt},
        ],
      }),
    );

    final Map<String, dynamic> body = jsonDecode(response.body);
    final text = body['choices'][0]['message']['content'] as String;
    final terms = text
        .split(RegExp(r'\n|\r'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty && !usedTerms.contains(e))
        .toList();

    cache[countryName] = [...usedTerms, ...terms];
    await _saveToCache(cache);

    return terms;
  }

  static Future<File> _getCacheFile() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = dir.path;
    return File('$path/$_cacheFileName');
  }

  static Future<void> _saveToCache(Map<String, dynamic> data) async {
    try {
      final file = await _getCacheFile();
      await file.writeAsString(jsonEncode(data));
    } catch (e) {
      print('Failed to write cache: $e');
    }
  }

  static Future<Map<String, dynamic>> _loadFromCache() async {
    try {
      final file = await _getCacheFile();
      if (await file.exists()) {
        final contents = await file.readAsString();
        return jsonDecode(contents);
      }
    } catch (e) {
      print('Failed to load cache: $e');
    }
    return {};
  }
}
