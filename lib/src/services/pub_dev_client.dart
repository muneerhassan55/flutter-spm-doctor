import 'dart:convert';
import 'package:http/http.dart' as http;
import 'cache_service.dart';

/// Fetches package metadata from the pub.dev API to determine whether a
/// package is a native iOS/macOS plugin and where its source repo lives.
class PubDevClient {
  final http.Client _client;
  final CacheService _cache;

  /// Creates a client backed by [_client] for HTTP calls and [_cache] for
  /// caching responses across runs.
  PubDevClient(this._client, this._cache);

  /// Fetches package info and returns [repoUrl, isPlugin]
  Future<PubPackageInfo?> getPackageInfo(String packageName) async {
    final cacheKey = 'pub_dev_$packageName';
    final cached = await _cache.get(cacheKey);

    if (cached != null) {
      return PubPackageInfo.fromJson(cached);
    }

    try {
      final response = await _client.get(
        Uri.parse('https://pub.dev/api/packages/$packageName'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final latest = data['latest'];
        if (latest == null) return null;

        final pubspec = latest['pubspec'];
        if (pubspec == null) return null;

        String? repoUrl = pubspec['repository'] ?? pubspec['homepage'];

        bool isPlugin = false;
        final flutter = pubspec['flutter'];
        if (flutter != null && flutter is Map) {
          final plugin = flutter['plugin'];
          if (plugin != null && plugin is Map) {
            final platforms = plugin['platforms'];
            if (platforms != null && platforms is Map) {
              if (platforms.containsKey('ios') ||
                  platforms.containsKey('macos')) {
                isPlugin = true;
              }
            }
          }
        }

        final info = PubPackageInfo(
          repositoryUrl: repoUrl,
          isIosMacosPlugin: isPlugin,
        );

        await _cache.set(cacheKey, info.toJson());
        return info;
      }
    } catch (e) {
      // Ignore network errors and return null
    }

    return null;
  }
}

/// Pub.dev metadata relevant to SPM detection for a single package.
class PubPackageInfo {
  /// The package's linked source repository or homepage URL, if any.
  final String? repositoryUrl;

  /// Whether this package declares native iOS or macOS plugin platforms.
  final bool isIosMacosPlugin;

  /// Creates a [PubPackageInfo] from already-fetched pub.dev data.
  PubPackageInfo({this.repositoryUrl, required this.isIosMacosPlugin});

  /// Restores a [PubPackageInfo] from its cached JSON representation.
  factory PubPackageInfo.fromJson(Map<String, dynamic> json) {
    return PubPackageInfo(
      repositoryUrl: json['repositoryUrl'] as String?,
      isIosMacosPlugin: json['isIosMacosPlugin'] as bool,
    );
  }

  /// Converts this info to a JSON-serializable map for caching.
  Map<String, dynamic> toJson() {
    return {
      'repositoryUrl': repositoryUrl,
      'isIosMacosPlugin': isIosMacosPlugin,
    };
  }
}
