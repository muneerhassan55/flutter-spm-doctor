/// The Swift Package Manager migration status of a plugin.
enum SpmStatus {
  /// The plugin has a `Package.swift` and is SPM-ready.
  supported,

  /// The plugin does not yet support SPM and is blocking full migration.
  notSupported,

  /// SPM support could not be determined automatically.
  unknown;

  /// A human-readable label for this status, used in console/JSON reports.
  String get displayName {
    switch (this) {
      case SpmStatus.supported:
        return 'Supported';
      case SpmStatus.notSupported:
        return 'Not Supported';
      case SpmStatus.unknown:
        return 'Unknown';
    }
  }
}
