import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_spm_doctor/flutter_spm_doctor.dart';
import 'package:flutter_spm_doctor/src/services/uiscene_checker.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockClient extends Mock implements http.Client {}

/// Builds a minimal valid 64-bit ELF file with one `PT_LOAD` program
/// header segment per entry in [loadAlignments], for testing
/// [ElfAlignmentParser] without needing a real `.so` fixture on disk.
Uint8List buildMinimalElf64(
  List<int> loadAlignments, {
  bool littleEndian = true,
}) {
  const headerSize = 64;
  const phentsize = 56;
  final phnum = loadAlignments.length;
  final bytes = Uint8List(headerSize + phentsize * phnum);
  final data = ByteData.sublistView(bytes);
  final endian = littleEndian ? Endian.little : Endian.big;

  bytes[0] = 0x7f;
  bytes[1] = 0x45; // E
  bytes[2] = 0x4c; // L
  bytes[3] = 0x46; // F
  bytes[4] = 2; // ELFCLASS64
  bytes[5] = littleEndian ? 1 : 2;
  bytes[6] = 1; // EI_VERSION

  data.setUint64(0x20, headerSize, endian); // e_phoff
  data.setUint16(0x36, phentsize, endian); // e_phentsize
  data.setUint16(0x38, phnum, endian); // e_phnum

  for (var i = 0; i < phnum; i++) {
    final off = headerSize + i * phentsize;
    data.setUint32(off, 1, endian); // p_type = PT_LOAD
    data.setUint64(off + 48, loadAlignments[i], endian); // p_align
  }

  return bytes;
}

/// Runs [body], capturing every `print()` call instead of writing to
/// stdout, so reporter output can be asserted on directly.
List<String> captureOutput(void Function() body) {
  final lines = <String>[];
  runZoned(
    body,
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) => lines.add(line),
    ),
  );
  return lines;
}

