import 'package:http/http.dart' as http;
import 'cache_service.dart';

/// Checks a plugin's GitHub repository for an `ios/Package.swift` or
/// `macos/Package.swift` file to determine SPM support directly from source.
class GithubClient {
  final http.Client _client;
  final CacheService _cache;
  final String? _token;

  /// Creates a client backed by [_client] for HTTP calls, [_cache] for
  /// caching lookups, and an optional [token] to raise GitHub API rate limits.
  GithubClient(this._client, this._cache, {String? token}) : _token = token;

  /// Checks if the repo contains a Package.swift in the ios/ or macos/ directories.
  /// Returns true if supported, false if not, or null if unknown (e.g. rate limit, bad url).
  Future<bool?> hasPackageSwift(String repoUrl) async {
    final cacheKey = 'github_spm_$repoUrl';
    final cached = await _cache.get(cacheKey);

    if (cached != null) {
      return cached['hasPackageSwift'] as bool;
    }

    // Parse github URL
    final uri = Uri.tryParse(repoUrl);
    if (uri == null || uri.host != 'github.com') return null;

    final pathSegments = uri.pathSegments;
    if (pathSegments.length < 2) return null;

    final owner = pathSegments[0];
    final repo = pathSegments[1];

    // If it's a monorepo, the URL might be like: tree/main/packages/url_launcher
    String subPath = '';
    String branch = 'main'; // Assume main, fallback to master if needed

    if (pathSegments.length > 4 && pathSegments[2] == 'tree') {
      branch = pathSegments[3];
      subPath = '${pathSegments.sublist(4).join('/')}/';
    }

    final hasIos = await _checkFileExists(
      owner,
      repo,
      branch,
      '${subPath}ios/Package.swift',
    );
    final hasMacos = await _checkFileExists(
      owner,
      repo,
      branch,
      '${subPath}macos/Package.swift',
    );

    // If neither found on 'main', try 'master'
    if (hasIos == null && hasMacos == null && branch == 'main') {
      final hasIosMaster = await _checkFileExists(
        owner,
        repo,
        'master',
        '${subPath}ios/Package.swift',
      );
      final hasMacosMaster = await _checkFileExists(
        owner,
        repo,
        'master',
        '${subPath}macos/Package.swift',
      );

      if (hasIosMaster == true || hasMacosMaster == true) {
        await _cache.set(cacheKey, {'hasPackageSwift': true});
        return true;
      }
      if (hasIosMaster == false && hasMacosMaster == false) {
        await _cache.set(cacheKey, {'hasPackageSwift': false});
        return false;
      }
    }

    if (hasIos == true || hasMacos == true) {
      await _cache.set(cacheKey, {'hasPackageSwift': true});
      return true;
    }

    if (hasIos == false && hasMacos == false) {
      await _cache.set(cacheKey, {'hasPackageSwift': false});
      return false;
    }

    return null;
  }

  Future<bool?> _checkFileExists(
    String owner,
    String repo,
    String branch,
    String path,
  ) async {
    final headers = <String, String>{
      'Accept': 'application/vnd.github.v3+json',
    };

    final token = _token;
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    try {
      final response = await _client.head(
        Uri.parse(
          'https://raw.githubusercontent.com/$owner/$repo/$branch/$path',
        ),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return true;
      } else if (response.statusCode == 404) {
        return false;
      } else if (response.statusCode == 403) {
        // Rate limit
        return null;
      }
    } catch (e) {
      // Network error
    }
    return null;
  }
}
