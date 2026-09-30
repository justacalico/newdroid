import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:newdroid/models/index_models.dart';
import 'package:newdroid/models/repo_config.dart';

void main() {
  group('RepoConfig', () {
    test('defaults contain F-Droid enabled', () {
      final repos = RepoConfig.defaults();
      expect(repos.length, 3);
      expect(repos.first.name, 'F-Droid');
      expect(repos.first.enabled, isTrue);
      expect(repos[1].enabled, isFalse);
      expect(repos.every((r) => r.builtIn), isTrue);
    });

    test('id and baseUrl normalize url', () {
      final r = RepoConfig(url: 'https://x.test/repo/', name: 'X');
      expect(r.baseUrl, 'https://x.test/repo');
      expect(r.id, 'https___x_test_repo_');
      expect(r.fileUrl('/a.apk'), 'https://x.test/repo/a.apk');
      expect(r.fileUrl('icon/a.png'), 'https://x.test/repo/icon/a.png');
    });

    test('json round trip', () {
      final repos = RepoConfig.defaults()
        ..add(RepoConfig(url: 'https://c.test/r', name: 'Custom', enabled: false));
      final decoded = RepoConfig.decodeList(RepoConfig.encodeList(repos));
      expect(decoded.length, 4);
      expect(decoded[3].name, 'Custom');
      expect(decoded[3].enabled, isFalse);
      expect(decoded[3].builtIn, isFalse);
      expect(decoded[0].enabled, isTrue);
    });

    test('fromJson fills defaults', () {
      final r = RepoConfig.fromJson({'url': 'https://a.test'});
      expect(r.name, 'https://a.test');
      expect(r.enabled, isTrue);
      expect(r.builtIn, isFalse);
    });
  });

  group('index v2 parsing', () {
    late FdroidIndex index;

    setUpAll(() async {
      index = parseIndexJson(
          await File('test/fixtures/index_v2.json').readAsString());
    });

    test('repo metadata', () {
      expect(index.repoName, 'Test Repo');
      expect(index.repoAddress, 'https://repo.test/repo');
      expect(index.packages.length, 3);
    });

    test('package fields', () {
      final p = index.packages['org.test.alpha']!;
      expect(p.name, 'Alpha App');
      expect(p.summary, 'The alpha app');
      expect(p.description, contains('alpha'));
      expect(p.categories, ['Internet', 'System']);
      expect(p.license, 'GPL-3.0-only');
      expect(p.authorName, 'Alpha Dev');
      expect(p.webSite, 'https://alpha.test');
      expect(p.sourceCode, 'https://code.test/alpha');
      expect(p.issueTracker, 'https://code.test/alpha/issues');
      expect(p.changelog, 'https://code.test/alpha/CHANGELOG');
      expect(p.donate, 'https://donate.test/alpha');
      expect(p.added, 1700000000000);
      expect(p.lastUpdated, 1700500000000);
      expect(p.icon!.name, 'icon/org.test.alpha.2.png');
      expect(p.screenshots.length, 2);
      expect(p.suggestedVersionCode, 3);
      expect(p.antiFeatures, contains('Ads'));
    });

    test('versions sorted desc with manifest fields', () {
      final p = index.packages['org.test.alpha']!;
      expect(p.versions.length, 2);
      final v = p.versions.first;
      expect(v.versionCode, 3);
      expect(v.versionName, '1.2.0');
      expect(v.fileName, '/org.test.alpha_3.apk');
      expect(v.sha256, 'aabbcc');
      expect(v.size, 1024);
      expect(v.minSdk, 21);
      expect(v.targetSdk, 34);
      expect(v.signerSha256, 'deadbeef');
      expect(v.permissions, contains('android.permission.INTERNET'));
      expect(v.permissions, contains('android.permission.VIBRATE'));
      expect(v.permissions, contains('android.permission.POST_NOTIFICATIONS'));
      expect(v.nativeCode, ['arm64-v8a']);
      expect(v.whatsNew, 'Bug fixes');
      expect(v.antiFeatures, contains('Tracking'));
    });

    test('bestVersion honours suggestedVersionCode', () {
      final p = index.packages['org.test.alpha']!;
      expect(p.bestVersion!.versionCode, 3);
      final beta = index.packages['org.test.beta']!;
      expect(beta.bestVersion!.versionCode, 9);
      expect(index.packages['org.test.empty']!.bestVersion, isNull);
    });

    test('missing name falls back to package name', () {
      expect(index.packages['org.test.beta']!.name, 'org.test.beta');
      expect(index.packages['org.test.beta']!.icon!.name, 'icon/beta.png');
    });
  });

  group('index v1 parsing', () {
    test('parses apps and packages', () async {
      final index = parseIndexJson(
          await File('test/fixtures/index_v1.json').readAsString());
      expect(index.packages.length, 2);
      final p = index.packages['org.v1.gamma']!;
      expect(p.name, 'Gamma App');
      expect(p.summary, 'V1 gamma');
      expect(p.license, 'MIT');
      expect(p.authorName, 'Gamma Dev');
      expect(p.icon!.name, 'icons/org.v1.gamma.5.png');
      expect(p.versions.length, 2);
      final v = p.versions.first;
      expect(v.versionCode, 5);
      expect(v.fileName, 'org.v1.gamma_5.apk');
      expect(v.sha256, 'beef');
      expect(v.minSdk, 21);
      expect(v.signerSha256, 'cafe');
      expect(v.permissions.length, 2);
      expect(v.nativeCode, ['armeabi-v7a']);
      expect(p.suggestedVersionCode, 5);
      expect(index.packages['org.v1.noname']!.name, 'org.v1.noname');
    });
  });

  group('helpers', () {
    test('pickLocalized handles string, map, missing', () {
      expect(pickLocalized('plain'), 'plain');
      expect(pickLocalized({'en-US': 'english', 'de': 'deutsch'}), 'english');
      expect(pickLocalized({'de': 'deutsch'}), 'deutsch');
      expect(pickLocalized({'en-US': ''}), '');
      expect(pickLocalized(null), '');
      expect(pickLocalized(42), '');
    });

    test('localizedKeys', () {
      expect(localizedKeys({'a': 1}), ['a']);
      expect(localizedKeys('x'), isEmpty);
    });

    test('FileRef.fromJson rejects bad input', () {
      expect(FileRef.fromJson(null), isNull);
      expect(FileRef.fromJson('x'), isNull);
      expect(FileRef.fromJson({'name': ''}), isNull);
      final ref = FileRef.fromJson({'name': 'a.png', 'size': 5, 'sha256': 'x'})!;
      expect(ref.size, 5);
      expect(ref.sha256, 'x');
    });
  });
}
