import 'dart:convert';
import '../models/plugin_info.dart';

/// Prints the SPM status report as structured JSON for CI pipelines and
/// other tooling.
class JsonReporter {
  /// Encodes [plugins] as a JSON object with a `plugins` array and writes
  /// it to stdout.
  void report(List<PluginInfo> plugins) {
    final list = plugins.map((p) => p.toJson()).toList();
    print(jsonEncode({'plugins': list}));
  }
}
