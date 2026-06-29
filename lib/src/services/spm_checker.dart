import 'dart:convert';
import 'dart:io';
import '../models/plugin_info.dart';
import '../models/spm_status.dart';
import 'github_client.dart';
import 'pub_dev_client.dart';

/// Orchestrates the tiered SPM-detection strategy: GitHub repo check first,
/// then the bundled known-status list, then "unknown" as a last resort.
class SpmChecker {
  final PubDevClient _pubClient;
  final GithubClient _githubClient;
  late final Map<String, SpmStatus> _knownStatuses;

  /// Creates a checker that uses [_pubClient] to identify plugins and
  /// [_githubClient] to inspect their repos for `Package.swift`.
  SpmChecker(this._pubClient, this._githubClient) {
    _loadKnownStatuses();
  }

  void _loadKnownStatuses() {
    _knownStatuses = {};
    try {
      // In a real deployed package, reading a bundled JSON might require
      // Isolate.resolvePackageUri. For simplicity in this structure,
      // we can read it if we are running locally, or fallback to an empty map.
      // A more robust approach is to embed it as a constant string in Dart.
      // But we will try to read it assuming it's in the lib/src directory.
      // As a fallback, we just don't populate it.

      final file = File('lib/src/known_spm_status.json');
      if (file.existsSync()) {
        final content = file.readAsStringSync();
        final List<dynamic> data = jsonDecode(content);
        for (final item in data) {
          final name = item['name'] as String;
          final statusStr = item['status'] as String;
          _knownStatuses[name] = statusStr == 'supported'
              ? SpmStatus.supported
              : SpmStatus.notSupported;
        }
      }
    } catch (_) {}
  }

  /// Checks the SPM status of a given dependency.
  /// Returns a PluginInfo if it's an iOS/macOS plugin, otherwise null.
  Future<PluginInfo?> checkPlugin(String name, String version) async {
    final info = await _pubClient.getPackageInfo(name);

    // Not found or not an iOS/macOS plugin
    if (info == null || !info.isIosMacosPlugin) {
      return null;
    }

    final plugin = PluginInfo(
      name: name,
      version: version,
      repositoryUrl: info.repositoryUrl,
    );

    // Tier 1: GitHub check
    if (info.repositoryUrl != null) {
      final hasPackageSwift = await _githubClient.hasPackageSwift(
        info.repositoryUrl!,
      );
      if (hasPackageSwift == true) {
        plugin.status = SpmStatus.supported;
        return plugin;
      } else if (hasPackageSwift == false) {
        plugin.status = SpmStatus.notSupported;
        return plugin;
      }
    }

    // Tier 2: Known status JSON
    if (_knownStatuses.containsKey(name)) {
      plugin.status = _knownStatuses[name]!;
      return plugin;
    }

    // Tier 3: Unknown
    plugin.status = SpmStatus.unknown;
    return plugin;
  }
}
