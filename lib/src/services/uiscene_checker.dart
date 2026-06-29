import '../models/uiscene_status.dart';
import 'github_client.dart';
import 'pub_dev_client.dart';

/// Best-effort checker for UIScene lifecycle migration: does a plugin hook
/// into iOS `AppDelegate` lifecycle callbacks, and if so, has it adopted
/// `FlutterSceneLifeCycleDelegate`?
///
/// This is heuristic source-scanning, not static analysis — it greps a
/// bounded set of the plugin's iOS source files for known method names.
/// Detection is intentionally conservative: anything ambiguous resolves to
/// "needs review" or "unknown" rather than a false "all clear", because
/// this is a newly evolving, fast-moving area of the Flutter SDK.
class UiSceneChecker {
  /// AppDelegate lifecycle method names that signal a plugin is hooking
  /// into app lifecycle events on iOS.
  static const lifecycleMethodPatterns = [
    'applicationDidBecomeActive',
    'applicationDidEnterBackground',
    'applicationWillEnterForeground',
    'applicationWillResignActive',
    'applicationWillTerminate',
    'didFinishLaunchingWithOptions',
    'application:openURL:options:',
    'application(_:open:options:)',
    'application(_:didFinishLaunchingWithOptions:)',
  ];

  /// Marker string indicating UIScene lifecycle adoption.
  static const sceneDelegateMarker = 'FlutterSceneLifeCycleDelegate';

  /// Source file extensions worth scanning for lifecycle hooks.
  static const _sourceExtensions = ['.swift', '.m', '.mm', '.h'];

  /// Upper bound on how many source files to fetch and scan per plugin, to
  /// stay respectful of GitHub API rate limits.
  static const maxFilesToScan = 8;

  final PubDevClient _pubClient;
  final GithubClient _githubClient;

  /// Creates a checker that uses [_pubClient] to identify iOS/macOS plugins
  /// and [_githubClient] to scan their repos for lifecycle method usage.
  UiSceneChecker(this._pubClient, this._githubClient);

  /// Classifies a plugin's UIScene migration status purely from the text
  /// content of its iOS source files. Exposed separately from
  /// [checkPlugin] so the classification rules can be unit tested without
  /// network access.
  static UiSceneStatus classifySourceContents(List<String> fileContents) {
    final combined = fileContents.join('\n');

    if (combined.contains(sceneDelegateMarker)) {
      return UiSceneStatus.migrated;
    }

    final usesLifecycleMethods = lifecycleMethodPatterns.any(combined.contains);
    if (usesLifecycleMethods) {
      return UiSceneStatus.needsReview;
    }

    return UiSceneStatus.notApplicable;
  }

  /// Checks the UIScene lifecycle migration status of a given dependency.
  /// Returns a [UiScenePluginInfo] if it's an iOS/macOS plugin, otherwise
  /// `null`.
  Future<UiScenePluginInfo?> checkPlugin(String name, String version) async {
    final info = await _pubClient.getPackageInfo(name);
    if (info == null || !info.isIosMacosPlugin) {
      return null;
    }

    final plugin = UiScenePluginInfo(
      name: name,
      version: version,
      repositoryUrl: info.repositoryUrl,
    );

    final repoUrl = info.repositoryUrl;
    if (repoUrl == null) {
      plugin.status = UiSceneStatus.unknown;
      return plugin;
    }

    final ref = GithubClient.parseRepoUrl(repoUrl);
    if (ref == null) {
      plugin.status = UiSceneStatus.unknown;
      return plugin;
    }

    final sourcePaths = <String>{};
    for (final dir in const ['ios', 'ios/Classes']) {
      final files = await _githubClient.listDirectory(repoUrl, dir);
      if (files != null) {
        sourcePaths.addAll(files.where(_isSourceFile));
      }
    }

    if (sourcePaths.isEmpty) {
      plugin.status = UiSceneStatus.unknown;
      return plugin;
    }

    final contents = <String>[];
    for (final path in sourcePaths.take(maxFilesToScan)) {
      final content = await _githubClient.fetchRawFile(
        repoUrl,
        path,
        branch: ref.branch,
      );
      if (content != null) {
        contents.add(content);
      }
    }

    if (contents.isEmpty) {
      plugin.status = UiSceneStatus.unknown;
      return plugin;
    }

    plugin.status = classifySourceContents(contents);
    return plugin;
  }

  static bool _isSourceFile(String path) {
    return _sourceExtensions.any(path.endsWith);
  }
}
