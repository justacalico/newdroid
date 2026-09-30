import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:newdroid/app_state.dart';
import 'package:newdroid/models/index_models.dart';
import 'package:newdroid/models/repo_config.dart';
import 'package:newdroid/services/device_bridge.dart';
import 'package:newdroid/theme.dart';
import 'package:newdroid/ui/app_shell.dart';
import 'package:newdroid/ui/pages/app_details_page.dart';
import 'package:newdroid/ui/pages/categories_page.dart';
import 'package:newdroid/ui/pages/latest_page.dart';
import 'package:newdroid/ui/pages/repos_page.dart';
import 'package:newdroid/ui/pages/search_page.dart';
import 'package:newdroid/ui/pages/settings_page.dart';
import 'package:newdroid/ui/pages/updates_page.dart';
import 'package:newdroid/ui/widgets/app_icon.dart';
import 'package:newdroid/ui/widgets/app_tile.dart';
import 'package:newdroid/ui/widgets/download_button.dart';
import 'package:newdroid/ui/widgets/empty_state.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:provider/provider.dart';

import 'helpers.dart';

void mockExtras() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (call) async => Directory.systemTemp.path,
  );
  messenger.setMockMethodCallHandler(
    const MethodChannel('dev.fluttercommunity.plus/package_info'),
    (call) async => {
      'appName': 'NewDroid',
      'packageName': 'com.httpanimations.newdroid',
      'version': '0.1.0',
      'buildNumber': '1',
    },
  );
  for (final name in const [
    'plugins.flutter.io/url_launcher',
    'plugins.flutter.io/url_launcher_android',
  ]) {
    messenger.setMockMethodCallHandler(
        MethodChannel(name), (call) async => true);
  }
}

Widget appFor(AppState state, {Widget? home, ThemeData? theme}) {
  return ChangeNotifierProvider<AppState>.value(
    value: state,
    child: MaterialApp(
      theme: theme ?? ndLightTheme(),
      darkTheme: ndDarkTheme(),
      home: home ?? const AppShell(),
    ),
  );
}

