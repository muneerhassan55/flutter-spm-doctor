import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:http/http.dart' as http;

import '../models/uiscene_status.dart';
import '../reporters/console_reporter.dart';
import '../reporters/json_reporter.dart';
import '../services/cache_service.dart';
import '../services/github_client.dart';
import '../services/pub_dev_client.dart';
import '../services/pubspec_reader.dart';
import '../services/uiscene_checker.dart';

/// The `uiscene` subcommand: checks plugin dependencies for UIScene
/// lifecycle migration status, via best-effort source scanning.
class UiSceneCommand extends Command<void> {
  @override
  final name = 'uiscene';

  @override
  final description =
      'Check plugin dependencies for UIScene lifecycle migration status '
      '(heuristic, source-scan based).';

  UiSceneCommand() {
    argParser
      ..addFlag(
        'json',
        negatable: false,
        help: 'Output the report as structured JSON.',
      )
      ..addFlag(
        'fail-on-unsupported',
        negatable: false,
        help:
            'Exits with code 1 if any plugin needs review (uses lifecycle '
            'events without detected UIScene adoption).',
      )
      ..addOption('ignore', help: 'Comma-separated list of packages to ignore.')
      ..addOption(
        'github-token',
        help: 'GitHub Personal Access Token to avoid API rate limits.',
      );
  }

  @override
  Future<void> run() async {
    final argResults = this.argResults!;

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
    final checker = UiSceneChecker(pubClient, githubClient);

    final plugins = <UiScenePluginInfo>[];

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
      JsonReporter().reportUiScene(plugins);
    } else {
      ConsoleReporter().reportUiScene(plugins);
    }

    if (failOnUnsupported) {
      final needsReview = plugins.any(
        (p) => p.status == UiSceneStatus.needsReview,
      );
      if (needsReview) {
        exitCode = 1;
      }
    }
  }
}
