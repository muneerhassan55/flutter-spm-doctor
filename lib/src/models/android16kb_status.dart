/// The Android 16KB page-size alignment compliance status of a plugin's
/// native `.so` libraries.
enum Android16kbStatus {
  /// All inspected `PT_LOAD` segments are aligned to at least 16KB.
  compliant,

  /// At least one inspected `PT_LOAD` segment is aligned below 16KB.
  nonCompliant,

  /// Compliance could not be determined automatically.
  unknown;

  /// A human-readable label for this status, used in console/JSON reports.
  String get displayName {
    switch (this) {
      case Android16kbStatus.compliant:
        return '16KB Compliant';
      case Android16kbStatus.nonCompliant:
        return 'Not 16KB Aligned';
      case Android16kbStatus.unknown:
        return 'Unknown';
    }
  }
}

/// A plugin's Android 16KB page-size alignment status, along with how that
/// status was determined.
class Android16kbPluginInfo {
  /// The package name as it appears on pub.dev.
  final String name;

  /// The resolved version installed in the project.
  final String version;

  /// The plugin's 16KB page-size alignment compliance status.
  Android16kbStatus status;

  /// `.so` file paths (when checked via `--apk`/`--aab`) found to have a
  /// non-compliant `PT_LOAD` alignment, for diagnostic output.
  final List<String> nonCompliantLibraries;

  /// Creates an [Android16kbPluginInfo] for a resolved plugin dependency.
  Android16kbPluginInfo({
    required this.name,
    required this.version,
    this.status = Android16kbStatus.unknown,
    this.nonCompliantLibraries = const [],
  });

  /// Converts this plugin's data to a JSON-serializable map.
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'version': version,
      'status': status.name,
      'nonCompliantLibraries': nonCompliantLibraries,
    };
  }
}
