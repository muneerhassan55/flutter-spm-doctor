import 'dart:io';
import 'package:args/command_runner.dart';

import 'package:flutter_spm_doctor/src/commands/android16kb_command.dart';
import 'package:flutter_spm_doctor/src/commands/all_command.dart';
import 'package:flutter_spm_doctor/src/commands/spm_command.dart';
import 'package:flutter_spm_doctor/src/commands/uiscene_command.dart';

/// Subcommand names recognized by the CLI. Used to decide whether to
/// transparently prepend the default `spm` command for backward
/// compatibility with pre-0.2.0 invocations like `flutter_spm_doctor --json`.
const _knownCommands = {'spm', 'uiscene', 'android16kb', 'all'};

Future<void> main(List<String> arguments) async {
  final runner =
      CommandRunner<void>(
          'flutter_spm_doctor',
          'Detect Flutter ecosystem migration issues (SPM, UIScene lifecycle, '
              'Android 16KB page alignment) across your plugin dependencies.',
        )
        ..addCommand(SpmCommand())
        ..addCommand(UiSceneCommand())
        ..addCommand(Android16kbCommand())
        ..addCommand(AllCommand());

  // Backward compatibility: prior to 0.2.0, this tool had no subcommands and
  // always ran the SPM check. If the first argument isn't a recognized
  // subcommand (or a global flag like --help), treat the invocation as an
  // implicit `spm` call so existing scripts/CI configs keep working.
  final effectiveArgs = _withDefaultCommand(arguments);

  try {
    await runner.run(effectiveArgs);
  } on UsageException catch (e) {
    print(e);
    exit(64);
  }

  exit(exitCode);
}

List<String> _withDefaultCommand(List<String> arguments) {
  if (arguments.isEmpty) {
    return ['spm'];
  }

  final first = arguments.first;
  if (_knownCommands.contains(first) ||
      first == '-h' ||
      first == '--help' ||
      first == 'help') {
    return arguments;
  }

  return ['spm', ...arguments];
}
