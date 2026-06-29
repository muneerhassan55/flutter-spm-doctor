import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:http/http.dart' as http;

import '../models/android16kb_status.dart';
import '../models/plugin_info.dart';
import '../models/spm_status.dart';
import '../models/uiscene_status.dart';
import '../reporters/console_reporter.dart';
import '../reporters/json_reporter.dart';
import '../services/android16kb_checker.dart';
import '../services/cache_service.dart';
import '../services/github_client.dart';
import '../services/pub_dev_client.dart';
import '../services/pubspec_reader.dart';
import '../services/spm_checker.dart';
import '../services/uiscene_checker.dart';

/// The `all` subcommand: runs the SPM, UIScene, and Android 16KB checks
/// together and prints (or encodes) a sectioned, combined report.
class AllCommand extends Command<void> {
  @override
  final name = 'all';

  @override
  final description =
      'Run the SPM, UIScene lifecycle, and Android 16KB alignment checks '
      'together.';

  AllCommand() {
    argParser
      ..addFlag(
        'json',
        negatable: false,
        help:
            'Output a combined JSON object with spm/uiscene/android16kb keys.',
      )
      ..addFlag(
        'fail-on-unsupported',
        negatable: false,
        help: 'Exits with code 1 if any of the three checks finds an issue.',
      )
      ..addOption('ignore', help: 'Comma-separated list of packages to ignore.')
      ..addOption(
        'github-token',
        help: 'GitHub Personal Access Token to avoid API rate limits.',
      )
      ..addOption(
        'apk',
        help: 'Path to a built APK, used by the Android 16KB check.',
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
    final String? githubToken =
        argResults['github-token'] ?? Platform.environment['GITHUB_TOKEN'];
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
        print(
          '{"spm": {"plugins": []}, "uiscene": {"plugins": []}, '
          '"android16kb": {"plugins": []}}',
        );
      } else {
        print('No external dependencies found.');
      }
      return;
    }

    final client = http.Client();
    final cache = CacheService();
    final pubClient = PubDevClient(client, cache);
    final githubClient = GithubClient(client, cache, token: githubToken);

    final spmChecker = SpmChecker(pubClient, githubClient);
    final uiSceneChecker = UiSceneChecker(pubClient, githubClient);
    final android16kbChecker = Android16kbChecker(pubClient);

    if (archivePath != null) {
      try {
        android16kbChecker.loadArchive(archivePath);
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

    final spmResults = <PluginInfo>[];
    final uiSceneResults = <UiScenePluginInfo>[];
    final android16kbResults = <Android16kbPluginInfo>[];

    if (!outputJson) {
      print(
        'Checking ${dependencies.length} packages across all three checks '
        '(this may take a moment)...',
      );
    }

    for (final entry in dependencies.entries) {
      final spmInfo = await spmChecker.checkPlugin(entry.key, entry.value);
      if (spmInfo != null) spmResults.add(spmInfo);

      final uiSceneInfo = await uiSceneChecker.checkPlugin(
        entry.key,
        entry.value,
      );
      if (uiSceneInfo != null) uiSceneResults.add(uiSceneInfo);

      final android16kbInfo = await android16kbChecker.checkPlugin(
        entry.key,
        entry.value,
      );
      if (android16kbInfo != null) android16kbResults.add(android16kbInfo);
    }

    client.close();

    if (outputJson) {
      JsonReporter().reportAll(
        spm: spmResults,
        uiscene: uiSceneResults,
        android16kb: android16kbResults,
      );
    } else {
      ConsoleReporter().reportAll(
        spm: spmResults,
        uiscene: uiSceneResults,
        android16kb: android16kbResults,
      );
    }

    if (failOnUnsupported) {
      final hasIssue =
          spmResults.any((p) => p.status == SpmStatus.notSupported) ||
          uiSceneResults.any((p) => p.status == UiSceneStatus.needsReview) ||
          android16kbResults.any(
            (p) => p.status == Android16kbStatus.nonCompliant,
          );
      if (hasIssue) {
        exitCode = 1;
      }
    }
  }
}
