import 'dart:convert';

class FileRef {
  const FileRef({required this.name, this.sha256, this.size});

  final String name;
  final String? sha256;
  final int? size;

  static FileRef? fromJson(dynamic json) {
    if (json is! Map<String, dynamic>) return null;
    final name = json['name'];
    if (name is! String || name.isEmpty) return null;
    return FileRef(
      name: name,
      sha256: json['sha256'] as String?,
      size: (json['size'] as num?)?.toInt(),
    );
  }
}

String pickLocalized(dynamic localized, [String locale = 'en-US']) {
  if (localized is String) return localized;
  if (localized is Map) {
    final en = localized[locale];
    if (en is String && en.isNotEmpty) return en;
    for (final v in localized.values) {
      if (v is String && v.isNotEmpty) return v;
    }
  }
  return '';
}

List<String> localizedKeys(dynamic localized) {
  if (localized is Map) return localized.keys.cast<String>().toList();
  return const [];
}

class AppVersion {
  const AppVersion({
    required this.versionName,
    required this.versionCode,
    required this.fileName,
    required this.added,
    this.sha256,
    this.size = 0,
    this.minSdk,
    this.targetSdk,
    this.signerSha256,
    this.permissions = const [],
    this.nativeCode = const [],
    this.antiFeatures = const [],
    this.whatsNew = '',
  });

  final String versionName;
  final int versionCode;
  final String fileName;
  final int added;
  final String? sha256;
  final int size;
  final int? minSdk;
  final int? targetSdk;
  final String? signerSha256;
  final List<String> permissions;
  final List<String> nativeCode;
  final List<String> antiFeatures;
  final String whatsNew;
}

class FdroidPackage {
  FdroidPackage({
    required this.packageName,
    required this.name,
    this.summary = '',
    this.description = '',
    this.categories = const [],
    this.license,
    this.authorName,
    this.webSite,
    this.sourceCode,
    this.issueTracker,
    this.changelog,
    this.donate,
    this.added = 0,
    this.lastUpdated = 0,
    this.icon,
    this.screenshots = const [],
    this.versions = const [],
    this.antiFeatures = const {},
    this.suggestedVersionCode,
  });

  final String packageName;
  final String name;
  final String summary;
  final String description;
  final List<String> categories;
  final String? license;
  final String? authorName;
  final String? webSite;
  final String? sourceCode;
  final String? issueTracker;
  final String? changelog;
  final String? donate;
  final int added;
  final int lastUpdated;
  final FileRef? icon;
  final List<FileRef> screenshots;
  final List<AppVersion> versions;
  final Map<String, String> antiFeatures;
  final int? suggestedVersionCode;

  AppVersion? get bestVersion {
    if (versions.isEmpty) return null;
    final target = suggestedVersionCode;
    if (target != null) {
      for (final v in versions) {
        if (v.versionCode == target) return v;
      }
    }
    return versions.first;
  }
}

class FdroidIndex {
  FdroidIndex({
    required this.repoName,
    required this.repoAddress,
    required this.packages,
  });

  final String repoName;
  final String repoAddress;
  final Map<String, FdroidPackage> packages;
}

List<String> _permissionNames(dynamic list) {
  if (list is! List) return const [];
  final names = <String>[];
  for (final p in list) {
    if (p is Map && p['name'] is String) {
      names.add(p['name'] as String);
    } else if (p is String) {
      names.add(p);
    }
  }
  return names;
}

List<String> _stringList(dynamic list) {
  if (list is! List) return const [];
  return list.whereType<String>().toList();
}

Map<String, String> _antiFeatures(dynamic json) {
  if (json is! Map) return const {};
  final out = <String, String>{};
  for (final e in json.entries) {
    final desc = pickLocalized(e.value);
    out[e.key as String] = desc.isEmpty ? (e.key as String) : desc;
  }
  return out;
}

