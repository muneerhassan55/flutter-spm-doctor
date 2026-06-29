import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:http/http.dart' as http;

import '../issue_template.dart';
import '../models/plugin_info.dart';
import '../models/spm_status.dart';
import '../reporters/console_reporter.dart';
import '../reporters/json_reporter.dart';
import '../services/cache_service.dart';
import '../services/github_client.dart';
import '../services/pub_dev_client.dart';
import '../services/pubspec_reader.dart';
import '../services/spm_checker.dart';

/// The `spm` subcommand: checks plugin dependencies for Swift Package
/// Manager migration status. This is also the default command run when
/// `flutter_spm_doctor` is invoked with no subcommand, preserving the
/// original (pre-0.2.0) CLI behavior.
class SpmCommand extends Command<void> {
  @override
  final name = 'spm';

  @override
  final description =
      'Check plugin dependencies for Swift Package Manager (SPM) migration '
      'status. (default command)';

  SpmCommand() {
    argParser
      ..addFlag(
        'json',
        negatable: false,
        help: 'Output the report as structured JSON.',
      )
      ..addFlag(
        'fail-on-unsupported',
        negatable: false,
        help: 'Exits with code 1 if any plugin is not SPM-supported.',
      )
      ..addOption('ignore', help: 'Comma-separated list of packages to ignore.')
      ..addOption(
        'generate-issue',
        help:
            'Prints a ready-to-paste GitHub issue body for a specific package.',
      )
      ..addOption(
        'github-token',
        help: 'GitHub Personal Access Token to avoid API rate limits.',
      );
  }

  @override
  Future<void> run() async {
    final argResults = this.argResults!;

    final String? generateIssuePackage = argResults['generate-issue'];
    if (generateIssuePackage != null) {
      IssueTemplate.printTemplate(generateIssuePackage);
      return;
    }

    final bool outputJson = argResults['json'];
    final bool failOnUnsupported = argResults['fail-on-unsupported'];
    final String? ignoreOpt = argResults['ignore'];
    final List<String> ignoreList =
        ignoreOpt?.split(',').map((e) => e.trim()).toList() ?? [];

    final String? githubToken =
        argResults['github-token'] ?? Platform.environment['GITHUB_TOKEN'];

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

    // Remove ignored packages
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
    final githubClient = GithubClient(client, cache, token: githubToken);
    final checker = SpmChecker(pubClient, githubClient);

    final plugins = <PluginInfo>[];

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
        print('\nNo iOS/macOS plugins found in dependencies. You\'re all set!');
      }
      return;
    }

    if (outputJson) {
      JsonReporter().report(plugins);
    } else {
      ConsoleReporter().report(plugins);
    }

    if (failOnUnsupported) {
      final hasUnsupported = plugins.any(
        (p) => p.status == SpmStatus.notSupported,
      );
      if (hasUnsupported) {
        exitCode = 1;
      }
    }
  }
}
