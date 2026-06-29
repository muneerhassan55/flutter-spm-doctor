import 'package:ansi_styles/ansi_styles.dart';
import '../models/android16kb_status.dart';
import '../models/plugin_info.dart';
import '../models/spm_status.dart';
import '../models/uiscene_status.dart';

/// Prints a color-coded, human-readable migration status report to the
/// console, for any of the SPM, UIScene, or Android 16KB checks.
class ConsoleReporter {
  /// Prints a status line for each [plugins] entry followed by a
  /// "X of Y plugins are SPM-ready" summary.
  void report(List<PluginInfo> plugins) {
    print(
      '\nChecking SPM support for ${plugins.length} iOS/macOS plugins...\n',
    );

    int supported = 0;

    for (final plugin in plugins) {
      final label = '${plugin.name} (v${plugin.version})';

      switch (plugin.status) {
        case SpmStatus.supported:
          supported++;
          _printLine('✅', AnsiStyles.green.call, label);
          break;
        case SpmStatus.notSupported:
          _printLine('❌', AnsiStyles.red.call, '$label - SPM not supported');
          _printRepoHint(plugin.repositoryUrl, '/issues/new', 'Open an issue');
          break;
        case SpmStatus.unknown:
          _printLine('⚠️', AnsiStyles.yellow.call, '$label - Unknown status');
          _printRepoHint(
            plugin.repositoryUrl,
            '/issues?q=is%3Aissue+Swift+Package+Manager',
            'Verify manually',
          );
          break;
      }
    }

    print(
      '\nSummary: $supported of ${plugins.length} plugins are SPM-ready.\n',
    );
  }

  /// Prints a status line for each [plugins] entry's UIScene lifecycle
  /// migration status, followed by a summary and a disclaimer that this
  /// check is heuristic, source-scan based.
  void reportUiScene(List<UiScenePluginInfo> plugins) {
    print(
      '\nChecking UIScene lifecycle migration for ${plugins.length} '
      'iOS/macOS plugins...\n',
    );

    int migrated = 0;

    for (final plugin in plugins) {
      final label = '${plugin.name} (v${plugin.version})';

      switch (plugin.status) {
        case UiSceneStatus.migrated:
          migrated++;
          _printLine('✅', AnsiStyles.green.call, '$label - Migrated');
          break;
        case UiSceneStatus.needsReview:
          _printLine(
            '⚠️',
            AnsiStyles.yellow.call,
            '$label - Needs review: uses lifecycle events, '
                'no UIScene adoption detected',
          );
          _printRepoHint(plugin.repositoryUrl, '', 'Inspect source');
          break;
        case UiSceneStatus.notApplicable:
          print('➖ $label - Not applicable');
          break;
        case UiSceneStatus.unknown:
          _printLine(
            '❓',
            AnsiStyles.yellow.call,
            '$label - Unknown, verify manually',
          );
          _printRepoHint(plugin.repositoryUrl, '', 'Inspect repo');
          break;
      }
    }

    print(
      '\nSummary: $migrated of ${plugins.length} plugins explicitly adopt '
      'UIScene lifecycle.',
    );
    print(
      AnsiStyles.gray(
        'Note: this check is heuristic (source-scan based) and this is a '
        'newly evolving area of the Flutter SDK. Treat results as a '
        'starting point, not a final answer. See the official UIScene '
        'migration guide: '
        'https://docs.flutter.dev/platform-integration/ios/ios-uiscenedelegate\n',
      ),
    );
  }

  /// Prints a status line for each [plugins] entry's Android 16KB
  /// page-size alignment compliance status, followed by a summary.
  void reportAndroid16kb(List<Android16kbPluginInfo> plugins) {
    print(
      '\nChecking Android 16KB page-size alignment for ${plugins.length} '
      'Android plugins...\n',
    );

    int compliant = 0;

    for (final plugin in plugins) {
      final label = '${plugin.name} (v${plugin.version})';

      switch (plugin.status) {
        case Android16kbStatus.compliant:
          compliant++;
          _printLine('✅', AnsiStyles.green.call, label);
          break;
        case Android16kbStatus.nonCompliant:
          _printLine(
            '❌',
            AnsiStyles.red.call,
            '$label - Not 16KB aligned'
                '${plugin.nonCompliantLibraries.isNotEmpty ? ' (${plugin.nonCompliantLibraries.join(', ')})' : ''}',
          );
          break;
        case Android16kbStatus.unknown:
          _printLine(
            '❓',
            AnsiStyles.yellow.call,
            '$label - Unknown, build an APK and re-run with --apk to check '
                'directly',
          );
          break;
      }
    }

    print(
      '\nSummary: $compliant of ${plugins.length} plugins are 16KB-aligned.\n',
    );
  }

  /// Prints all three checks as separate, clearly labeled sections, so
  /// Android-only or iOS-only readers can skip what's not relevant to them.
  void reportAll({
    required List<PluginInfo> spm,
    required List<UiScenePluginInfo> uiscene,
    required List<Android16kbPluginInfo> android16kb,
  }) {
    print(AnsiStyles.bold('\n=== iOS/macOS: Swift Package Manager ==='));
    report(spm);

    print(AnsiStyles.bold('=== iOS/macOS: UIScene Lifecycle ==='));
    reportUiScene(uiscene);

    print(AnsiStyles.bold('=== Android: 16KB Page-Size Alignment ==='));
    reportAndroid16kb(android16kb);
  }

  void _printLine(String icon, String Function(String) colorFn, String text) {
    print(colorFn('$icon $text'));
  }

  void _printRepoHint(String? repositoryUrl, String suffix, String label) {
    if (repositoryUrl == null) return;
    final repoUri = Uri.tryParse(repositoryUrl);
    if (repoUri != null && repoUri.host == 'github.com') {
      print('   $label: $repositoryUrl$suffix');
    }
  }
}
