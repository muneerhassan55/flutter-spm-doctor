import 'package:ansi_styles/ansi_styles.dart';
import '../models/plugin_info.dart';
import '../models/spm_status.dart';

/// Prints a color-coded, human-readable SPM status report to the console.
class ConsoleReporter {
  /// Prints a status line for each [plugins] entry followed by a
  /// "X of Y plugins are SPM-ready" summary.
  void report(List<PluginInfo> plugins) {
    print(
      '\nChecking SPM support for ${plugins.length} iOS/macOS plugins...\n',
    );

    int supported = 0;

    for (final plugin in plugins) {
      final name = plugin.name;
      final version = plugin.version;

      switch (plugin.status) {
        case SpmStatus.supported:
          supported++;
          print(AnsiStyles.green('✅ $name (v$version)'));
          break;
        case SpmStatus.notSupported:
          print(AnsiStyles.red('❌ $name (v$version) - SPM not supported'));
          if (plugin.repositoryUrl != null) {
            final repoUri = Uri.tryParse(plugin.repositoryUrl!);
            if (repoUri != null && repoUri.host == 'github.com') {
              print('   Open an issue: ${plugin.repositoryUrl}/issues/new');
            }
          }
          break;
        case SpmStatus.unknown:
          print(AnsiStyles.yellow('⚠️ $name (v$version) - Unknown status'));
          if (plugin.repositoryUrl != null) {
            final repoUri = Uri.tryParse(plugin.repositoryUrl!);
            if (repoUri != null && repoUri.host == 'github.com') {
              print(
                '   Verify manually: ${plugin.repositoryUrl}/issues?q=is%3Aissue+Swift+Package+Manager',
              );
            }
          }
          break;
      }
    }

    print(
      '\nSummary: $supported of ${plugins.length} plugins are SPM-ready.\n',
    );
  }
}
