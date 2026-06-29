import 'dart:io';
import 'package:yaml/yaml.dart';

/// Reads a project's `pubspec.lock` to discover its resolved dependencies.
class PubspecReader {
  /// Reads pubspec.lock and pubspec.yaml to extract all external dependencies
  /// Returns a map of package name to version.
  Future<Map<String, String>> getDependencies() async {
    final lockFile = File('pubspec.lock');
    if (!await lockFile.exists()) {
      throw Exception(
        'pubspec.lock not found. Please run `flutter pub get` first.',
      );
    }

    final String lockContent = await lockFile.readAsString();
    final YamlMap lockYaml = loadYaml(lockContent);
    final YamlMap? packages = lockYaml['packages'] as YamlMap?;

    if (packages == null) {
      return {};
    }

    final dependencies = <String, String>{};

    for (final entry in packages.entries) {
      final name = entry.key.toString();
      final details = entry.value;

      // Ignore flutter SDK and the current project
      if (details is YamlMap) {
        final source = details['source'];
        if (source == 'sdk') continue;

        final version = details['version']?.toString() ?? 'unknown';

        if (source == 'hosted') {
          dependencies[name] = version;
        } else if (source == 'git') {
          dependencies[name] = 'git';
        } else if (source == 'path') {
          dependencies[name] = 'path';
        }
      }
    }

    return dependencies;
  }
}
