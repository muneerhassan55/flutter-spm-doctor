import 'spm_status.dart';

/// A native iOS/macOS plugin dependency discovered in the project's
/// `pubspec.lock`, along with its resolved version and SPM migration status.
class PluginInfo {
  /// The package name as it appears on pub.dev.
  final String name;

  /// The resolved version installed in the project.
  final String version;

  /// The plugin's Swift Package Manager migration status.
  SpmStatus status;

  /// The plugin's source repository URL, if one is linked on pub.dev.
  String? repositoryUrl;

  /// Creates a [PluginInfo] for a resolved plugin dependency.
  PluginInfo({
    required this.name,
    required this.version,
    this.status = SpmStatus.unknown,
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
