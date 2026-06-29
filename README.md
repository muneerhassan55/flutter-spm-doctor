# flutter_spm_doctor

[![pub package](https://img.shields.io/pub/v/flutter_spm_doctor.svg)](https://pub.dev/packages/flutter_spm_doctor)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

**Flutter Swift Package Manager (SPM) checker, UIScene lifecycle migration checker, and Android 16KB page-size alignment checker — all in one CLI doctor.**

A Flutter migration doctor for your plugin dependencies. It checks your project's `pubspec.lock` against three separate, currently-relevant Flutter ecosystem migrations and tells you which plugins are blocking you:

1. **Swift Package Manager (SPM)** — replacing CocoaPods on iOS/macOS.
2. **UIScene lifecycle** — the new iOS app-lifecycle model plugins must individually adopt.
3. **Android 16KB page-size alignment** — a native-library requirement for Android 15+ devices.

Each check can be run on its own, or all together with `all`. The original SPM check remains the default — running `flutter_spm_doctor` with no arguments behaves exactly as it did before 0.2.0.

## Why this exists

Flutter's ecosystem is mid-migration on multiple fronts at once, and there's no single place to see which of *your* dependencies are blocking you on any of them. Today you'd have to manually open each plugin's GitHub repo, dig through scattered migration-status threads, or build and inspect an APK by hand. `flutter_spm_doctor` automates all three audits from one CLI.

### Swift Package Manager (SPM)

As of Flutter 3.44, Swift Package Manager is the default iOS/macOS dependency manager, replacing CocoaPods. Plugins that haven't added a `Package.swift` file still work today via a CocoaPods fallback, but that fallback won't last forever — the CocoaPods trunk registry goes read-only on **December 2, 2026**. Right now only a fraction of popular iOS plugins have migrated.

### UIScene lifecycle

As of Flutter 3.41, UIScene lifecycle support is the default for iOS apps, and the app itself is migrated automatically. But plugins that hook into app lifecycle events (background tasks, push notifications, deep links, app-state listeners) must individually adopt the `FlutterSceneLifeCycleDelegate` protocol. Starting with the Flutter/iOS release following iOS 26, apps with non-migrated lifecycle-dependent plugins risk failing to launch or having broken lifecycle behavior.

This is a very recent, fast-evolving area of the SDK, so `flutter_spm_doctor`'s detection here is deliberately heuristic and conservative: it scans a plugin's iOS source for known `AppDelegate` lifecycle method names and `FlutterSceneLifeCycleDelegate` adoption, and favors flagging something for manual review over silently giving it a pass. Always cross-check against [Flutter's official UIScene migration guide](https://docs.flutter.dev/platform-integration/ios/ios-uiscenedelegate) for the final word.

### Android 16KB page-size alignment

Since November 2025, Android requires native libraries in apps targeting Android 15+ devices to be 16KB-page-size aligned (previously 4KB was sufficient). Apps with non-compliant native `.so` libraries — often bundled inside plugin packages, including *transitive* dependencies — get rejected or flagged by Google Play Console. `flutter_spm_doctor` walks your full resolved dependency tree (not just direct dependencies) and, given a built APK/AAB, parses ELF program headers directly (in pure Dart) to check real alignment values.

## Features

- 🔍 **Automatic plugin detection** — parses `pubspec.lock` and filters to packages with native iOS/macOS/Android code.
- 🧭 **Tiered detection** for each check: inspect the real source/binary first, fall back to a bundled known-status list, then fall back to "Unknown — verify manually."
- 🎨 **Color-coded console report** with a pass/fail summary line per check.
- 🤖 **`--json` output** for CI pipelines and other tooling.
- 🚦 **CI gating** via `--fail-on-unsupported`, with an `--ignore` allowlist for packages you've already accepted as blocked.
- ✍️ **One-command GitHub issue drafting** (`--generate-issue`) for the SPM check.
- ⚡ **Local caching** (`.dart_tool/flutter_spm_doctor/`, 24h TTL) to avoid hammering pub.dev/GitHub on repeated runs.
- 🪶 **Pure Dart** — no Flutter SDK required to run the tool itself.

## Installation

Install globally:

```bash
dart pub global activate flutter_spm_doctor
```

Or add it as a dev dependency to your project:

```bash
dart pub add dev:flutter_spm_doctor
```

## Usage

Run from your Flutter project's root directory (next to `pubspec.lock`):

```bash
flutter_spm_doctor                  # default: SPM check (unchanged pre-0.2.0 behavior)
flutter_spm_doctor spm              # explicit SPM check, same as above
flutter_spm_doctor uiscene          # UIScene lifecycle check
flutter_spm_doctor android16kb      # Android 16KB alignment check
flutter_spm_doctor all              # run all three, sectioned report
```

### `spm` options

| Flag | Description |
|---|---|
| `--json` | Output the report as structured JSON. |
| `--fail-on-unsupported` | Exit with code `1` if any plugin is not SPM-supported. |
| `--ignore=<packages>` | Comma-separated list of packages to exclude, e.g. `--ignore=package_a,package_b`. |
| `--generate-issue=<package>` | Print a ready-to-paste GitHub issue body asking the maintainer to add SPM support, pre-filled with the plugin name and your local Flutter version. |
| `--github-token=<token>` | GitHub personal access token, used to raise the GitHub API rate limit. Can also be set via the `GITHUB_TOKEN` environment variable. |

### `uiscene` options

| Flag | Description |
|---|---|
| `--json` | Output the report as structured JSON. |
| `--fail-on-unsupported` | Exit with code `1` if any plugin needs review (uses lifecycle events without detected UIScene adoption). |
| `--ignore=<packages>` | Comma-separated list of packages to exclude. |
| `--github-token=<token>` | GitHub personal access token / `GITHUB_TOKEN` env var. |

### `android16kb` options

| Flag | Description |
|---|---|
| `--json` | Output the report as structured JSON. |
| `--fail-on-unsupported` | Exit with code `1` if any plugin is not 16KB-aligned. |
| `--ignore=<packages>` | Comma-separated list of packages to exclude. |
| `--apk=<path>` | Path to a built APK — inspects bundled `.so` files directly via pure-Dart ELF parsing, instead of relying on the known-status list. |
| `--aab=<path>` | Path to a built AAB. Same effect as `--apk`. |

### `all` options

Accepts `--json`, `--fail-on-unsupported`, `--ignore`, `--github-token`, `--apk`, and `--aab` — applied across all three checks.

## Example output

```
Checking SPM support for 5 iOS/macOS plugins...

✅ package_info_plus (v8.0.0)
✅ url_launcher (v6.3.0)
❌ outdated_plugin (v1.2.0) - SPM not supported
   Open an issue: https://github.com/maintainer/outdated_plugin/issues
⚠️ unknown_plugin (v2.0.0) - Unknown status
   Verify manually: https://github.com/author/unknown_plugin/issues?q=is%3Aissue+Swift+Package+Manager

Summary: 2 of 4 plugins are SPM-ready.
```

```
flutter_spm_doctor uiscene

Checking UIScene lifecycle migration for 3 iOS/macOS plugins...

✅ some_modern_plugin (v2.0.0) - Migrated
⚠️ legacy_push_plugin (v1.4.0) - Needs review: uses lifecycle events, no UIScene adoption detected
   Inspect source: https://github.com/maintainer/legacy_push_plugin
➖ url_launcher (v6.3.0) - Not applicable

Summary: 1 of 3 plugins explicitly adopt UIScene lifecycle.
Note: this check is heuristic (source-scan based) and this is a newly evolving area of the Flutter SDK. ...
```

### JSON output

```bash
flutter_spm_doctor spm --json
flutter_spm_doctor all --json   # {"spm": {...}, "uiscene": {...}, "android16kb": {...}}
```

### Gating CI on migration readiness

```bash
flutter_spm_doctor all --fail-on-unsupported --ignore=outdated_plugin
```

Fails the build if any *non-ignored* plugin has an issue in any of the three checks — handy for tracking migration progress without blocking on packages you've already triaged.

### Checking real `.so` alignment from a built APK

```bash
flutter build apk --release
flutter_spm_doctor android16kb --apk=build/app/outputs/flutter-apk/app-release.apk
```

### Drafting an SPM migration request

```bash
flutter_spm_doctor spm --generate-issue=outdated_plugin
```

Prints a filled-in issue body (based on Flutter's official migration guide) that you can paste straight into the plugin's GitHub issue tracker.

## FAQ

#### How do I check if a Flutter plugin supports Swift Package Manager?

Run `flutter_spm_doctor` (or `flutter_spm_doctor spm`) in your project root. It reads `pubspec.lock`, finds your iOS/macOS plugins, and reports which ones have a `Package.swift` and which are still CocoaPods-only.

#### How do I know if my Flutter app is ready for the CocoaPods to SPM migration?

Run the `spm` check with `--fail-on-unsupported` in CI. It exits non-zero if any non-ignored plugin hasn't migrated, so you can track readiness over time instead of finding out at the CocoaPods registry's December 2026 cutoff.

#### How do I check Flutter plugins for UIScene lifecycle / iOS 26 lifecycle support?

Run `flutter_spm_doctor uiscene`. It scans each plugin's iOS source for `AppDelegate` lifecycle hooks and `FlutterSceneLifeCycleDelegate` adoption and flags anything that needs manual review.

#### How do I check Android 16KB page size alignment for Flutter plugins?

Run `flutter_spm_doctor android16kb`, optionally with `--apk=<path>` against a built APK/AAB, to check whether your app's (including transitive) native `.so` libraries are 16KB-page-size aligned for Android 15+.

#### Does this work without the Flutter SDK installed?

Yes — it's pure Dart and only needs your project's `pubspec.lock`.

## Contributing to the known-status lists

[`lib/src/known_spm_status.json`](lib/src/known_spm_status.json) and [`lib/src/services/known_16kb_status.json`](lib/src/services/known_16kb_status.json) are fallback lists used when a plugin's source/binary can't be inspected automatically. The 16KB list ships empty — it needs real, community-sourced compliance data. PRs updating either file are welcome.

## License

MIT — see [LICENSE](LICENSE).
