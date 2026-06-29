// ignore_for_file: avoid_print
//
// This example shows how to use flutter_spm_doctor's library API directly,
// instead of via the CLI. Run it with:
//
//   dart run example/flutter_spm_doctor_example.dart
import 'package:http/http.dart' as http;
import 'package:flutter_spm_doctor/flutter_spm_doctor.dart';

Future<void> main() async {
  final client = http.Client();
  final cache = CacheService();
  final pubClient = PubDevClient(client, cache);
  final githubClient = GithubClient(client, cache);
  final checker = SpmChecker(pubClient, githubClient);

  // Check a handful of well-known plugins for SPM support.
  const packagesToCheck = {
    'url_launcher': '6.3.0',
    'package_info_plus': '8.0.0',
  };

  final plugins = <PluginInfo>[];
  for (final entry in packagesToCheck.entries) {
    final plugin = await checker.checkPlugin(entry.key, entry.value);
    if (plugin != null) {
      plugins.add(plugin);
    }
  }

  client.close();

  ConsoleReporter().report(plugins);

  // You can also generate a ready-to-paste GitHub issue body for a plugin
  // that doesn't support SPM yet:
  IssueTemplate.printTemplate('some_outdated_plugin');
}
