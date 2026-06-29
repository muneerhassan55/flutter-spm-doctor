import 'dart:io';

/// Generates a ready-to-paste GitHub issue body requesting SPM support.
class IssueTemplate {
  /// Prints a GitHub issue body for [packageName], pre-filled with the
  /// locally detected Flutter version.
  static void printTemplate(String packageName) {
    final flutterVersion = _getFlutterVersion();

    final template =
        '''
### Problem
The Flutter plugin `$packageName` does not yet support Swift Package Manager (SPM).
Flutter has transitioned to using SPM as the default iOS/macOS dependency manager, and CocoaPods is being deprecated (registry goes read-only Dec 2, 2026).

Plugins that have not migrated to SPM will eventually break in future versions of Flutter.

### Proposal
Please add `ios/Package.swift` and `macos/Package.swift` to support Swift Package Manager.

Official Migration Guide:
https://docs.flutter.dev/packages-and-plugins/developing-packages#swift-package-manager

### Environment
$flutterVersion
''';

    print('\n--- GitHub Issue Template for $packageName ---\n');
    print(template);
    print('--------------------------------------------\n');
  }

  static String _getFlutterVersion() {
    try {
      final result = Process.runSync('flutter', ['--version']);
      if (result.exitCode == 0) {
        final lines = (result.stdout as String).split('\n');
        if (lines.isNotEmpty) return lines.first;
      }
    } catch (_) {}
    return 'Flutter version: Unknown (run `flutter doctor`)';
  }
}
