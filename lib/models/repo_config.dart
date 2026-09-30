import 'dart:convert';

class RepoConfig {
  RepoConfig({
    required this.url,
    required this.name,
    this.enabled = true,
    this.builtIn = false,
  });

  final String url;
  String name;
  bool enabled;
  final bool builtIn;

  String get id => url.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');

  String get baseUrl => url.endsWith('/') ? url.substring(0, url.length - 1) : url;

  String fileUrl(String name) =>
      name.startsWith('/') ? '$baseUrl$name' : '$baseUrl/$name';

  Map<String, dynamic> toJson() => {
        'url': url,
        'name': name,
        'enabled': enabled,
        'builtIn': builtIn,
      };

  static RepoConfig fromJson(Map<String, dynamic> json) => RepoConfig(
        url: json['url'] as String,
        name: json['name'] as String? ?? json['url'] as String,
        enabled: json['enabled'] as bool? ?? true,
        builtIn: json['builtIn'] as bool? ?? false,
      );

  static List<RepoConfig> decodeList(String raw) {
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => RepoConfig.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static String encodeList(List<RepoConfig> repos) =>
      jsonEncode(repos.map((r) => r.toJson()).toList());

  static List<RepoConfig> defaults() => [
        RepoConfig(
          url: 'https://f-droid.org/repo',
          name: 'F-Droid',
          enabled: true,
          builtIn: true,
        ),
        RepoConfig(
          url: 'https://apt.izzysoft.de/fdroid/repo',
          name: 'IzzyOnDroid',
          enabled: false,
          builtIn: true,
        ),
        RepoConfig(
          url: 'https://guardianproject.info/fdroid/repo',
          name: 'Guardian Project',
          enabled: false,
          builtIn: true,
        ),
      ];
}
