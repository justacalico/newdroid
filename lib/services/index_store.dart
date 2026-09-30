import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import '../models/index_models.dart';
import '../models/repo_config.dart';

class RepoFetchResult {
  const RepoFetchResult({required this.index, required this.fromCache});

  final FdroidIndex index;
  final bool fromCache;
}

/// Downloads and caches F-Droid indexes (index-v2.json with index-v1.json
/// fallback), using ETag conditional requests so refreshes are cheap.
class IndexStore {
  IndexStore({http.Client? client, required this.cacheDir})
      : client = client ?? IOClient();

  final http.Client client;
  final Directory cacheDir;

  File _bodyFile(RepoConfig repo) =>
      File('${cacheDir.path}/index-${repo.id}.json');
  File _etagFile(RepoConfig repo) =>
      File('${cacheDir.path}/index-${repo.id}.etag');

  Future<FdroidIndex?> loadCached(RepoConfig repo) async {
    final file = _bodyFile(repo);
    if (!file.existsSync()) return null;
    try {
      return await compute(parseIndexJson, await file.readAsString());
    } on Object {
      return null;
    }
  }

  Future<RepoFetchResult?> fetch(RepoConfig repo) async {
    final errors = <String>[];
    for (final path in const ['index-v2.json', 'index-v1.json']) {
      try {
        final result = await _fetchOne(repo, path);
        if (result != null) return result;
      } on http.ClientException catch (e) {
        errors.add(e.message);
      } on SocketException catch (e) {
        errors.add(e.message);
      } on FormatException catch (e) {
        errors.add(e.message);
      }
    }
    // Network failed but a cached copy still works.
    final cached = await loadCached(repo);
    if (cached != null) return RepoFetchResult(index: cached, fromCache: true);
    if (errors.isNotEmpty) {
      throw Exception(errors.first);
    }
    return null;
  }

  Future<RepoFetchResult?> _fetchOne(RepoConfig repo, String path) async {
    final uri = Uri.parse('${repo.baseUrl}/$path');
    final headers = <String, String>{'Accept': 'application/json'};
    if (await _etagFile(repo).exists()) {
      headers['If-None-Match'] = (await _etagFile(repo).readAsString()).trim();
    }
    final response = await client
        .get(uri, headers: headers)
        .timeout(const Duration(seconds: 60));
    if (response.statusCode == 404) return null;
    if (response.statusCode == 304) {
      final cached = await loadCached(repo);
      if (cached != null) {
        return RepoFetchResult(index: cached, fromCache: true);
      }
    }
    if (response.statusCode != 200) {
      throw http.ClientException('HTTP ${response.statusCode}', uri);
    }
    final body = utf8.decode(response.bodyBytes);
    final index = await compute(parseIndexJson, body);
    await _bodyFile(repo).writeAsString(body, flush: true);
    final etag = response.headers['etag'];
    if (etag != null) {
      await _etagFile(repo).writeAsString(etag, flush: true);
    }
    return RepoFetchResult(index: index, fromCache: false);
  }
}
