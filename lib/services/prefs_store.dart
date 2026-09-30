import 'package:shared_preferences/shared_preferences.dart';

import '../models/repo_config.dart';

class PrefsStore {
  static const reposKey = 'repos';
  static const themeModeKey = 'themeMode';
  static const autoRefreshKey = 'autoRefresh';
  static const showIncompatibleKey = 'showIncompatible';

  final SharedPreferences prefs;

  PrefsStore(this.prefs);

  List<RepoConfig> loadRepos() {
    final raw = prefs.getString(reposKey);
    if (raw == null) return RepoConfig.defaults();
    try {
      return RepoConfig.decodeList(raw);
    } on Object {
      return RepoConfig.defaults();
    }
  }

  Future<void> saveRepos(List<RepoConfig> repos) =>
      prefs.setString(reposKey, RepoConfig.encodeList(repos));

  String loadThemeMode() => prefs.getString(themeModeKey) ?? 'system';

  Future<void> saveThemeMode(String mode) =>
      prefs.setString(themeModeKey, mode);

  bool loadAutoRefresh() => prefs.getBool(autoRefreshKey) ?? true;

  Future<void> saveAutoRefresh(bool value) =>
      prefs.setBool(autoRefreshKey, value);

  bool loadShowIncompatible() => prefs.getBool(showIncompatibleKey) ?? false;

  Future<void> saveShowIncompatible(bool value) =>
      prefs.setBool(showIncompatibleKey, value);
}
