import 'dart:convert';

import 'package:flutter_spm_doctor/flutter_spm_doctor.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockClient extends Mock implements http.Client {}

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
}
