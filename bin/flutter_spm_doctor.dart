import 'dart:io';
import 'package:args/args.dart';
import 'package:http/http.dart' as http;

import 'package:flutter_spm_doctor/flutter_spm_doctor.dart';

Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Print this usage information.',
    )
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
      help: 'Prints a ready-to-paste GitHub issue body for a specific package.',
    )
    ..addOption(
      'github-token',
      help: 'GitHub Personal Access Token to avoid API rate limits.',
    );

  final ArgResults argResults;
  try {
    argResults = parser.parse(arguments);
  } catch (e) {
    print(e);
    print(parser.usage);
    exit(1);
  }

  if (argResults['help']) {
    print(
      'Detect which Flutter plugin dependencies haven\'t migrated to SPM.\n',
    );
    print(parser.usage);
    exit(0);
  }

  final String? generateIssuePackage = argResults['generate-issue'];
  if (generateIssuePackage != null) {
    IssueTemplate.printTemplate(generateIssuePackage);
    exit(0);
  }

  final bool outputJson = argResults['json'];
  final bool failOnUnsupported = argResults['fail-on-unsupported'];
  final String? ignoreOpt = argResults['ignore'];
  final List<String> ignoreList =
      ignoreOpt?.split(',').map((e) => e.trim()).toList() ?? [];

  String? githubToken =
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
    exit(1);
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
    exit(0);
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
    exit(0);
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
      exit(1);
    }
  }
}