void main() {
  setUpAll(() {
    registerFallbackValue(Uri.parse('https://example.com'));
  });

  group('PubDevClient Tests', () {
    late MockClient mockClient;
    late CacheService cacheService;
    late PubDevClient pubClient;

    setUp(() {
      mockClient = MockClient();
      cacheService = CacheService();
      pubClient = PubDevClient(mockClient, cacheService);
    });

    test('Identifies iOS/macOS plugin', () async {
      when(() => mockClient.get(any())).thenAnswer(
        (_) async => http.Response(
          jsonEncode({
            'latest': {
              'pubspec': {
                'repository': 'https://github.com/flutter/packages',
                'flutter': {
                  'plugin': {
                    'platforms': {'ios': {}, 'android': {}},
                  },
                },
              },
            },
          }),
          200,
        ),
      );

      final info = await pubClient.getPackageInfo('test_package');
      expect(info, isNotNull);
      expect(info!.isIosMacosPlugin, isTrue);
      expect(info.repositoryUrl, 'https://github.com/flutter/packages');
    });

    test('Ignores non-plugin package', () async {
      when(() => mockClient.get(any())).thenAnswer(
        (_) async => http.Response(
          jsonEncode({
            'latest': {
              'pubspec': {'repository': 'https://github.com/flutter/packages'},
            },
          }),
          200,
        ),
      );

      final info = await pubClient.getPackageInfo('test_package_2');
      expect(info, isNotNull);
      expect(info!.isIosMacosPlugin, isFalse);
    });
  });

  group('GithubClient Tests', () {
    late MockClient mockClient;
    late CacheService cacheService;
    late GithubClient githubClient;

    setUp(() {
      mockClient = MockClient();
      cacheService = CacheService();
      githubClient = GithubClient(mockClient, cacheService);
    });

    test('Returns true if Package.swift exists', () async {
      when(
        () => mockClient.head(
          Uri.parse(
            'https://raw.githubusercontent.com/owner/repo/main/ios/Package.swift',
          ),
          headers: any(named: 'headers'),
        ),
      ).thenAnswer((_) async => http.Response('', 200));

      final result = await githubClient.hasPackageSwift(
        'https://github.com/owner/repo',
      );
      expect(result, isTrue);
    });

    test('Returns false if Package.swift missing', () async {
      when(
        () => mockClient.head(any(), headers: any(named: 'headers')),
      ).thenAnswer((_) async => http.Response('', 404));

      final result = await githubClient.hasPackageSwift(
        'https://github.com/owner/repo2',
      );
      expect(result, isFalse);
    });
  });

  group('SpmChecker Tests', () {
    late MockClient mockClient;
    late CacheService cacheService;
    late PubDevClient pubClient;
    late GithubClient githubClient;
    late SpmChecker checker;

    setUp(() {
      mockClient = MockClient();
      cacheService = CacheService();
      pubClient = PubDevClient(mockClient, cacheService);
      githubClient = GithubClient(mockClient, cacheService);
      checker = SpmChecker(pubClient, githubClient);
    });

    test('Returns supported status when GitHub has Package.swift', () async {
      // Mock pub.dev
      when(
        () =>
            mockClient.get(Uri.parse('https://pub.dev/api/packages/my_plugin')),
      ).thenAnswer(
        (_) async => http.Response(
          jsonEncode({
            'latest': {
              'pubspec': {
                'repository': 'https://github.com/owner/my_plugin',
                'flutter': {
                  'plugin': {
                    'platforms': {'ios': {}},
                  },
                },
              },
            },
          }),
          200,
        ),
      );

      // Mock GitHub
      when(
        () => mockClient.head(
          Uri.parse(
            'https://raw.githubusercontent.com/owner/my_plugin/main/ios/Package.swift',
          ),
          headers: any(named: 'headers'),
        ),
      ).thenAnswer((_) async => http.Response('', 200));

      final plugin = await checker.checkPlugin('my_plugin', '1.0.0');

      expect(plugin, isNotNull);
      expect(plugin!.name, 'my_plugin');
      expect(plugin.status, SpmStatus.supported);
    });
  });

  group('ElfAlignmentParser Tests', () {
    test('rejects non-ELF bytes', () {
      final result = ElfAlignmentParser.parse(Uint8List.fromList([1, 2, 3]));
      expect(result.isValidElf, isFalse);
      expect(result.isAligned, isFalse);
    });

    test('flags a PT_LOAD segment below 16KB as not aligned', () {
      final bytes = buildMinimalElf64([0x1000]); // 4KB
      final result = ElfAlignmentParser.parse(bytes);

      expect(result.isValidElf, isTrue);
      expect(result.is64Bit, isTrue);
      expect(result.loadSegmentAlignments, [0x1000]);
      expect(result.isAligned, isFalse);
    });

    test('accepts PT_LOAD segments at or above 16KB as aligned', () {
      final bytes = buildMinimalElf64([0x4000, 0x10000]); // 16KB, 64KB
      final result = ElfAlignmentParser.parse(bytes);

      expect(result.isValidElf, isTrue);
      expect(result.isAligned, isTrue);
    });

    test('is not aligned if any one of several segments is below 16KB', () {
      final bytes = buildMinimalElf64([0x4000, 0x1000]);
      final result = ElfAlignmentParser.parse(bytes);

      expect(result.isAligned, isFalse);
    });

    test('treats a file with no PT_LOAD segments as aligned', () {
      final bytes = buildMinimalElf64([]);
      final result = ElfAlignmentParser.parse(bytes);

      expect(result.isValidElf, isTrue);
      expect(result.loadSegmentAlignments, isEmpty);
      expect(result.isAligned, isTrue);
    });
  });

  group('UiSceneChecker.classifySourceContents Tests', () {
    test('detects FlutterSceneLifeCycleDelegate adoption as migrated', () {
      final status = UiSceneChecker.classifySourceContents([
        'class MyPlugin: NSObject, FlutterSceneLifeCycleDelegate {}',
      ]);
      expect(status, UiSceneStatus.migrated);
    });

    test(
      'flags AppDelegate lifecycle method usage without adoption as needsReview',
      () {
        final status = UiSceneChecker.classifySourceContents([
          'func applicationDidBecomeActive(_ application: UIApplication) {}',
        ]);
        expect(status, UiSceneStatus.needsReview);
      },
    );

    test('treats unrelated source as not applicable', () {
      final status = UiSceneChecker.classifySourceContents([
        'class MyPlugin: NSObject, FlutterPlugin {}',
      ]);
      expect(status, UiSceneStatus.notApplicable);
    });

    test('prefers migrated even if lifecycle methods are also present', () {
      final status = UiSceneChecker.classifySourceContents([
        'func applicationDidBecomeActive(_ application: UIApplication) {}',
        'class MyPlugin: FlutterSceneLifeCycleDelegate {}',
      ]);
      expect(status, UiSceneStatus.migrated);
    });
  });

  group('ConsoleReporter sectioned output Tests', () {
    test('reportAll prints all three section headers', () {
      final lines = captureOutput(() {
        ConsoleReporter().reportAll(
          spm: [
            PluginInfo(
              name: 'spm_plugin',
              version: '1.0.0',
              status: SpmStatus.supported,
            ),
          ],
          uiscene: [
            UiScenePluginInfo(
              name: 'uiscene_plugin',
              version: '1.0.0',
              status: UiSceneStatus.notApplicable,
            ),
          ],
          android16kb: [
            Android16kbPluginInfo(
              name: 'android_plugin',
              version: '1.0.0',
              status: Android16kbStatus.compliant,
            ),
          ],
        );
      });

      final joined = lines.join('\n');
      expect(joined, contains('Swift Package Manager'));
      expect(joined, contains('UIScene Lifecycle'));
      expect(joined, contains('16KB Page-Size Alignment'));
      expect(joined, contains('spm_plugin'));
      expect(joined, contains('uiscene_plugin'));
      expect(joined, contains('android_plugin'));
    });
  });

  group('JsonReporter combined output Tests', () {
    test('reportAll emits one object with spm/uiscene/android16kb keys', () {
      final lines = captureOutput(() {
        JsonReporter().reportAll(
          spm: [
            PluginInfo(
              name: 'spm_plugin',
              version: '1.0.0',
              status: SpmStatus.supported,
            ),
          ],
          uiscene: [
            UiScenePluginInfo(
              name: 'uiscene_plugin',
              version: '1.0.0',
              status: UiSceneStatus.unknown,
            ),
          ],
          android16kb: [
            Android16kbPluginInfo(
              name: 'android_plugin',
              version: '1.0.0',
              status: Android16kbStatus.nonCompliant,
            ),
          ],
        );
      });

      expect(lines, hasLength(1));
      final decoded = jsonDecode(lines.single) as Map<String, dynamic>;
      expect(decoded.keys, containsAll(['spm', 'uiscene', 'android16kb']));

      final spmPlugins = decoded['spm']['plugins'] as List;
      expect(spmPlugins.single['name'], 'spm_plugin');

      final android16kbPlugins = decoded['android16kb']['plugins'] as List;
      expect(android16kbPlugins.single['status'], 'nonCompliant');
    });
  });
}
