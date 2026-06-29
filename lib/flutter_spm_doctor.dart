/// Detects which Flutter plugin dependencies haven't migrated to
/// Swift Package Manager (SPM) yet.
///
/// Exposes the models, services, and reporters used to read a project's
/// `pubspec.lock`, classify its native iOS/macOS plugins, and report their
/// SPM migration status.
library;

export 'src/models/plugin_info.dart';
export 'src/models/spm_status.dart';
export 'src/services/pubspec_reader.dart';
export 'src/services/pub_dev_client.dart';
export 'src/services/github_client.dart';
export 'src/services/spm_checker.dart';
export 'src/services/cache_service.dart';
export 'src/reporters/console_reporter.dart';
export 'src/reporters/json_reporter.dart';
export 'src/issue_template.dart';
