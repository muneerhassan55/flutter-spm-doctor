/// A plugin's best-effort UIScene lifecycle migration status.
///
/// Detection here is heuristic and source-scan based — see
/// [UiSceneStatus.displayName] callers for the disclaimer text shown
/// alongside this status in reports. This is a newly evolving area of the
/// Flutter SDK; favor flagging for manual review over claiming certainty.
enum UiSceneStatus {
  /// The plugin's iOS source appears to adopt `FlutterSceneLifeCycleDelegate`.
  migrated,

  /// The plugin appears to hook into `AppDelegate` lifecycle callbacks but
  /// no `FlutterSceneLifeCycleDelegate` adoption was detected.
  needsReview,

  /// No lifecycle method usage was detected — most plugins fall here.
  notApplicable,

  /// The plugin's source couldn't be inspected (no repo, fetch failure,
  /// rate limit, etc).
  unknown;

  /// A human-readable label for this status, used in console/JSON reports.
  String get displayName {
    switch (this) {
      case UiSceneStatus.migrated:
        return 'Migrated';
      case UiSceneStatus.needsReview:
        return 'Needs review';
      case UiSceneStatus.notApplicable:
        return 'Not applicable';
      case UiSceneStatus.unknown:
        return 'Unknown';
    }
  }
}

/// A plugin's UIScene lifecycle migration status, along with how that
/// status was determined.
class UiScenePluginInfo {
  /// The package name as it appears on pub.dev.
  final String name;

  /// The resolved version installed in the project.
  final String version;

  /// The plugin's UIScene lifecycle migration status.
  UiSceneStatus status;

  /// The plugin's source repository URL, if one is linked on pub.dev.
  String? repositoryUrl;

  /// Creates a [UiScenePluginInfo] for a resolved plugin dependency.
  UiScenePluginInfo({
    required this.name,
    required this.version,
    this.status = UiSceneStatus.unknown,
    this.repositoryUrl,
  });

  /// Converts this plugin's data to a JSON-serializable map.
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'version': version,
      'status': status.name,
      'repositoryUrl': repositoryUrl,
    };
  }
}
