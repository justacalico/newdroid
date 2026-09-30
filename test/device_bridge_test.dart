import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:newdroid/services/device_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('newdroid/device');
  final bridge = DeviceBridge(channel);

  MethodCall? lastCall;

  setUp(() {
    lastCall = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      lastCall = call;
      switch (call.method) {
        case 'installedPackages':
          return {
            'org.a': {
              'versionCode': 7,
              'versionName': '7.0',
              'label': 'A',
              'signer': 'AA',
              'system': false,
            },
            'org.b': {'versionCode': 1},
          };
        case 'sdkInt':
          return 34;
        case 'abis':
          return ['arm64-v8a', 'armeabi-v7a'];
        case 'canInstallUnknownApps':
          return true;
        case 'openInstallSettings':
          return true;
        case 'installApk':
          return true;
        case 'openApp':
          return true;
        case 'uninstallApp':
          return true;
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('installedPackages maps payload', () async {
    final apps = await bridge.installedPackages();
    expect(apps['org.a']!.versionCode, 7);
    expect(apps['org.a']!.versionName, '7.0');
    expect(apps['org.a']!.label, 'A');
    expect(apps['org.a']!.signerSha256, 'aa');
    expect(apps['org.b']!.versionName, '');
    expect(apps['org.b']!.signerSha256, isNull);
  });

  test('scalar queries', () async {
    expect(await bridge.sdkInt(), 34);
    expect(await bridge.abis(), ['arm64-v8a', 'armeabi-v7a']);
    expect(await bridge.canInstallUnknownApps(), isTrue);
  });

  test('actions forward args', () async {
    expect(await bridge.installApk('/tmp/x.apk'), isTrue);
    expect(lastCall!.method, 'installApk');
    expect(lastCall!.arguments, {'path': '/tmp/x.apk'});

    expect(await bridge.openApp('org.a'), isTrue);
    expect(lastCall!.arguments, {'package': 'org.a'});

    expect(await bridge.uninstallApp('org.a'), isTrue);
    await bridge.openInstallSettings();
    expect(lastCall!.method, 'openInstallSettings');
  });

  test('null platform responses map to safe defaults', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => null);
    expect(await bridge.installedPackages(), isEmpty);
    expect(await bridge.sdkInt(), 0);
    expect(await bridge.abis(), isEmpty);
    expect(await bridge.canInstallUnknownApps(), isFalse);
    expect(await bridge.installApk('x'), isFalse);
    expect(await bridge.openApp('x'), isFalse);
    expect(await bridge.uninstallApp('x'), isFalse);
  });
}
