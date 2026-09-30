import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'models/index_models.dart';
import 'models/repo_config.dart';
import 'services/apk_download.dart';
import 'services/device_bridge.dart';
import 'services/index_store.dart';
import 'services/prefs_store.dart';

class AppEntry {
  AppEntry({required this.package, required this.repo});

  final FdroidPackage package;
  final RepoConfig repo;
  InstalledApp? installed;

  String get packageName => package.packageName;

  AppVersion? get bestVersion => package.bestVersion;

  String? get iconUrl =>
      package.icon != null ? repo.fileUrl(package.icon!.name) : null;

  List<String> get screenshotUrls =>
      package.screenshots.map((s) => repo.fileUrl(s.name)).toList();

  bool get hasUpdate {
    final installed = this.installed;
    final best = bestVersion;
    if (installed == null || best == null) return false;
    return best.versionCode > installed.versionCode;
  }

  bool get signerMismatch {
    final installed = this.installed;
    final best = bestVersion;
    if (installed == null || best == null) return false;
    final i = installed.signerSha256;
    final v = best.signerSha256;
    return i != null && v != null && i != v;
  }
}

enum IndexStatus { idle, loading, ready, error }

class DownloadState {
  DownloadState({this.progress = const DownloadProgress(received: 0), this.installing = false, this.error, this.handle});

  DownloadProgress progress;
  bool installing;
  String? error;
  DownloadHandle? handle;

  bool get active => error == null && (handle != null || installing);
}

class AppState extends ChangeNotifier {
  AppState({
    required this.prefs,
    IndexStore? indexStore,
    DeviceBridge? device,
    ApkDownloader? downloader,
    Directory? cacheDir,
  })  : _providedStore = indexStore,
        _providedCacheDir = cacheDir,
        device = device ?? DeviceBridge(),
        downloader = downloader ?? ApkDownloader();

  final PrefsStore prefs;
  final IndexStore? _providedStore;
  final Directory? _providedCacheDir;
  final DeviceBridge device;
  final ApkDownloader downloader;

  IndexStore? _store;

  List<RepoConfig> repos = [];
  final Map<String, FdroidIndex> indexes = {};
  final Map<String, InstalledApp> installed = {};
  final Map<String, DownloadState> downloads = {};

  List<AppEntry> apps = [];
  IndexStatus status = IndexStatus.idle;
  String? error;
  int deviceSdk = 0;
  List<String> deviceAbis = const [];
  int selectedTab = 0;

  ThemeMode get themeMode => switch (prefs.loadThemeMode()) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  bool get autoRefresh => prefs.loadAutoRefresh();
  bool get showIncompatible => prefs.loadShowIncompatible();
  bool get isLoading => status == IndexStatus.loading;

  Future<void> init() async {
    repos = prefs.loadRepos();
    await _resolveStore();
    await _loadDeviceInfo();
    await _loadCachedIndexes();
    _rebuildApps();
    if (autoRefresh) {
      unawaited(refreshIndexes());
    }
  }

  Future<void> _resolveStore() async {
    _store ??= _providedStore ??
        IndexStore(
            cacheDir: _providedCacheDir ??
                await getApplicationSupportDirectory());
  }

  Future<void> _loadDeviceInfo() async {
    try {
      installed
        ..clear()
        ..addAll(await device.installedPackages());
      deviceSdk = await device.sdkInt();
      deviceAbis = await device.abis();
    } on MissingPluginException {
      // Not on Android (tests, previews).
    } on PlatformException {
      // Device query failed; keep empty state.
    }
  }

  Future<void> _loadCachedIndexes() async {
    for (final repo in repos.where((r) => r.enabled)) {
      final cached = await _store!.loadCached(repo);
      if (cached != null) indexes[repo.id] = cached;
    }
  }

  void _rebuildApps() {
    final merged = <String, AppEntry>{};
    for (final repo in repos.where((r) => r.enabled)) {
      final index = indexes[repo.id];
      if (index == null) continue;
      for (final pkg in index.packages.values) {
        final existing = merged[pkg.packageName];
        if (existing == null || pkg.lastUpdated > existing.package.lastUpdated) {
          merged[pkg.packageName] = AppEntry(package: pkg, repo: repo);
        }
      }
    }
    final list = merged.values.toList();
    for (final e in list) {
      e.installed = installed[e.packageName];
    }
    list.sort((a, b) => b.package.lastUpdated.compareTo(a.package.lastUpdated));
    apps = list;
    notifyListeners();
  }

  Future<void> refreshInstalled() => _loadDeviceInfo().then((_) {
        _rebuildApps();
      });

  Future<void> refreshIndexes({bool force = true}) async {
    if (status == IndexStatus.loading) return;
    status = IndexStatus.loading;
    error = null;
    notifyListeners();
    await _resolveStore();
    final failures = <String>[];
    for (final repo in repos.where((r) => r.enabled)) {
      try {
        final result = await _store!.fetch(repo);
        if (result != null) indexes[repo.id] = result.index;
      } on Object catch (e) {
        failures.add('${repo.name}: $e');
      }
    }
    status = IndexStatus.ready;
    if (indexes.isEmpty && failures.isNotEmpty) {
      status = IndexStatus.error;
      error = failures.first;
    } else if (failures.isNotEmpty) {
      error = failures.first;
    }
    _rebuildApps();
  }

