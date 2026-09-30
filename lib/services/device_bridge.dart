import 'package:flutter/services.dart';

class InstalledApp {
  const InstalledApp({
    required this.packageName,
    required this.versionCode,
    required this.versionName,
    this.label,
    this.signerSha256,
  });

  final String packageName;
  final int versionCode;
  final String versionName;
  final String? label;
  final String? signerSha256;
}

class DeviceBridge {
  DeviceBridge([this.channel = const MethodChannel('newdroid/device')]);

  final MethodChannel channel;

  Future<Map<String, InstalledApp>> installedPackages() async {
    final raw = await channel.invokeMapMethod<String, dynamic>(
        'installedPackages');
    final out = <String, InstalledApp>{};
    if (raw == null) return out;
    for (final e in raw.entries) {
      final m = e.value as Map;
      out[e.key] = InstalledApp(
        packageName: e.key,
        versionCode: (m['versionCode'] as num?)?.toInt() ?? 0,
        versionName: m['versionName'] as String? ?? '',
        label: m['label'] as String?,
        signerSha256: (m['signer'] as String?)?.toLowerCase(),
      );
    }
    return out;
  }

  Future<int> sdkInt() async =>
      (await channel.invokeMethod<int>('sdkInt')) ?? 0;

  Future<List<String>> abis() async =>
      (await channel.invokeListMethod<String>('abis')) ?? const [];

  Future<bool> canInstallUnknownApps() async =>
      (await channel.invokeMethod<bool>('canInstallUnknownApps')) ?? false;

  Future<void> openInstallSettings() =>
      channel.invokeMethod<void>('openInstallSettings');

  Future<bool> installApk(String path) async =>
      (await channel
          .invokeMethod<bool>('installApk', <String, String>{'path': path})) ??
      false;

  Future<bool> openApp(String packageName) async =>
      (await channel.invokeMethod<bool>(
          'openApp', <String, String>{'package': packageName})) ??
      false;

  Future<bool> uninstallApp(String packageName) async =>
      (await channel.invokeMethod<bool>(
          'uninstallApp', <String, String>{'package': packageName})) ??
      false;
}
