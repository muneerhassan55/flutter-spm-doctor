/// A Flutter migration doctor for plugin dependencies: checks for Swift
/// Package Manager (SPM), UIScene lifecycle, and Android 16KB page-size
/// alignment migration readiness.
///
/// Exposes the models, services, and reporters used to read a project's
/// `pubspec.lock`, classify its native plugins, and report each check's
/// migration status.
library;

export 'src/models/android16kb_status.dart';
export 'src/models/plugin_info.dart';
export 'src/models/spm_status.dart';
export 'src/models/uiscene_status.dart';
export 'src/services/android16kb_checker.dart';
export 'src/services/cache_service.dart';
export 'src/services/elf_alignment_parser.dart';
export 'src/services/github_client.dart';
export 'src/services/pub_dev_client.dart';
export 'src/services/pubspec_reader.dart';
export 'src/services/spm_checker.dart';
export 'src/reporters/console_reporter.dart';
export 'src/reporters/json_reporter.dart';
export 'src/issue_template.dart';
