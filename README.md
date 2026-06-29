# flutter_spm_doctor

[![pub package](https://img.shields.io/pub/v/flutter_spm_doctor.svg)](https://pub.dev/packages/flutter_spm_doctor)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Detect which Flutter plugin dependencies haven't migrated to Swift Package Manager (SPM) yet — a CLI doctor for the CocoaPods → SPM transition.

## Why this exists

As of Flutter 3.44, Swift Package Manager is the default iOS/macOS dependency manager, replacing CocoaPods. Plugins that haven't added a `Package.swift` file still work today via a CocoaPods fallback, but that fallback won't last forever — the CocoaPods trunk registry goes read-only on **December 2, 2026**.

Right now only a fraction of popular iOS plugins have migrated, and there's no easy way to audit your own project's dependency tree to see which ones are blocking you. Today you'd have to manually open every plugin's GitHub repo, dig for an `ios/Package.swift` file, and read scattered migration-status threads.

`flutter_spm_doctor` automates that audit: it reads your `pubspec.lock`, finds your native iOS/macOS plugins, checks each one's SPM status, and gives you a clear report — plus tools to push migration along (CI gating, ready-to-file GitHub issues).

## Features

- 🔍 **Automatic plugin detection** — parses `pubspec.lock`/`pubspec.yaml` and filters to packages with native iOS/macOS code.
- 🧭 **Tiered SPM detection**
  1. Checks the plugin's linked GitHub repo for `ios/Package.swift` or `macos/Package.swift`.
  2. Falls back to a bundled, community-updatable list of known plugins (`known_spm_status.json`).
  3. Falls back to "Unknown — verify manually" with a direct link to search the repo's issues.
- 🎨 **Color-coded console report** with a pass/fail summary line.
- 🤖 **`--json` output** for CI pipelines and other tooling.
- 🚦 **CI gating** via `--fail-on-unsupported`, with an `--ignore` allowlist for packages you've already accepted as blocked.
- ✍️ **One-command GitHub issue drafting** (`--generate-issue`) so you can ask a maintainer to add SPM support without writing the request yourself.
- ⚡ **Local caching** (`.dart_tool/spm_doctor_cache.json`, 24h TTL) to avoid hammering pub.dev/GitHub on repeated runs.
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

Run the doctor from your Flutter project's root directory (next to `pubspec.lock`):

```bash
flutter_spm_doctor
# or, if added as a dev dependency
dart run flutter_spm_doctor
```

### Options

| Flag | Description |
|---|---|
| `--json` | Output the report as structured JSON instead of a console table. |
| `--fail-on-unsupported` | Exit with code `1` if any plugin is not SPM-supported. Use this in CI to gate builds. |
| `--ignore=<packages>` | Comma-separated list of packages to exclude from the report/exit-code check, e.g. `--ignore=package_a,package_b`. |
| `--generate-issue=<package>` | Print a ready-to-paste GitHub issue body asking the maintainer to add SPM support, pre-filled with the plugin name and your local Flutter version. |
| `--github-token=<token>` | GitHub personal access token, used to raise the GitHub API rate limit. Can also be set via the `GITHUB_TOKEN` environment variable. |

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

### JSON output

```bash
flutter_spm_doctor --json
```

```json
{
  "summary": { "ready": 2, "total": 4 },
  "plugins": [
    { "name": "package_info_plus", "version": "8.0.0", "status": "supported" },
    { "name": "url_launcher", "version": "6.3.0", "status": "supported" },
    {
      "name": "outdated_plugin",
      "version": "1.2.0",
      "status": "unsupported",
      "issueUrl": "https://github.com/maintainer/outdated_plugin/issues"
    },
    {
      "name": "unknown_plugin",
      "version": "2.0.0",
      "status": "unknown",
      "issueUrl": "https://github.com/author/unknown_plugin/issues?q=is%3Aissue+Swift+Package+Manager"
    }
  ]
}
```

### Gating CI on SPM readiness

```bash
flutter_spm_doctor --fail-on-unsupported --ignore=outdated_plugin
```

This fails the build if any *non-ignored* plugin lacks SPM support — handy for tracking migration progress without blocking on packages you've already triaged.

### Drafting a migration request

```bash
flutter_spm_doctor --generate-issue=outdated_plugin
```

Prints a filled-in issue body (based on Flutter's official migration guide) that you can paste straight into the plugin's GitHub issue tracker.

## Contributing to `known_spm_status.json`

The bundled [`lib/src/known_spm_status.json`](lib/src/known_spm_status.json) file is a fallback list of well-known plugins and their last-checked SPM status, used when a plugin's GitHub repo can't be parsed automatically. If you know a plugin's status is stale or missing, PRs updating this file are welcome.

## License

MIT — see [LICENSE](LICENSE).
