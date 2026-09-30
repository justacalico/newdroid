import 'package:flutter_test/flutter_test.dart';
import 'package:newdroid/models/repo_config.dart';
import 'package:newdroid/services/prefs_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PrefsStore', () {
    test('defaults when empty', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = PrefsStore(await SharedPreferences.getInstance());
      expect(prefs.loadRepos().map((r) => r.name), contains('F-Droid'));
      expect(prefs.loadThemeMode(), 'system');
      expect(prefs.loadAutoRefresh(), isTrue);
      expect(prefs.loadShowIncompatible(), isFalse);
    });

    test('bad repos json falls back to defaults', () async {
      SharedPreferences.setMockInitialValues({'repos': '{broken'});
      final prefs = PrefsStore(await SharedPreferences.getInstance());
      expect(prefs.loadRepos().first.name, 'F-Droid');
    });

    test('round trips all settings', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = PrefsStore(await SharedPreferences.getInstance());
      final repos = RepoConfig.defaults();
      repos[1].enabled = true;
      await prefs.saveRepos(repos);
      await prefs.saveThemeMode('dark');
      await prefs.saveAutoRefresh(false);
      await prefs.saveShowIncompatible(true);

      final again = PrefsStore(await SharedPreferences.getInstance());
      expect(again.loadRepos()[1].enabled, isTrue);
      expect(again.loadThemeMode(), 'dark');
      expect(again.loadAutoRefresh(), isFalse);
      expect(again.loadShowIncompatible(), isTrue);
    });
  });
}
