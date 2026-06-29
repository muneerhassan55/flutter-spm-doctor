import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../models/android16kb_status.dart';
import 'elf_alignment_parser.dart';
import 'pub_dev_client.dart';

/// Checks a project's Android plugin dependencies for compliance with
/// Android's 16KB native-library page-size alignment requirement, in effect
/// for apps targeting Android 15+ devices since November 2025.
class Android16kbChecker {
  final PubDevClient _pubClient;
  late final Map<String, Android16kbStatus> _knownStatuses;

  /// Map of `.so` entry path -> raw bytes, extracted from an APK/AAB via
  /// [loadArchive]. When non-null, [checkPlugin] prefers inspecting these
  /// directly over the bundled known-status list.
  Map<String, List<int>>? _extractedLibraries;

  /// Creates a checker that uses [_pubClient] to identify Android plugins.
  Android16kbChecker(this._pubClient) {
    _loadKnownStatuses();
  }

  void _loadKnownStatuses() {
    _knownStatuses = {};
    try {
      final file = File('lib/src/services/known_16kb_status.json');
      if (file.existsSync()) {
        final content = file.readAsStringSync();
        final List<dynamic> data = jsonDecode(content);
        for (final item in data) {
          final name = item['name'] as String;
          final statusStr = item['status'] as String;
          _knownStatuses[name] = statusStr == 'compliant'
              ? Android16kbStatus.compliant
              : Android16kbStatus.nonCompliant;
        }
      }
    } catch (_) {
      // Leave the known-status map empty; everything falls through to
      // "unknown" rather than crashing the check.
    }
  }

  /// Extracts and indexes every `.so` file from the APK/AAB at [path] so
  /// that subsequent [checkPlugin] calls can inspect real native libraries
  /// instead of relying on the known-status fallback list.
  ///
  /// Throws a [FormatException] if [path] isn't a readable zip archive
  /// (both APKs and AABs are zip files).
  void loadArchive(String path) {
    final bytes = File(path).readAsBytesSync();
    final archive = ZipDecoder().decodeBytes(bytes);

    final libraries = <String, List<int>>{};
    for (final file in archive) {
      if (file.isFile && file.name.endsWith('.so')) {
        libraries[file.name] = file.content as List<int>;
      }
    }
    _extractedLibraries = libraries;
  }

  /// Checks the 16KB alignment status of a given Android dependency.
  /// Returns an [Android16kbPluginInfo] if it's an Android plugin with
  /// native code, otherwise `null`.
  Future<Android16kbPluginInfo?> checkPlugin(
    String name,
    String version,
  ) async {
    final info = await _pubClient.getPackageInfo(name);

    if (info == null || !info.isAndroidPlugin) {
      return null;
    }

    final plugin = Android16kbPluginInfo(name: name, version: version);

    // Tier 1: inspect real .so files extracted from a provided APK/AAB.
    final extracted = _extractedLibraries;
    if (extracted != null) {
      final matches = extracted.entries
          .where((e) => e.key.contains(name))
          .toList();

      if (matches.isNotEmpty) {
        final nonCompliant = <String>[];
        for (final match in matches) {
          final result = ElfAlignmentParser.parse(
            Uint8List.fromList(match.value),
          );
          if (result.isValidElf && !result.isAligned) {
            nonCompliant.add(match.key);
          }
        }

        return Android16kbPluginInfo(
          name: name,
          version: version,
          status: nonCompliant.isEmpty
              ? Android16kbStatus.compliant
              : Android16kbStatus.nonCompliant,
          nonCompliantLibraries: nonCompliant,
        );
      }
    }

    // Tier 2: bundled known-status list.
    if (_knownStatuses.containsKey(name)) {
      plugin.status = _knownStatuses[name]!;
      return plugin;
    }

    // Tier 3: unknown — caller should suggest running with --apk/--aab.
    plugin.status = Android16kbStatus.unknown;
    return plugin;
  }
}
