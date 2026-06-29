import 'dart:convert';
import 'dart:io';

/// Caches pub.dev and GitHub API responses on disk for 24 hours to avoid
/// hitting rate limits on repeated runs.
class CacheService {
  final Directory _cacheDir;

  /// Creates a cache backed by the `.dart_tool/flutter_spm_doctor` directory,
  /// creating it if it doesn't already exist.
  CacheService() : _cacheDir = Directory('.dart_tool/flutter_spm_doctor') {
    if (!_cacheDir.existsSync()) {
      _cacheDir.createSync(recursive: true);
    }
  }

  File _getCacheFile(String key) {
    // Basic sanitization
    final safeKey = key.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    return File('${_cacheDir.path}/$safeKey.json');
  }

  /// Returns the cached value for [key], or `null` if missing or older
  /// than 24 hours.
  Future<Map<String, dynamic>?> get(String key) async {
    final file = _getCacheFile(key);
    if (await file.exists()) {
      final stat = await file.stat();
      final now = DateTime.now();
      // Cache for 24 hours
      if (now.difference(stat.modified).inHours < 24) {
        try {
          final content = await file.readAsString();
          return jsonDecode(content) as Map<String, dynamic>;
        } catch (e) {
          // If cache is corrupted, return null
          return null;
        }
      }
    }
    return null;
  }

  /// Stores [data] in the cache under [key], overwriting any existing entry.
  Future<void> set(String key, Map<String, dynamic> data) async {
    final file = _getCacheFile(key);
    await file.writeAsString(jsonEncode(data));
  }
}