AppVersion _versionV2(dynamic json) {
  final v = json as Map<String, dynamic>;
  final manifest = v['manifest'] as Map<String, dynamic>? ?? const {};
  final file = v['file'] as Map<String, dynamic>? ?? const {};
  final usesSdk = manifest['usesSdk'] as Map<String, dynamic>? ?? const {};
  final signer = manifest['signer'] as Map<String, dynamic>? ?? const {};
  final signers = signer['sha256'];
  final perms = <String>[
    ..._permissionNames(manifest['uses-permission']),
    ..._permissionNames(manifest['uses-permission-sdk-23']),
  ];
  return AppVersion(
    versionName: manifest['versionName'] as String? ?? '',
    versionCode: (manifest['versionCode'] as num?)?.toInt() ?? 0,
    fileName: file['name'] as String? ?? '',
    added: (v['added'] as num?)?.toInt() ?? 0,
    sha256: file['sha256'] as String?,
    size: (file['size'] as num?)?.toInt() ?? 0,
    minSdk: (usesSdk['minSdkVersion'] as num?)?.toInt(),
    targetSdk: (usesSdk['targetSdkVersion'] as num?)?.toInt(),
    signerSha256: signers is List && signers.isNotEmpty
        ? (signers.first as String).toLowerCase()
        : null,
    permissions: perms,
    nativeCode: _stringList(manifest['nativecode']),
    antiFeatures: _antiFeatures(v['antiFeatures']).keys.toList(),
    whatsNew: pickLocalized(v['whatsNew']),
  );
}

List<FileRef> _screenshotsV2(dynamic json) {
  if (json is! Map) return const [];
  final refs = <FileRef>[];
  const order = ['phone', 'sevenInch', 'tenInch', 'tv', 'wear'];
  for (final kind in order) {
    final byLocale = json[kind];
    if (byLocale is! Map) continue;
    final en = byLocale['en-US'];
    final list = en is List ? en : byLocale.values.whereType<List>().firstOrNull;
    if (list is List) {
      for (final s in list) {
        final ref = FileRef.fromJson(s);
        if (ref != null) refs.add(ref);
      }
      if (refs.isNotEmpty) return refs;
    }
  }
  return refs;
}

FdroidIndex _parseV2(Map<String, dynamic> root) {
  final repo = root['repo'] as Map<String, dynamic>? ?? const {};
  final packages = <String, FdroidPackage>{};
  final rawPackages = root['packages'] as Map<String, dynamic>? ?? const {};
  for (final entry in rawPackages.entries) {
    final pkg = entry.value as Map<String, dynamic>;
    final meta = pkg['metadata'] as Map<String, dynamic>? ?? const {};
    final versions = <AppVersion>[];
    final rawVersions = pkg['versions'];
    if (rawVersions is Map) {
      for (final v in rawVersions.values) {
        final parsed = _versionV2(v);
        if (parsed.versionCode > 0 && parsed.fileName.isNotEmpty) {
          versions.add(parsed);
        }
      }
    }
    versions.sort((a, b) => b.versionCode.compareTo(a.versionCode));
    final name = pickLocalized(meta['name']);
    packages[entry.key] = FdroidPackage(
      packageName: entry.key,
      name: name.isEmpty ? entry.key : name,
      summary: pickLocalized(meta['summary']),
      description: pickLocalized(meta['description']),
      categories: _stringList(meta['categories']),
      license: meta['license'] as String?,
      authorName: meta['authorName'] as String?,
      webSite: meta['webSite'] as String?,
      sourceCode: meta['sourceCode'] as String?,
      issueTracker: meta['issueTracker'] as String?,
      changelog: meta['changelog'] as String?,
      donate: meta['donate'] as String?,
      added: (meta['added'] as num?)?.toInt() ?? 0,
      lastUpdated: (meta['lastUpdated'] as num?)?.toInt() ?? 0,
      icon: FileRef.fromJson((meta['icon'] as Map?)?['en-US'] ??
          (meta['icon'] as Map?)?.values.firstOrNull),
      screenshots: _screenshotsV2(meta['screenshots']),
      versions: versions,
      antiFeatures: _antiFeatures(meta['antiFeatures']),
      suggestedVersionCode:
          int.tryParse('${meta['suggestedVersionCode'] ?? ''}'),
    );
  }
  return FdroidIndex(
    repoName: pickLocalized(repo['name']).isEmpty
        ? 'Repository'
        : pickLocalized(repo['name']),
    repoAddress: repo['address'] as String? ?? '',
    packages: packages,
  );
}

