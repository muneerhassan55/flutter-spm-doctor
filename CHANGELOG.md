## 0.2.0

- Restructured the CLI around subcommands: `spm`, `uiscene`, `android16kb`, and `all`. Running `flutter_spm_doctor` with no subcommand still runs the `spm` check, exactly as before — existing scripts and CI configs continue to work unchanged.
- Added the `uiscene` check: best-effort, source-scan based detection of whether a plugin hooks into iOS `AppDelegate` lifecycle events and whether it has adopted `FlutterSceneLifeCycleDelegate`. Heuristic and intentionally conservative — ambiguous cases are flagged for manual review rather than marked as passing.
- Added the `android16kb` check: scans direct and transitive Android plugin dependencies for 16KB native-library page-size alignment compliance (required for Android 15+ devices since November 2025). Supports inspecting real `.so` files via `--apk`/`--aab` (pure-Dart ELF program header parsing), with a bundled `known_16kb_status.json` fallback list.
- Added the `all` subcommand, which runs all three checks and prints a sectioned report; `--json` produces one combined object with `spm`, `uiscene`, and `android16kb` keys.
- `--json`, `--fail-on-unsupported`, `--ignore`, and `--github-token` now work per-subcommand where relevant.

## 0.1.3

- Fix repository URL and history.

## 0.1.1

## 0.1.0

- Initial release.
- Parse `pubspec.lock` and `pubspec.yaml` to extract iOS/macOS dependencies.
- Tiered SPM support detection: GitHub repo check, known local status list.
- Formatted console table output and JSON output mode.
- Generate GitHub issue template for unsupported plugins.
