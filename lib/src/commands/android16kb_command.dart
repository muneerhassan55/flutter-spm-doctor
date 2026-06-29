import 'dart:io';
import 'package:args/command_runner.dart';

import '../models/android16kb_status.dart';
import '../reporters/console_reporter.dart';
import '../reporters/json_reporter.dart';
import '../services/android16kb_checker.dart';
import '../services/pub_dev_client.dart';
import '../services/cache_service.dart';
import '../services/pubspec_reader.dart';
import 'package:http/http.dart' as http;

/// The `android16kb` subcommand: checks plugin dependencies (direct and
/// transitive) for Android 16KB native-library page-size alignment
/// compliance.
class Android16kbCommand extends Command<void> {
  @override
  final name = 'android16kb';

  @override
  final description =
      'Check plugin dependencies for Android 16KB page-size alignment '
      'compliance.';

  Android16kbCommand() {
    argParser
      ..addFlag(
        'json',
        negatable: false,
        help: 'Output the report as structured JSON.',
      )
      ..addFlag(
        'fail-on-unsupported',
        negatable: false,
        help: 'Exits with code 1 if any plugin is not 16KB-aligned.',
      )
      ..addOption('ignore', help: 'Comma-separated list of packages to ignore.')
      ..addOption(
        'apk',
        help:
            'Path to a built APK to inspect .so files directly for 16KB '
            'alignment, instead of relying on the known-status list.',
      )
      ..addOption('aab', help: 'Path to a built AAB. Same effect as --apk.');
  }

  @override
  Future<void> run() async {
    final argResults = this.argResults!;

    final bool outputJson = argResults['json'];
    final bool failOnUnsupported = argResults['fail-on-unsupported'];
    final String? ignoreOpt = argResults['ignore'];
    final List<String> ignoreList =
        ignoreOpt?.split(',').map((e) => e.trim()).toList() ?? [];

    final String? archivePath = argResults['apk'] ?? argResults['aab'];

    if (!outputJson) {
      print('Reading pubspec dependencies...');
    }

    final reader = PubspecReader();
    Map<String, String> dependencies;
    try {
      dependencies = await reader.getDependencies();
    } catch (e) {
      if (outputJson) {
        print('{"error": "${e.toString()}"}');
      } else {
        print('Error: $e');
      }
      exitCode = 1;
      return;
    }

    for (final pkg in ignoreList) {
      dependencies.remove(pkg);
    }

    if (dependencies.isEmpty) {
      if (outputJson) {
        print('{"plugins": []}');
      } else {
        print('No external dependencies found.');
      }
      return;
    }

    final client = http.Client();
    final cache = CacheService();
    final pubClient = PubDevClient(client, cache);
    final checker = Android16kbChecker(pubClient);

    if (archivePath != null) {
      try {
        checker.loadArchive(archivePath);
      } catch (e) {
        if (outputJson) {
          print('{"error": "Failed to read $archivePath: ${e.toString()}"}');
        } else {
          print('Error: Failed to read $archivePath: $e');
        }
        client.close();
        exitCode = 1;
        return;
      }
    }

    final plugins = <Android16kbPluginInfo>[];

    if (!outputJson) {
      print(
        'Checking ${dependencies.length} packages (this may take a moment)...',
      );
    }

    for (final entry in dependencies.entries) {
      final info = await checker.checkPlugin(entry.key, entry.value);
      if (info != null) {
        plugins.add(info);
      }
    }

    client.close();

    if (plugins.isEmpty) {
      if (outputJson) {
        print('{"plugins": []}');
      } else {
        print('\nNo Android plugins found in dependencies. You\'re all set!');
      }
      return;
    }

    if (outputJson) {
      JsonReporter().reportAndroid16kb(plugins);
    } else {
      ConsoleReporter().reportAndroid16kb(plugins);
    }

    if (failOnUnsupported) {
      final hasNonCompliant = plugins.any(
        (p) => p.status == Android16kbStatus.nonCompliant,
      );
      if (hasNonCompliant) {
        exitCode = 1;
      }
    }
  }
}