FdroidIndex _parseV1(Map<String, dynamic> root) {
  final packages = <String, FdroidPackage>{};
  final apps = root['apps'];
  final metaById = <String, Map<String, dynamic>>{};
  if (apps is List) {
    for (final a in apps) {
      final m = a as Map<String, dynamic>;
      final id = m['packageName'] as String? ?? m['id'] as String? ?? '';
      if (id.isNotEmpty) metaById[id] = m;
    }
  }
  final rawPackages = root['packages'] as Map<String, dynamic>? ?? const {};
  for (final entry in rawPackages.entries) {
    final meta = metaById[entry.key] ?? const <String, dynamic>{};
    final versions = <AppVersion>[];
    if (entry.value is List) {
      for (final v in entry.value as List) {
        final m = v as Map<String, dynamic>;
        versions.add(AppVersion(
          versionName: m['versionName'] as String? ?? '',
          versionCode: (m['versionCode'] as num?)?.toInt() ?? 0,
          fileName: m['apkName'] as String? ?? '',
          added: (m['added'] as num?)?.toInt() ?? 0,
          sha256: m['hash'] as String?,
          size: (m['size'] as num?)?.toInt() ?? 0,
          minSdk: int.tryParse('${m['minSdkVersion'] ?? ''}'),
          targetSdk: int.tryParse('${m['targetSdkVersion'] ?? ''}'),
          signerSha256: (m['sig'] as String? ?? m['signer'] as String?)
              ?.toLowerCase(),
          permissions: _stringList(m['uses-permission'] is List
              ? (m['uses-permission'] as List)
                  .map((p) => p is Map ? p['name'] : p)
                  .whereType<String>()
                  .toList()
              : m['uses-permission']),
          nativeCode: _stringList(m['nativecode']),
        ));
      }
    }
    versions.sort((a, b) => b.versionCode.compareTo(a.versionCode));
    final name = meta['name'] as String? ?? '';
    packages[entry.key] = FdroidPackage(
      packageName: entry.key,
      name: name.isEmpty ? entry.key : name,
      summary: meta['summary'] as String? ?? '',
      description: meta['description'] as String? ?? '',
      categories: _stringList(meta['categories']),
      license: meta['license'] as String?,
      authorName: meta['author'] as String? ?? meta['authorName'] as String?,
      webSite: meta['webSite'] as String?,
      sourceCode: meta['sourceCode'] as String?,
      issueTracker: meta['issueTracker'] as String?,
      changelog: meta['changelog'] as String?,
      donate: meta['donate'] as String?,
      added: (meta['added'] as num?)?.toInt() ?? 0,
      lastUpdated: (meta['lastUpdated'] as num?)?.toInt() ?? 0,
      icon: meta['icon'] is String
          ? FileRef(name: 'icons/${meta['icon']}')
          : null,
      versions: versions,
      suggestedVersionCode:
          int.tryParse('${meta['suggestedVersionCode'] ?? ''}'),
    );
  }
  return FdroidIndex(
    repoName: 'Repository',
    repoAddress: '',
    packages: packages,
  );
}

FdroidIndex parseIndexJson(String body) {
  final root = jsonDecode(body) as Map<String, dynamic>;
  final packages = root['packages'];
  if (root['repo'] is Map && packages is Map) {
    final first = packages.values.isEmpty ? null : packages.values.first;
    if (first is Map && first.containsKey('metadata')) {
      return _parseV2(root);
    }
  }
  return _parseV1(root);
}
