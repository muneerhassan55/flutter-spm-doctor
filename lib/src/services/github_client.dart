import 'dart:convert';

import 'package:http/http.dart' as http;
import 'cache_service.dart';

/// A parsed GitHub repository reference: owner/repo, an assumed default
/// branch, and an optional monorepo subdirectory (e.g. for repos where the
/// pub.dev `repository` URL points at `tree/main/packages/foo`).
class GithubRepoRef {
  final String owner;
  final String repo;
  final String branch;
  final String subPath;

  const GithubRepoRef({
    required this.owner,
    required this.repo,
    required this.branch,
    required this.subPath,
  });
}

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

    final ref = parseRepoUrl(repoUrl);
    if (ref == null) return null;
    final owner = ref.owner;
    final repo = ref.repo;
    final branch = ref.branch;
    final subPath = ref.subPath;

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

  /// Parses a pub.dev `repository`/`homepage` URL into a [GithubRepoRef],
  /// or returns `null` if [repoUrl] doesn't point at github.com.
  ///
  /// Handles monorepo URLs of the form `.../tree/<branch>/path/to/package`,
  /// resolving [GithubRepoRef.subPath] to the package's subdirectory.
  static GithubRepoRef? parseRepoUrl(String repoUrl) {
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

    return GithubRepoRef(
      owner: owner,
      repo: repo,
      branch: branch,
      subPath: subPath,
    );
  }

  /// Lists files directly inside [dirPath] of the repo at [repoUrl] (one
  /// level, not recursive), trying `main` then `master`. Returns `null` if
  /// the directory doesn't exist on either branch, the repo URL can't be
  /// parsed, or the API call fails (e.g. rate limit) — callers should treat
  /// `null` as "unknown", not "empty".
  Future<List<String>?> listDirectory(String repoUrl, String dirPath) async {
    final ref = parseRepoUrl(repoUrl);
    if (ref == null) return null;

    final fullPath = '${ref.subPath}$dirPath';

    for (final branch in {ref.branch, 'master'}) {
      final result = await _listDirectoryOnBranch(
        ref.owner,
        ref.repo,
        branch,
        fullPath,
      );
      if (result != null) return result;
    }
    return null;
  }

  Future<List<String>?> _listDirectoryOnBranch(
    String owner,
    String repo,
    String branch,
    String dirPath,
  ) async {
    final headers = <String, String>{
      'Accept': 'application/vnd.github.v3+json',
    };
    final token = _token;
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    try {
      final response = await _client.get(
        Uri.parse(
          'https://api.github.com/repos/$owner/$repo/contents/$dirPath?ref=$branch',
        ),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> entries = jsonDecode(response.body);
        return entries
            .where((e) => e is Map && e['type'] == 'file')
            .map((e) => e['path'] as String)
            .toList();
      }
    } catch (_) {
      // Network error; fall through to null.
    }
    return null;
  }

  /// Fetches the raw text content of [filePath] from the repo at [repoUrl]
  /// on [branch]. Returns `null` on any failure (missing file, network
  /// error, rate limit) rather than throwing, so callers can treat it as
  /// "unknown" alongside other heuristic gaps.
  Future<String?> fetchRawFile(
    String repoUrl,
    String filePath, {
    required String branch,
  }) async {
    final ref = parseRepoUrl(repoUrl);
    if (ref == null) return null;

    final headers = <String, String>{};
    final token = _token;
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    try {
      final response = await _client.get(
        Uri.parse(
          'https://raw.githubusercontent.com/${ref.owner}/${ref.repo}/$branch/$filePath',
        ),
        headers: headers,
      );
      if (response.statusCode == 200) {
        return response.body;
      }
    } catch (_) {
      // Network error; fall through to null.
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
