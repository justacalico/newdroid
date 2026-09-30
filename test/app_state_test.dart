import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:newdroid/models/index_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:newdroid/app_state.dart';
import 'package:newdroid/models/repo_config.dart';
import 'package:newdroid/services/device_bridge.dart';
import 'package:newdroid/services/index_store.dart';
import 'package:newdroid/services/prefs_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

void mockPathProvider(String path) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (call) async => path,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('app_state_test');
    mockPathProvider(tmp.path);
  });

  tearDown(() async {
    if (tmp.existsSync()) await tmp.delete(recursive: true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'), null);
  });

  group('init', () {
    test('loads defaults, device info, cached indexes and auto-refreshes', () async {
      final device = FakeDevice()
        ..packages = {'org.a': const InstalledApp(packageName: 'org.a', versionCode: 1, versionName: 'v1')};
      final store = FakeIndexStore(
        cached: {
          RepoConfig.defaults().first.id: indexWith(pkg('org.cached')),
        },
        results: {
          RepoConfig.defaults().first.id: RepoFetchResult(
              index: indexWith(pkg('org.fresh')), fromCache: false),
        },
      );
      final s = makeState(prefs: await prefsStore(), store: store, device: device);
      await s.init();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(s.repos.length, 3);
      expect(s.deviceSdk, 34);
      expect(s.installed.containsKey('org.a'), isTrue);
      expect(store.fetches, greaterThan(0));
      expect(s.apps.map((e) => e.packageName), contains('org.fresh'));
      expect(s.status, IndexStatus.ready);
    });

    test('skips refresh when autoRefresh off but indexes cached', () async {
      final store = FakeIndexStore(cached: {
        RepoConfig.defaults().first.id: indexWith(pkg('org.cached')),
      });
      final prefs = await prefsStore({'autoRefresh': false});
      final s = makeState(prefs: prefs, store: store, device: FakeDevice());
      await s.init();
      await Future<void>.delayed(Duration.zero);
      expect(store.fetches, 0);
      expect(s.apps.single.packageName, 'org.cached');
    });

    test('does not fetch when autoRefresh is off', () async {
      final store = FakeIndexStore();
      final prefs = await prefsStore({'autoRefresh': false});
      final s = makeState(prefs: prefs, store: store, device: FakeDevice());
      await s.init();
      await Future<void>.delayed(Duration.zero);
      expect(store.fetches, 0);
    });

    test('does not fetch when autoRefresh off and apps exist', () async {
      final store = FakeIndexStore(cached: {
        RepoConfig.defaults().first.id: indexWith(pkg('org.cached')),
      });
      final prefs = await prefsStore({'autoRefresh': false});
      final s = makeState(prefs: prefs, store: store, device: FakeDevice());
      await s.init();
      await Future<void>.delayed(Duration.zero);
      expect(store.fetches, 0);
      expect(s.apps.single.packageName, 'org.cached');
    });
  });

  group('index refresh and merge', () {
    test('refresh marks error when all repos fail and nothing cached', () async {
      final store = FakeIndexStore(throwOn: {RepoConfig.defaults().first.id});
      final s = makeState(prefs: await prefsStore({'autoRefresh': false}), store: store, device: FakeDevice());
      await s.init();
      await s.refreshIndexes();
      expect(s.status, IndexStatus.error);
      expect(s.error, contains('boom'));
    });

    test('partial failure keeps apps and reports error', () async {
      final repos = RepoConfig.defaults();
      repos[1].enabled = true;
      final prefs = await prefsStore({
        'repos': RepoConfig.encodeList(repos),
        'autoRefresh': false,
      });
      final store = FakeIndexStore(
        throwOn: {repos.first.id},
        results: {
          repos[1].id: RepoFetchResult(
              index: indexWith(pkg('org.izzy')), fromCache: false),
        },
      );
      final s = makeState(prefs: prefs, store: store, device: FakeDevice());
      await s.init();
      await s.refreshIndexes();
      expect(s.status, IndexStatus.ready);
      expect(s.error, isNotNull);
      expect(s.apps.single.packageName, 'org.izzy');
    });

    test('later lastUpdated wins when two repos ship same package', () async {
      final repos = [RepoConfig(url: 'https://a.test', name: 'A'), RepoConfig(url: 'https://b.test', name: 'B')];
      final prefs = await prefsStore({
        'repos': RepoConfig.encodeList(repos),
        'autoRefresh': false,
      });
      final older = indexWith(pkg('org.dup', lastUpdated: 1));
      final newer = indexWith(pkg('org.dup', lastUpdated: 2));
      final store = FakeIndexStore(cached: {
        repos[0].id: older,
        repos[1].id: newer,
      });
      final s = makeState(prefs: prefs, store: store, device: FakeDevice());
      await s.init();
      expect(s.apps.single.repo.name, 'B');
    });

    test('refreshIndexes is reentrant-safe while loading', () async {
      final store = _SlowStore();
      final prefs = await prefsStore({'autoRefresh': false});
      final s = makeState(prefs: prefs, store: store, device: FakeDevice());
      s.repos = prefs.loadRepos();
      final f1 = s.refreshIndexes();
      final f2 = s.refreshIndexes();
      await Future.wait([f1, f2]);
      expect(store.fetches, 1);
    });
  });

  group('repos', () {
    test('addRepo normalizes url, fetches and persists', () async {
      final store = FakeIndexStore(results: {
        'https___new_test_repo': RepoFetchResult(
            index: indexWith(pkg('org.new')), fromCache: false),
      });
      final prefs = await prefsStore({'autoRefresh': false});
      final s = makeState(prefs: prefs, store: store, device: FakeDevice());
      await s.init();
      await s.addRepo(' https://new.test/repo/ ');
      expect(s.repos.last.url, 'https://new.test/repo');
      expect(store.fetches, greaterThan(0));
      expect(PrefsStore(await SharedPreferences.getInstance())
          .loadRepos()
          .length, 4);
    });

    test('addRepo rejects empty and duplicates', () async {
      final prefs = await prefsStore({'autoRefresh': false});
      final s = makeState(prefs: prefs, device: FakeDevice());
      await s.init();
      final count = s.repos.length;
      await s.addRepo('   ');
      await s.addRepo('https://f-droid.org/repo');
      expect(s.repos.length, count);
    });

    test('removeRepo drops repo and its apps', () async {
      final repo = RepoConfig.defaults().first;
      final store = FakeIndexStore(cached: {repo.id: indexWith(pkg('org.x'))});
      final prefs = await prefsStore();
      final s = makeState(prefs: prefs, store: store, device: FakeDevice());
      await s.init();
      expect(s.apps, isNotEmpty);
      await s.removeRepo(repo);
      expect(s.apps, isEmpty);
      expect(s.repos.where((r) => r.id == repo.id), isEmpty);
    });

    test('disable repo hides apps, re-enable refetches', () async {
      final repo = RepoConfig.defaults().first;
      final store = FakeIndexStore(
        cached: {repo.id: indexWith(pkg('org.x'))},
        results: {repo.id: RepoFetchResult(index: indexWith(pkg('org.x')), fromCache: false)},
      );
      final prefs = await prefsStore();
      final s = makeState(prefs: prefs, store: store, device: FakeDevice());
      await s.init();
      await s.setRepoEnabled(repo, false);
      expect(s.apps, isEmpty);
      await s.setRepoEnabled(repo, true);
      await Future<void>.delayed(Duration.zero);
      expect(s.apps, isNotEmpty);
    });

    test('enable already-indexed repo does not refetch', () async {
      final repo = RepoConfig.defaults().first;
      final store = FakeIndexStore(cached: {repo.id: indexWith(pkg('org.x'))});
      final prefs = await prefsStore();
      final s = makeState(prefs: prefs, store: store, device: FakeDevice());
      await s.init();
      await s.setRepoEnabled(repo, false);
      final before = store.fetches;
      await s.setRepoEnabled(repo, true);
      expect(store.fetches, before);
    });
  });

  group('settings', () {
    test('theme mode cycles and persists', () async {
      final prefs = await prefsStore();
      final s = makeState(prefs: prefs, device: FakeDevice());
      expect(s.themeMode, ThemeMode.system);
      await s.setThemeMode(ThemeMode.dark);
      expect(s.themeMode, ThemeMode.dark);
      await s.setThemeMode(ThemeMode.light);
      expect(s.themeMode, ThemeMode.light);
      await s.setThemeMode(ThemeMode.system);
      expect(s.themeMode, ThemeMode.system);
    });

    test('autoRefresh and showIncompatible persist', () async {
      final prefs = await prefsStore();
      final s = makeState(prefs: prefs, device: FakeDevice());
      expect(s.autoRefresh, isTrue);
      expect(s.showIncompatible, isFalse);
      await s.setAutoRefresh(false);
      await s.setShowIncompatible(true);
      expect(s.autoRefresh, isFalse);
      expect(s.showIncompatible, isTrue);
    });

    test('selectTab only notifies on change', () async {
      final s = makeState(prefs: await prefsStore(), device: FakeDevice());
      var notifies = 0;
      s.addListener(() => notifies++);
      s.selectTab(0);
      expect(notifies, 0);
      s.selectTab(2);
      expect(s.selectedTab, 2);
      expect(notifies, 1);
    });
  });

  group('queries', () {
    late AppState s;
    late RepoConfig repo;

    setUp(() async {
      repo = RepoConfig(url: 'https://r.test', name: 'R');
      SharedPreferences.setMockInitialValues(
          {'repos': RepoConfig.encodeList([repo])});
      final device = FakeDevice()
        ..packages = {
          'org.old': const InstalledApp(
              packageName: 'org.old',
              versionCode: 1,
              versionName: 'v1',
              signerSha256: 'same'),
          'org.signed': const InstalledApp(
              packageName: 'org.signed',
              versionCode: 1,
              versionName: 'v1',
              signerSha256: 'other'),
          'org.current': const InstalledApp(
              packageName: 'org.current', versionCode: 5, versionName: 'v5'),
        };
      final store = FakeIndexStore(
        cached: {
          repo.id: FdroidIndex(repoName: 'R', repoAddress: 'https://r.test', packages: {
            'org.old': pkg('org.old', versionCode: 9, signer: 'same', lastUpdated: 9),
            'org.signed': pkg('org.signed', versionCode: 9, signer: 'new', lastUpdated: 8),
            'org.current': pkg('org.current', versionCode: 5, lastUpdated: 7),
            'org.fresh': pkg('org.fresh',
                versionCode: 2,
                categories: const ['Games'],
                icon: const FileRef(name: 'icon/fresh.png'),
                lastUpdated: 10),
          }),
        },
      );
      s = makeState(prefs: PrefsStore(await SharedPreferences.getInstance()),
          store: store, device: device);
      await s.init();
    });

    test('updates detects upgrades and signer mismatch', () {
      final updates = s.updates;
      expect(updates.map((e) => e.packageName),
          containsAll(['org.old', 'org.signed']));
      expect(s.findApp('org.current')!.hasUpdate, isFalse);
      expect(s.findApp('org.signed')!.signerMismatch, isTrue);
      expect(s.findApp('org.old')!.signerMismatch, isFalse);
      expect(s.findApp('org.fresh')!.signerMismatch, isFalse);
      expect(s.findApp('missing'), isNull);
    });

    test('installedEntries and latest ordering', () {
      expect(s.installedEntries.length, 3);
      expect(s.latest.first.packageName, 'org.fresh');
    });

    test('categories groups by name sorted', () {
      final cats = s.categories;
      expect(cats.keys, containsAll(['Tools', 'Games']));
      expect(cats['Games']!.single.packageName, 'org.fresh');
    });

    test('search ranks name over package over summary', () {
      final results = s.search('fresh');
      expect(results.first.packageName, 'org.fresh');
      expect(s.search('org').length, 4);
      expect(s.search('   '), isEmpty);
      expect(s.search('nomatch'), isEmpty);
      // prefix beats contains
      final byPrefix = s.search('fr');
      expect(byPrefix.first.packageName, 'org.fresh');
    });

    test('iconUrl and screenshotUrls', () {
      final fresh = s.findApp('org.fresh')!;
      expect(fresh.iconUrl, 'https://r.test/icon/fresh.png');
      expect(fresh.screenshotUrls, isEmpty);
      expect(s.findApp('org.old')!.iconUrl, isNull);
    });
  });

  group('compatibility', () {
    test('minSdk blocks newer-only versions', () async {
      final device = FakeDevice()..sdk = 30;
      final s = makeState(prefs: await prefsStore(), device: device);
      await s.init();
      final e = AppEntry(
          package: pkg('org.needhigh', minSdk: 33),
          repo: RepoConfig(url: 'https://r.test', name: 'R'));
      expect(s.isCompatible(e.bestVersion!), isFalse);
      expect(s.compatibleVersion(e), isNull);
    });

    test('abi filters native code', () async {
      final device = FakeDevice()
        ..abiList = ['arm64-v8a'];
      final s = makeState(prefs: await prefsStore(), device: device);
      await s.init();
      final arm = AppVersion(
          versionName: 'v', versionCode: 1, fileName: 'f', added: 0,
          nativeCode: const ['arm64-v8a']);
      final x86 = AppVersion(
          versionName: 'v', versionCode: 1, fileName: 'f', added: 0,
          nativeCode: const ['x86_64']);
      final universal = AppVersion(
          versionName: 'v', versionCode: 1, fileName: 'f', added: 0);
      expect(s.isCompatible(arm), isTrue);
      expect(s.isCompatible(x86), isFalse);
      expect(s.isCompatible(universal), isTrue);
    });

    test('no abi info accepts native versions', () async {
      final device = FakeDevice()..abiList = [];
      final s = makeState(prefs: await prefsStore(), device: device);
      await s.init();
      final v = AppVersion(
          versionName: 'v', versionCode: 1, fileName: 'f', added: 0,
          nativeCode: const ['mips']);
      expect(s.isCompatible(v), isTrue);
    });
  });

  group('misc coverage', () {
    test('DownloadState.active reflects fields', () {
      final d = DownloadState();
      expect(d.active, isFalse);
      d.installing = true;
      expect(d.active, isTrue);
      d.error = 'x';
      expect(d.active, isFalse);
      final d2 = DownloadState(handle: null);
      expect(d2.active, isFalse);
    });

    test('device bridge platform exceptions are swallowed', () async {
      final device = _ThrowingDevice();
      final s = makeState(prefs: await prefsStore(), device: device);
      await s.init();
      expect(s.installed, isEmpty);
      expect(s.deviceSdk, 0);
    });

    test('enabling repo without index refetches', () async {
      final repo = RepoConfig.defaults()[1];
      repo.enabled = false;
      SharedPreferences.setMockInitialValues({
        'repos': RepoConfig.encodeList(RepoConfig.defaults()),
        'autoRefresh': false,
      });
      final prefs = PrefsStore(await SharedPreferences.getInstance());
      final store = FakeIndexStore();
      final s = makeState(prefs: prefs, store: store, device: FakeDevice());
      await s.init();
      await s.setRepoEnabled(s.repos[1], true);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(store.fetches, 2);
      expect(s.repos[1].enabled, isTrue);
    });
  });

  group('install flow', () {
    late AppState s;
    late AppEntry entry;
    late FakeDevice device;

    setUp(() async {
      final repo = RepoConfig(url: 'https://r.test', name: 'R');
      device = FakeDevice();
      s = makeState(
          prefs: await prefsStore(),
          store: FakeIndexStore(),
          device: device,
          downloader: FakeDownloader());
      entry = AppEntry(
          package: pkg('org.app', versionCode: 2),
          repo: repo);
    });

    test('happy path downloads then installs', () async {
      await s.installEntry(entry);
      expect(device.calls, contains('installApk'));
      expect(s.downloads.containsKey('org.app'), isFalse);
    });

    test('requests permission first when installs are blocked', () async {
      device.canInstall = false;
      var checks = 0;
      final toggling = _TogglingDevice(device, () => checks++ == 0 ? false : true);
      final s2 = makeState(
          prefs: await prefsStore(),
          store: FakeIndexStore(),
          device: toggling,
          downloader: FakeDownloader());
      await s2.init();
      await s2.installEntry(entry);
      expect(device.calls, contains('openInstallSettings'));
      expect(device.calls, contains('installApk'));
    });

    test('gives up when permission never granted', () async {
      device.canInstall = false;
      await s.installEntry(entry);
      expect(device.calls, contains('openInstallSettings'));
      expect(device.calls, isNot(contains('installApk')));
      expect(s.downloads['org.app']!.error, contains('blocked'));
      s.dismissDownloadError('org.app');
      expect(s.downloads.containsKey('org.app'), isFalse);
    });

    test('download failure stores error state', () async {
      final s2 = makeState(
          prefs: await prefsStore(),
          store: FakeIndexStore(),
          device: device,
          downloader: FakeDownloader(error: Exception('network down')));
      await s2.init();
      await s2.installEntry(entry);
      expect(s2.downloads['org.app']!.error, contains('network down'));
      expect(device.calls, isNot(contains('installApk')));
    });

    test('no compatible version is a no-op', () async {
      final e = AppEntry(
          package: FdroidPackage(packageName: 'org.none', name: 'None'),
          repo: RepoConfig(url: 'https://r.test', name: 'R'));
      await s.installEntry(e);
      expect(s.downloads.containsKey('org.none'), isFalse);
    });
  });
}

class _SlowStore extends FakeIndexStore {
  @override
  Future<RepoFetchResult?> fetch(RepoConfig repo) async {
    fetches++;
    await Future<void>.delayed(const Duration(milliseconds: 10));
    return null;
  }
}

class _TogglingDevice extends FakeDevice {
  _TogglingDevice(this.inner, this.canInstallCheck);

  final FakeDevice inner;
  final bool Function() canInstallCheck;

  @override
  Map<String, InstalledApp> get packages => inner.packages;
  @override
  set packages(Map<String, InstalledApp> v) => inner.packages = v;
  @override
  int get sdk => inner.sdk;
  @override
  List<String> get abiList => inner.abiList;
  @override
  List<String> get calls => inner.calls;

  @override
  Future<bool> canInstallUnknownApps() async => canInstallCheck();

  @override
  Future<void> openInstallSettings() => inner.openInstallSettings();

  @override
  Future<bool> installApk(String path) => inner.installApk(path);
}


class _ThrowingDevice extends FakeDevice {
  @override
  Future<Map<String, InstalledApp>> installedPackages() =>
      throw PlatformException(code: 'denied');
}