  Future<void> addRepo(String url) async {
    final normalized = url.trim().replaceAll(RegExp(r'/+$'), '');
    if (normalized.isEmpty || repos.any((r) => r.baseUrl == normalized)) {
      return;
    }
    repos.add(RepoConfig(url: normalized, name: normalized));
    await prefs.saveRepos(repos);
    notifyListeners();
    await refreshIndexes();
  }

  Future<void> removeRepo(RepoConfig repo) async {
    repos.removeWhere((r) => r.id == repo.id);
    indexes.remove(repo.id);
    await prefs.saveRepos(repos);
    _rebuildApps();
  }

  Future<void> setRepoEnabled(RepoConfig repo, bool enabled) async {
    final target =
        repos.firstWhere((r) => r.id == repo.id, orElse: () => repo);
    target.enabled = enabled;
    await prefs.saveRepos(repos);
    if (enabled && !indexes.containsKey(repo.id)) {
      await refreshIndexes();
    } else {
      _rebuildApps();
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await prefs.saveThemeMode(switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    });
    notifyListeners();
  }

  Future<void> setAutoRefresh(bool value) async {
    await prefs.saveAutoRefresh(value);
    notifyListeners();
  }

  Future<void> setShowIncompatible(bool value) async {
    await prefs.saveShowIncompatible(value);
    notifyListeners();
  }

  void selectTab(int index) {
    if (selectedTab == index) return;
    selectedTab = index;
    notifyListeners();
  }

  AppEntry? findApp(String packageName) {
    for (final e in apps) {
      if (e.packageName == packageName) return e;
    }
    return null;
  }

  List<AppEntry> get latest => List.unmodifiable(apps);

  List<AppEntry> get updates =>
      apps.where((e) => e.hasUpdate).toList(growable: false);

  List<AppEntry> get installedEntries =>
      apps.where((e) => e.installed != null).toList(growable: false);

  Map<String, List<AppEntry>> get categories {
    final map = <String, List<AppEntry>>{};
    for (final e in apps) {
      for (final c in e.package.categories) {
        map.putIfAbsent(c, () => []).add(e);
      }
    }
    for (final list in map.values) {
      list.sort((a, b) => a.package.name
          .toLowerCase()
          .compareTo(b.package.name.toLowerCase()));
    }
    return Map.fromEntries(
        map.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
  }

  List<AppEntry> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final scored = <(int, AppEntry)>[];
    for (final e in apps) {
      final name = e.package.name.toLowerCase();
      final pkg = e.packageName.toLowerCase();
      final summary = e.package.summary.toLowerCase();
      final score = name.startsWith(q)
          ? 0
          : name.contains(q)
              ? 1
              : pkg.contains(q)
                  ? 2
                  : summary.contains(q)
                      ? 3
                      : -1;
      if (score >= 0) scored.add((score, e));
    }
    scored.sort((a, b) {
      final c = a.$1.compareTo(b.$1);
      if (c != 0) return c;
      return a.$2.package.name
          .toLowerCase()
          .compareTo(b.$2.package.name.toLowerCase());
    });
    return scored.map((s) => s.$2).toList(growable: false);
  }

  bool isCompatible(AppVersion v) {
    if (v.minSdk != null && deviceSdk > 0 && v.minSdk! > deviceSdk) {
      return false;
    }
    if (v.nativeCode.isNotEmpty && deviceAbis.isNotEmpty) {
      return v.nativeCode.any(deviceAbis.contains);
    }
    return true;
  }

  AppVersion? compatibleVersion(AppEntry e) {
    for (final v in e.package.versions) {
      if (isCompatible(v)) return v;
    }
    return null;
  }

  Future<void> installEntry(AppEntry entry) async {
    final version = compatibleVersion(entry) ?? entry.bestVersion;
    if (version == null) return;
    final state = downloads[entry.packageName] = DownloadState();
    notifyListeners();
    try {
      if (!await device.canInstallUnknownApps()) {
        await device.openInstallSettings();
        if (!await device.canInstallUnknownApps()) {
          throw const _InstallBlocked();
        }
      }
      final dir = await getTemporaryDirectory();
      final dest =
          File('${dir.path}/apks/${entry.packageName}-${version.versionCode}.apk');
      final handle = downloader.start(
        Uri.parse(entry.repo.fileUrl(version.fileName)),
        dest,
        expectedSha256: version.sha256,
      );
      state.handle = handle;
      handle.progress.listen((p) {
        state.progress = p;
        notifyListeners();
      });
      await handle.result;
      state
        ..handle = null
        ..installing = true;
      notifyListeners();
      await device.installApk(dest.path);
      state.installing = false;
      downloads.remove(entry.packageName);
      unawaited(refreshInstalled());
    } on Object catch (e) {
      state
        ..handle = null
        ..installing = false
        ..error = e is _InstallBlocked
            ? 'Installation blocked: allow unknown apps first'
            : e.toString();
      notifyListeners();
    }
  }

  void dismissDownloadError(String packageName) {
    downloads.remove(packageName);
    notifyListeners();
  }
}

class _InstallBlocked implements Exception {
  const _InstallBlocked();
}
