import 'dart:async';
import 'dart:io';

import 'package:newdroid/app_state.dart';
import 'package:newdroid/models/index_models.dart';
import 'package:newdroid/models/repo_config.dart';
import 'package:newdroid/services/apk_download.dart';
import 'package:newdroid/services/device_bridge.dart';
import 'package:newdroid/services/index_store.dart';
import 'package:newdroid/services/prefs_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeIndexStore extends IndexStore {
  FakeIndexStore({this.results = const {}, this.cached = const {}, this.throwOn = const {}})
      : super(cacheDir: Directory.systemTemp);

  final Map<String, RepoFetchResult> results;
  final Map<String, FdroidIndex> cached;
  final Set<String> throwOn;
  int fetches = 0;

  @override
  Future<RepoFetchResult?> fetch(RepoConfig repo) async {
    fetches++;
    if (throwOn.contains(repo.id)) throw Exception('boom');
    return results[repo.id];
  }

  @override
  Future<FdroidIndex?> loadCached(RepoConfig repo) async => cached[repo.id];
}

class FakeDevice extends DeviceBridge {
  Map<String, InstalledApp> packages = {};
  int sdk = 34;
  List<String> abiList = ['arm64-v8a'];
  bool canInstall = true;
  bool installResult = true;
  final List<String> calls = [];

  @override
  Future<Map<String, InstalledApp>> installedPackages() async => packages;

  @override
  Future<int> sdkInt() async => sdk;

  @override
  Future<List<String>> abis() async => abiList;

  @override
  Future<bool> canInstallUnknownApps() async => canInstall;

  @override
  Future<void> openInstallSettings() async => calls.add('openInstallSettings');

  @override
  Future<bool> installApk(String path) async {
    calls.add('installApk');
    return installResult;
  }

  @override
  Future<bool> openApp(String packageName) async {
    calls.add('open:$packageName');
    return true;
  }

  @override
  Future<bool> uninstallApp(String packageName) async {
    calls.add('uninstall:$packageName');
    return true;
  }
}

class FakeDownloader extends ApkDownloader {
  FakeDownloader({this.error, this.hang = false});

  final Object? error;
  final bool hang;

  @override
  DownloadHandle start(Uri uri, File destination, {String? expectedSha256}) {
    final progress = StreamController<DownloadProgress>();
    final result = (() async {
      progress.add(const DownloadProgress(received: 50, total: 100));
      if (hang) {
        await Completer<File>().future;
      }
      if (error != null) throw error!;
      progress.add(const DownloadProgress(received: 100, total: 100));
      return destination;
    })();
    return DownloadHandle(progress: progress.stream, result: result);
  }
}

FdroidIndex indexWith(FdroidPackage pkg) => FdroidIndex(
      repoName: 'Test Repo',
      repoAddress: 'https://repo.test',
      packages: {pkg.packageName: pkg},
    );

FdroidPackage pkg(
  String name, {
  int versionCode = 1,
  String? signer,
  int minSdk = 21,
  List<String> nativeCode = const [],
  int lastUpdated = 1000,
  List<String> categories = const ['Tools'],
  FileRef? icon,
  String summary = '',
  String description = '',
  String? license,
  String? author,
  String? webSite,
  String? sourceCode,
  String? issueTracker,
  String? changelog,
  String? donate,
  List<FileRef> screenshots = const [],
  Map<String, String> antiFeatures = const {},
  String whatsNew = '',
  List<AppVersion>? extraVersions,
}) =>
    FdroidPackage(
      packageName: name,
      name: name.split('.').last,
      summary: summary.isEmpty ? 'summary of $name' : summary,
      description: description,
      categories: categories,
      license: license,
      authorName: author,
      webSite: webSite,
      sourceCode: sourceCode,
      issueTracker: issueTracker,
      changelog: changelog,
      donate: donate,
      icon: icon,
      screenshots: screenshots,
      antiFeatures: antiFeatures,
      lastUpdated: lastUpdated,
      versions: [
        AppVersion(
          versionName: 'v$versionCode',
          versionCode: versionCode,
          fileName: '/$name.apk',
          added: 1700000000000,
          sha256: 'abc',
          size: 1500000,
          minSdk: minSdk,
          signerSha256: signer,
          nativeCode: nativeCode,
          whatsNew: whatsNew,
        ),
        ...?extraVersions,
      ]..sort((a, b) => b.versionCode.compareTo(a.versionCode)),
    );

Future<PrefsStore> prefsStore([Map<String, Object> values = const {}]) async {
  SharedPreferences.setMockInitialValues(values);
  return PrefsStore(await SharedPreferences.getInstance());
}

AppState makeState({
  required PrefsStore prefs,
  IndexStore? store,
  DeviceBridge? device,
  ApkDownloader? downloader,
}) =>
    AppState(
      prefs: prefs,
      indexStore: store ?? FakeIndexStore(),
      device: device ?? FakeDevice(),
      downloader: downloader ?? FakeDownloader(),
      cacheDir: Directory.systemTemp,
    );

/// Builds a ready-to-pump AppState with a single test repo and the given
/// packages/installed apps already merged into [AppState.apps].
Future<AppState> seededState({
  List<FdroidPackage> packages = const [],
  Map<String, InstalledApp> installed = const {},
  List<RepoConfig>? repos,
  FakeDevice? device,
  ApkDownloader? downloader,
  bool autoRefresh = false,
}) async {
  final repoList =
      repos ?? [RepoConfig(url: 'https://repo.test', name: 'Test Repo')];
  final prefs = await prefsStore({
    'repos': RepoConfig.encodeList(repoList),
    'autoRefresh': autoRefresh,
  });
  final store = FakeIndexStore(cached: {
    repoList.first.id: FdroidIndex(
      repoName: repoList.first.name,
      repoAddress: repoList.first.url,
      packages: {for (final p in packages) p.packageName: p},
    ),
  });
  final d = device ?? FakeDevice()..packages = installed;
  final state = makeState(
      prefs: prefs, store: store, device: d, downloader: downloader);
  await state.init();
  return state;
}