Future<void> pumpSized(
  WidgetTester tester,
  AppState state, {
  Widget? home,
  Size size = const Size(420, 840),
  ThemeData? theme,
}) async {
  await tester.binding.setSurfaceSize(size);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(appFor(state, home: home, theme: theme));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

List<FdroidPackage> samplePackages() => [
      pkg('org.demo.alpha',
          signer: 'sigAlpha',
          summary: 'Alpha browser',
          categories: const ['Internet'],
          icon: const FileRef(name: 'icon/a.png'),
          screenshots: const [FileRef(name: 's/a1.png'), FileRef(name: 's/a2.png')],
          license: 'GPL-3.0',
          author: 'Alpha Dev',
          webSite: 'https://a.test',
          sourceCode: 'https://src.test/a',
          issueTracker: 'https://src.test/a/issues',
          changelog: 'https://src.test/a/cl',
          donate: 'https://donate.test/a',
          description: '<p>Alpha <b>description</b> with a <a href="https://link.test">weblink</a>.</p>',
          whatsNew: 'Fixed bugs',
          antiFeatures: const {'Ads': 'Has ads'},
          extraVersions: const [
            AppVersion(
                versionName: 'v0',
                versionCode: 0,
                fileName: '/o.apk',
                added: 1,
                size: 2200000000,
                minSdk: 21),
          ]),
      pkg('org.demo.beta',
          summary: 'Beta editor',
          categories: const ['Writing'],
          icon: const FileRef(name: 'icon/b.png')),
      pkg('org.demo.gamma', categories: const ['Internet']),
    ];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(mockExtras);

  group('AppShell', () {
    testWidgets('compact layout shows navigation bar and switches tabs',
        (tester) async {
      final state = await seededState(packages: samplePackages());
      await pumpSized(tester, state);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(LatestPage), findsOneWidget);

      await tester.tap(find.text('Categories'));
      await tester.pumpAndSettle();
      expect(find.byType(CategoriesPage), findsOneWidget);

      await tester.tap(find.text('Search'));
      await tester.pumpAndSettle();
      expect(find.byType(SearchPage), findsOneWidget);

      await tester.tap(find.text('Updates'));
      await tester.pumpAndSettle();
      expect(find.byType(UpdatesPage), findsOneWidget);

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsPage), findsOneWidget);
    });

    testWidgets('wide layout uses NavigationRail', (tester) async {
      final state = await seededState(packages: samplePackages());
      await pumpSized(tester, state, size: const Size(1100, 800));
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('updates badge shows count', (tester) async {
      final state = await seededState(
        packages: [pkg('org.demo.old', versionCode: 9)],
        installed: {
          'org.demo.old': const InstalledApp(
              packageName: 'org.demo.old',
              versionCode: 1,
              versionName: 'v1'),
        },
      );
      await pumpSized(tester, state);
      expect(find.text('1'), findsWidgets);
      await pumpSized(tester, state, size: const Size(1100, 800));
      expect(find.byType(NavigationRail), findsOneWidget);
    });
  });

  group('LatestPage', () {
    testWidgets('loading spinner without data', (tester) async {
      final state = await seededState();
      state.status = IndexStatus.loading;
      state.apps = [];
      await pumpSized(tester, state);
      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });

    testWidgets('error state with retry', (tester) async {
      final state = await seededState();
      state.status = IndexStatus.error;
      state.error = 'no network';
      state.apps = [];
      await pumpSized(tester, state);
      expect(find.text('Could not load repositories'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pump();
    });

    testWidgets('empty state', (tester) async {
      final state = await seededState();
      state.status = IndexStatus.ready;
      state.apps = [];
      await pumpSized(tester, state);
      expect(find.text('No apps yet'), findsOneWidget);
      await tester.tap(find.text('Refresh'));
      await tester.pump();
    });

    testWidgets('list renders tiles and triggers details', (tester) async {
      final state = await seededState(packages: samplePackages());
      await pumpSized(tester, state);
      expect(find.text('alpha'), findsOneWidget);
      expect(find.text('Alpha browser'), findsOneWidget);
      await tester.tap(find.text('alpha'));
      await tester.pumpAndSettle();
      expect(find.byType(AppDetailsPage), findsOneWidget);
    });

    testWidgets('refresh icon calls refresh', (tester) async {
      final state = await seededState(packages: samplePackages());
      await pumpSized(tester, state);
      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pump();
      expect(state.status, IndexStatus.ready);
    });
  });

  group('CategoriesPage', () {
    testWidgets('lists categories and drills in', (tester) async {
      final state = await seededState(packages: samplePackages());
      await pumpSized(tester, state,
          home: const Scaffold(body: CategoriesPage()));
      await tester.pumpWidget(
          appFor(state, home: const CategoriesPage()));
      await tester.pumpAndSettle();
      expect(find.text('Internet'), findsOneWidget);
      expect(find.text('2 apps'), findsOneWidget);
      await tester.tap(find.text('Internet'));
      await tester.pumpAndSettle();
      expect(find.byType(CategoryAppsPage), findsOneWidget);
      expect(find.text('alpha'), findsOneWidget);
    });

    testWidgets('empty state', (tester) async {
      final state = await seededState();
      await pumpSized(tester, state, home: const CategoriesPage());
      expect(find.text('No categories'), findsOneWidget);
    });
  });

  group('SearchPage', () {
    testWidgets('placeholder then results then empty', (tester) async {
      final state = await seededState(packages: samplePackages());
      await pumpSized(tester, state, home: const SearchPage());
      expect(find.text('Search the catalog'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'demo');
      await tester.pumpAndSettle();
      expect(find.byType(AppTile).evaluate().length, greaterThan(1));

      await tester.enterText(find.byType(TextField), 'zzzz');
      await tester.pumpAndSettle();
      expect(find.text('No results'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(find.text('Search the catalog'), findsOneWidget);
    });
  });

  group('UpdatesPage', () {
    testWidgets('shows updates and installed sections', (tester) async {
      final state = await seededState(
        packages: [
          pkg('org.demo.old', versionCode: 9),
          pkg('org.demo.cur', versionCode: 1),
        ],
        installed: {
          'org.demo.old': const InstalledApp(
              packageName: 'org.demo.old',
              versionCode: 1,
              versionName: 'v1'),
          'org.demo.cur': const InstalledApp(
              packageName: 'org.demo.cur',
              versionCode: 1,
              versionName: 'v1'),
        },
      );
      await pumpSized(tester, state, home: const UpdatesPage());
      expect(find.text('Updates available · 1'), findsOneWidget);
      expect(find.text('Installed · 1'), findsOneWidget);
      expect(find.text('v1 → v9'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pump();
    });

    testWidgets('up to date and empty states', (tester) async {
      final current = await seededState(
        packages: [pkg('org.demo.cur', versionCode: 1)],
        installed: {
          'org.demo.cur': const InstalledApp(
              packageName: 'org.demo.cur',
              versionCode: 1,
              versionName: 'v1'),
        },
      );
      await pumpSized(tester, current, home: const UpdatesPage());
      expect(find.text('Everything is up to date.'), findsOneWidget);

      final empty = await seededState();
      await pumpSized(tester, empty, home: const UpdatesPage());
      expect(find.text('Nothing installed'), findsOneWidget);
    });
  });

  group('SettingsPage', () {
    testWidgets('renders all sections and toggles', (tester) async {
      final state = await seededState(autoRefresh: true);
      await pumpSized(tester, state, home: const SettingsPage());
      expect(find.text('Test Repo'), findsOneWidget);
      expect(find.text('Manage repositories'), findsOneWidget);
      expect(find.text('Refresh on launch'), findsOneWidget);
      expect(find.text('Show incompatible apps'), findsOneWidget);

      await tester.tap(find.text('Light'));
      await tester.pump();
      expect(state.themeMode, ThemeMode.light);
      await tester.tap(find.text('Dark'));
      await tester.pump();
      expect(state.themeMode, ThemeMode.dark);

      await tester.scrollUntilVisible(
          find.text('Refresh on launch'), 200,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('Refresh on launch'));
      await tester.pump();
      expect(state.autoRefresh, isFalse);
      await tester.scrollUntilVisible(
          find.text('Show incompatible apps'), 200,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('Show incompatible apps'));
      await tester.pump();
      expect(state.showIncompatible, isTrue);

      await tester.drag(
          find.byType(ListView).first, const Offset(0, 600));
      await tester.pump();
      final froid = find.widgetWithText(SwitchListTile, 'Test Repo');
      await tester.tap(froid);
      await tester.pump();
      expect(state.repos.first.enabled, isFalse);
    });

    testWidgets('navigates to repos page and opens source link',
        (tester) async {
      final state = await seededState();
      await pumpSized(tester, state, home: const SettingsPage());
      await tester.tap(find.text('Manage repositories'));
      await tester.pumpAndSettle();
      expect(find.byType(ReposPage), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Source code'));
      await tester.pump();
    });
  });

  group('ReposPage', () {
    testWidgets('add dialog validates and adds', (tester) async {
      final state = await seededState();
      await pumpSized(tester, state, home: const ReposPage());
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      expect(find.text('Add repository'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byType(TextField), 'https://new.test/repo');
      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await tester.pumpAndSettle();
      expect(state.repos.last.url, 'https://new.test/repo');
    });

    testWidgets('removes custom repo and toggles built-in', (tester) async {
      final repos = [
        ...RepoConfig.defaults(),
        RepoConfig(url: 'https://c.test/r', name: 'Custom'),
      ];
      final state = await seededState(repos: repos);
      await pumpSized(tester, state, home: const ReposPage());
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      expect(state.repos.length, 3);

      await tester.tap(find.byType(Switch).first);
      await tester.pump();
      expect(state.repos.first.enabled, isFalse);
    });
  });

  group('AppDetailsPage', () {
    testWidgets('renders full details', (tester) async {
      final state = await seededState(
        packages: samplePackages(),
        installed: {
          'org.demo.alpha': const InstalledApp(
              packageName: 'org.demo.alpha',
              versionCode: 1,
              versionName: 'v1',
              signerSha256: 'mismatch'),
        },
      );
      final entry = state.findApp('org.demo.alpha')!;
      await pumpSized(tester, state,
          home: AppDetailsPage(entry: entry),
          size: const Size(420, 1400));
      await tester.runAsync(() => Future<void>.delayed(
          const Duration(milliseconds: 500)));
      await tester.pump();
      expect(find.text('alpha'), findsWidgets);
      expect(find.text('Alpha Dev'), findsOneWidget);
      expect(find.text('vv1'), findsWidgets);
      expect(find.textContaining('signed by a different key'),
          findsOneWidget);
      expect(find.text('Ads'), findsWidgets);
      expect(find.text("What's new"), findsOneWidget);
      expect(find.text('About'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Links'), 200,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('Links'), findsOneWidget);
      expect(find.text('Website'), findsOneWidget);
      expect(find.text('Source'), findsOneWidget);
      expect(find.text('Issues'), findsOneWidget);
      expect(find.text('Changelog'), findsOneWidget);
      expect(find.text('Donate'), findsOneWidget);
      await tester.tap(find.text('Website'));
      await tester.pump();
      await tester.scrollUntilVisible(find.text('Versions'), 200,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('Versions'), findsOneWidget);
      expect(find.textContaining('2.05 GB'), findsOneWidget);
      // pull the screenshot strip back into view so its tiles build,
      // then let the failed image fetches resolve into error widgets
      await tester.drag(find.byType(ListView).first, const Offset(0, 600));
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(
          const Duration(milliseconds: 300)));
      await tester.pump();
      await tester.scrollUntilVisible(find.byType(Html), 150,
          scrollable: find.byType(Scrollable).first);
      final html = tester.widget<Html>(find.byType(Html));
      html.onLinkTap!('https://link.test', const {}, null);
      await tester.pump();
    });

    testWidgets('minimal package renders without optional sections',
        (tester) async {
      final state = await seededState(
          packages: [pkg('org.demo.min', categories: const [])]);
      final entry = state.findApp('org.demo.min')!;
      await pumpSized(tester, state, home: AppDetailsPage(entry: entry));
      expect(find.text('min'), findsWidgets);
      expect(find.text('Links'), findsNothing);
      expect(find.text('Versions'), findsNothing);
      expect(find.text("What's new"), findsNothing);
    });
  });

  group('widgets', () {
    testWidgets('AppIcon placeholder and image', (tester) async {
      final state = await seededState();
      await pumpSized(
        tester,
        state,
        home: const Scaffold(
          body: Column(children: [
            AppIcon(name: 'Hello', size: 48),
            AppIcon(name: '', size: 24),
            AppIcon(url: 'https://x.test/icon.png', name: 'Net', size: 48),
          ]),
        ),
      );
      await tester.runAsync(() => Future<void>.delayed(
          const Duration(milliseconds: 800)));
      await tester.pump();
      await tester.pump();
      expect(find.text('H'), findsOneWidget);
      expect(find.text('?'), findsOneWidget);
    });

    testWidgets('EmptyState with and without extras', (tester) async {
      final state = await seededState();
      await pumpSized(
        tester,
        state,
        home: const Scaffold(
          body: EmptyState(
              icon: Icons.error, title: 'T', message: 'M', action: Text('A')),
        ),
      );
      expect(find.text('T'), findsOneWidget);
      expect(find.text('M'), findsOneWidget);
      expect(find.text('A'), findsOneWidget);
    });

    testWidgets('InstallButton states', (tester) async {
      final device = FakeDevice();
      final state = await seededState(
        packages: [pkg('org.demo.b', versionCode: 5)],
        installed: {
          'org.demo.b': const InstalledApp(
              packageName: 'org.demo.b',
              versionCode: 1,
              versionName: 'v1'),
        },
        device: device,
      );
      final entry = state.findApp('org.demo.b')!;
      await pumpSized(
        tester,
        state,
        home: Scaffold(
          body: Column(children: [
            InstallButton(entry: entry, compact: true),
            InstallButton(entry: entry),
          ]),
        ),
      );
      expect(find.text('Update'), findsWidgets);
      await tester.tap(find.text('Update').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(device.calls, contains('installApk'));
    });

    testWidgets('InstallButton error retry', (tester) async {
      final state = await seededState(
        packages: [pkg('org.demo.b')],
        downloader: FakeDownloader(error: Exception('fail')),
      );
      final entry = state.findApp('org.demo.b')!;
      await pumpSized(
        tester,
        state,
        home: Scaffold(body: InstallButton(entry: entry, compact: true)),
      );
      await tester.tap(find.text('Install'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Retry'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('InstallButton progress and installing states',
        (tester) async {
      final state = await seededState(
        packages: [pkg('org.demo.b')],
        downloader: FakeDownloader(hang: true),
      );
      final entry = state.findApp('org.demo.b')!;
      await pumpSized(
        tester,
        state,
        home: Scaffold(body: InstallButton(entry: entry)),
      );
      await tester.tap(find.text('Install'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('50%'), findsOneWidget);

      final dl = state.downloads['org.demo.b']!;
      dl.installing = true;
      state.notifyListeners();
      await tester.pump();
      expect(find.text('Installing'), findsOneWidget);
    });

    testWidgets('open button for installed app', (tester) async {
      final device = FakeDevice();
      final state = await seededState(
        packages: [pkg('org.demo.b', versionCode: 1)],
        installed: {
          'org.demo.b': const InstalledApp(
              packageName: 'org.demo.b',
              versionCode: 1,
              versionName: 'v1'),
        },
        device: device,
      );
      final entry = state.findApp('org.demo.b')!;
      await pumpSized(
        tester,
        state,
        home: Scaffold(body: InstallButton(entry: entry, compact: true)),
      );
      expect(find.text('Open'), findsOneWidget);
      await tester.tap(find.text('Open'));
      await tester.pump();
      expect(device.calls, contains('open:org.demo.b'));
    });
  });
}
