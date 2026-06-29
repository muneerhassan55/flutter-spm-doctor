import 'dart:convert';
import '../models/android16kb_status.dart';
import '../models/plugin_info.dart';
import '../models/uiscene_status.dart';

/// Prints migration check results as structured JSON for CI pipelines and
/// other tooling.
class JsonReporter {
  /// Encodes [plugins] as a JSON object with a `plugins` array and writes
  /// it to stdout.
  void report(List<PluginInfo> plugins) {
    print(jsonEncode(buildSpmJson(plugins)));
  }

  /// Encodes [plugins]' UIScene lifecycle status as a JSON object with a
  /// `plugins` array and writes it to stdout.
  void reportUiScene(List<UiScenePluginInfo> plugins) {
    print(jsonEncode(buildUiSceneJson(plugins)));
  }

  /// Encodes [plugins]' Android 16KB alignment status as a JSON object
  /// with a `plugins` array and writes it to stdout.
  void reportAndroid16kb(List<Android16kbPluginInfo> plugins) {
    print(jsonEncode(buildAndroid16kbJson(plugins)));
  }

  /// Encodes all three checks into one combined JSON object with `spm`,
  /// `uiscene`, and `android16kb` keys, and writes it to stdout.
  void reportAll({
    required List<PluginInfo> spm,
    required List<UiScenePluginInfo> uiscene,
    required List<Android16kbPluginInfo> android16kb,
  }) {
    print(
      jsonEncode({
        'spm': buildSpmJson(spm),
        'uiscene': buildUiSceneJson(uiscene),
        'android16kb': buildAndroid16kbJson(android16kb),
      }),
    );
  }

  /// Builds the JSON-serializable map for an SPM check report, without
  /// printing it. Used directly by [report] and shared with [reportAll].
  Map<String, dynamic> buildSpmJson(List<PluginInfo> plugins) {
    return {'plugins': plugins.map((p) => p.toJson()).toList()};
  }

  /// Builds the JSON-serializable map for a UIScene check report, without
  /// printing it.
  Map<String, dynamic> buildUiSceneJson(List<UiScenePluginInfo> plugins) {
    return {'plugins': plugins.map((p) => p.toJson()).toList()};
  }

  /// Builds the JSON-serializable map for an Android 16KB check report,
  /// without printing it.
  Map<String, dynamic> buildAndroid16kbJson(
    List<Android16kbPluginInfo> plugins,
  ) {
    return {'plugins': plugins.map((p) => p.toJson()).toList()};
  }
}
