import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:newdroid/app_state.dart';
import 'package:newdroid/models/index_models.dart';
import 'package:newdroid/services/device_bridge.dart';
import 'package:newdroid/theme.dart';
import 'package:newdroid/ui/app_shell.dart';
import 'package:newdroid/ui/pages/app_details_page.dart';
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

List<FdroidPackage> galleryPackages() => [
      pkg('org.demo.tusky',
          summary: 'Mastodon client',
          description: '<p>A clean Mastodon client.</p>',
          categories: const ['Internet'],
          license: 'GPL-3.0',
          author: 'Tusky Team',
          icon: const FileRef(name: 'icon/tusky.png'),
          lastUpdated: 300),
      pkg('org.demo.organic',
          summary: 'Offline maps',
          categories: const ['Navigation'],
          license: 'Apache-2.0',
          lastUpdated: 200),
      pkg('org.demo.vlc', summary: 'Media player', lastUpdated: 100),
    ];

Widget _wrap(AppState state, {Widget? home, bool dark = false}) {
  return ChangeNotifierProvider<AppState>.value(
    value: state,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: dark ? ndDarkTheme(fontFamily: 'Roboto') : ndLightTheme(fontFamily: 'Roboto'),
      home: home ?? const AppShell(),
    ),
  );
}

Future<void> golden(
  WidgetTester tester,
  AppState state,
  String name, {
  Widget? home,
  Size size = const Size(390, 780),
  bool dark = false,
}) async {
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_wrap(state, home: home, dark: dark));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
  await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/$name.png'));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(mockExtras);

  testWidgets('golden latest compact', (tester) async {
    final state = await seededState(packages: galleryPackages());
    await golden(tester, state, 'latest_compact');
  });

  testWidgets('golden latest wide', (tester) async {
    final state = await seededState(packages: galleryPackages());
    await golden(tester, state, 'latest_wide', size: const Size(960, 720));
  });

  testWidgets('golden details', (tester) async {
    final state = await seededState(
      packages: galleryPackages(),
      installed: {
        'org.demo.tusky': const InstalledApp(
            packageName: 'org.demo.tusky',
            versionCode: 0,
            versionName: 'v0',
            signerSha256: 'other'),
      },
    );
    await golden(tester, state, 'details',
        home: AppDetailsPage(entry: state.findApp('org.demo.tusky')!));
  });

  testWidgets('golden updates', (tester) async {
    final state = await seededState(
      packages: [pkg('org.demo.tusky', versionCode: 4, lastUpdated: 300)],
      installed: {
        'org.demo.tusky': const InstalledApp(
            packageName: 'org.demo.tusky',
            versionCode: 1,
            versionName: 'v1'),
      },
    );
    state.selectTab(3);
    await golden(tester, state, 'updates');
  });

  testWidgets('golden categories', (tester) async {
    final state = await seededState(packages: galleryPackages());
    state.selectTab(1);
    await golden(tester, state, 'categories');
  });

  testWidgets('golden settings', (tester) async {
    final state = await seededState();
    state.selectTab(4);
    await golden(tester, state, 'settings');
  });

  testWidgets('golden dark latest', (tester) async {
    final state = await seededState(packages: galleryPackages());
    await golden(tester, state, 'latest_dark', dark: true);
  });
}
