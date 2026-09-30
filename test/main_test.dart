import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:newdroid/app_state.dart';
import 'package:newdroid/main.dart' as app;
import 'package:newdroid/services/prefs_store.dart';
import 'package:newdroid/ui/app_shell.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('NewDroidApp builds shell around injected state', (tester) async {
    SharedPreferences.setMockInitialValues({'autoRefresh': false});
    final prefs = await SharedPreferences.getInstance();
    final state = AppState(prefs: PrefsStore(prefs));
    await tester.pumpWidget(app.NewDroidApp(state: state));
    await tester.pump();
    expect(find.byType(AppShell), findsOneWidget);
    expect(find.byType(MaterialApp), findsOneWidget);
  });

  testWidgets('app.main() wires state and runs', (tester) async {
    SharedPreferences.setMockInitialValues({'autoRefresh': false});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => Directory.systemTemp.path,
    );
    await tester.runAsync(() async { await app.main(); });
    await tester.pump();
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(AppShell), findsOneWidget);
  });
}
