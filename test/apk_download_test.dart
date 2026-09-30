import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:newdroid/services/apk_download.dart';

void main() {
  // The widget test config installs a fake HttpClient that 400s everything;
  // this suite exercises real loopback HTTP.
  HttpOverrides.global = null;
  late HttpServer server;
  late Uri base;
  late Directory tmp;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    base = Uri.parse('http://localhost:${server.port}');
    tmp = await Directory.systemTemp.createTemp('apk_dl_test');
    server.listen((request) {
      if (request.uri.path == '/good.apk') {
        request.response
          ..contentLength = 6
          ..add([1, 2, 3, 4, 5, 6]);
        request.response.close();
      } else if (request.uri.path == '/slow.apk') {
        request.response
          ..contentLength = 4
          ..add([9, 9]);
        // Never finishes — used by the cancel test.
      } else {
        request.response.statusCode = 500;
        request.response.close();
      }
    });
  });

  tearDown(() async {
    await server.close(force: true);
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  test('downloads with progress and verifies sha256', () async {
    final dest = File('${tmp.path}/out/app.apk');
    final handle = ApkDownloader()
        .start(base.resolve('/good.apk'), dest, expectedSha256: sha256.convert([1, 2, 3, 4, 5, 6]).toString());
    final progress = <double>[];
    final sub = handle.progress.listen((p) => progress.add(p.fraction));
    final file = await handle.result;
    await sub.cancel();
    expect(await file.readAsBytes(), [1, 2, 3, 4, 5, 6]);
    expect(progress, isNotEmpty);
    expect(progress.last, 1.0);
    expect(DownloadProgress(received: 5).fraction, 0);
  });

  test('checksum mismatch deletes file and throws', () async {
    final dest = File('${tmp.path}/bad.apk');
    final handle = ApkDownloader()
        .start(base.resolve('/good.apk'), dest, expectedSha256: 'deadbeef');
    expect(() => handle.result, throwsA(isA<ChecksumMismatchException>()));
    await handle.result.catchError((Object _) => dest);
    expect(dest.existsSync(), isFalse);
  });

  test('http error throws', () async {
    final handle = ApkDownloader()
        .start(base.resolve('/missing.apk'), File('${tmp.path}/x.apk'));
    expect(() => handle.result, throwsA(isA<HttpException>()));
    await handle.result.catchError((Object _) => File(''));
  });

  test('checksum exception message', () {
    final e = ChecksumMismatchException('abc', 'def');
    expect(e.toString(), contains('abc'));
    expect(e.toString(), contains('def'));
  });

  test('cancel aborts the download', () async {
    final dest = File('${tmp.path}/slow.apk');
    final handle = ApkDownloader().start(base.resolve('/slow.apk'), dest);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    handle.cancel!();
    await handle.result.catchError((Object _) => dest);
    expect(dest.existsSync(), isFalse);
  });
}
