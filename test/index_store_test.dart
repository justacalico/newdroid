import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:newdroid/models/repo_config.dart';
import 'package:newdroid/services/index_store.dart';

void main() {
  late Directory dir;
  late RepoConfig repo;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('index_store_test');
    repo = RepoConfig(url: 'https://repo.test/base', name: 'Test');
  });

  tearDown(() async {
    if (dir.existsSync()) await dir.delete(recursive: true);
  });

  IndexStore storeWith(http.Client client) =>
      IndexStore(client: client, cacheDir: dir);

  test('fetches v2 index, writes cache and etag', () async {
    final body = await File('test/fixtures/index_v2.json').readAsString();
    final client = MockClient((request) async {
      expect(request.url.path, '/base/index-v2.json');
      return http.Response(body, 200, headers: {'etag': 'W/"v1"'});
    });
    final result = await storeWith(client).fetch(repo);
    expect(result!.fromCache, isFalse);
    expect(result.index.packages.containsKey('org.test.alpha'), isTrue);
    expect(File('${dir.path}/index-${repo.id}.json').existsSync(), isTrue);
    expect(File('${dir.path}/index-${repo.id}.etag').readAsStringSync(),
        'W/"v1"');
  });

  test('sends etag and reuses cache on 304', () async {
    // Seed the cache.
    final body = await File('test/fixtures/index_v2.json').readAsString();
    final seed = MockClient((_) async =>
        http.Response(body, 200, headers: {'etag': 'W/"seed"'}));
    await storeWith(seed).fetch(repo);

    final client = MockClient((request) async {
      expect(request.headers['if-none-match'], 'W/"seed"');
      return http.Response('', 304);
    });
    final result = await storeWith(client).fetch(repo);
    expect(result!.fromCache, isTrue);
    expect(result.index.repoName, 'Test Repo');
  });

  test('falls back to v1 index on 404', () async {
    final v1 = await File('test/fixtures/index_v1.json').readAsString();
    final client = MockClient((request) async {
      if (request.url.path.endsWith('index-v2.json')) {
        return http.Response('not found', 404);
      }
      expect(request.url.path, '/base/index-v1.json');
      return http.Response(v1, 200);
    });
    final result = await storeWith(client).fetch(repo);
    expect(result!.index.packages.containsKey('org.v1.gamma'), isTrue);
  });

  test('serves cache when network fails', () async {
    final body = await File('test/fixtures/index_v2.json').readAsString();
    final seed = MockClient((_) async => http.Response(body, 200));
    await storeWith(seed).fetch(repo);

    final failing =
        MockClient((_) async => throw http.ClientException('offline'));
    final result = await storeWith(failing).fetch(repo);
    expect(result!.fromCache, isTrue);
  });

  test('throws when nothing cached and network fails', () async {
    final failing =
        MockClient((_) async => throw http.ClientException('offline'));
    expect(() => storeWith(failing).fetch(repo), throwsException);
  });

  test('socket and format errors fall back to cache or throw', () async {
    var calls = 0;
    final client = MockClient((_) async {
      calls++;
      if (calls == 1) throw const SocketException('no route');
      throw const FormatException('corrupt');
    });
    await expectLater(storeWith(client).fetch(repo), throwsException);
    expect(calls, 2);
  });

  test('http error status throws client exception path', () async {
    final client = MockClient((_) async => http.Response('oops', 500));
    expect(() => storeWith(client).fetch(repo), throwsException);
  });

  test('returns null when repo serves nothing', () async {
    final client = MockClient((_) async => http.Response('no', 404));
    final result = await storeWith(client).fetch(repo);
    expect(result, isNull);
  });

  test('loadCached returns null without cache or on bad json', () async {
    final store = storeWith(MockClient((_) async => http.Response('', 404)));
    expect(await store.loadCached(repo), isNull);
    await File('${dir.path}/index-${repo.id}.json').writeAsString('{bad');
    expect(await store.loadCached(repo), isNull);
  });
}
