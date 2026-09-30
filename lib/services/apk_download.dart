import 'dart:async';
import 'dart:io';

import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

class DownloadProgress {
  const DownloadProgress({required this.received, this.total});

  final int received;
  final int? total;

  double get fraction =>
      total != null && total! > 0 ? received / total! : 0;
}

class DownloadHandle {
  DownloadHandle({required this.progress, required this.result, this.cancel});

  final Stream<DownloadProgress> progress;
  final Future<File> result;
  final void Function()? cancel;
}

class ChecksumMismatchException implements Exception {
  ChecksumMismatchException(this.expected, this.actual);

  final String expected;
  final String actual;

  @override
  String toString() =>
      'APK checksum mismatch: expected $expected, got $actual';
}

class ApkDownloader {
  ApkDownloader({http.Client? client}) : client = client ?? IOClient();

  final http.Client client;

  DownloadHandle start(
    Uri uri,
    File destination, {
    String? expectedSha256,
  }) {
    final progress = StreamController<DownloadProgress>();
    final httpClient = HttpClient();
    var cancelled = false;

    Future<File> run() async {
      final request = await httpClient.getUrl(uri);
      final response = await request.close();
      if (response.statusCode != 200) {
        throw HttpException('HTTP ${response.statusCode}', uri: uri);
      }
      await destination.parent.create(recursive: true);
      final sink = destination.openWrite();
      final digestSink = AccumulatorSink<Digest>();
      final sha = sha256.startChunkedConversion(digestSink);
      var received = 0;
      try {
        await for (final chunk in response) {
          if (cancelled) {
            throw const _Cancelled();
          }
          received += chunk.length;
          sink.add(chunk);
          sha.add(chunk);
          if (!progress.isClosed) {
            progress.add(DownloadProgress(
                received: received, total: response.contentLength));
          }
        }
        sha.close();
        await sink.flush();
        await sink.close();
      } on Object {
        await sink.close();
        await destination.delete().catchError((_) => destination);
        rethrow;
      }
      if (expectedSha256 != null &&
          digestSink.events.single.toString().toLowerCase() !=
              expectedSha256.toLowerCase()) {
        await destination.delete().catchError((_) => destination);
        throw ChecksumMismatchException(
            expectedSha256, digestSink.events.single.toString());
      }
      return destination;
    }

    final future = run();
    future.catchError((Object _) => File('')).ignore();
    return DownloadHandle(
      progress: progress.stream,
      result: future.whenComplete(() {
        httpClient.close();
        // close() only completes once the done event is delivered, which
        // hangs when nobody ever listened; fire and forget instead.
        unawaited(progress.close());
      }),
      cancel: () {
        cancelled = true;
        httpClient.close(force: true);
      },
    );
  }
}

class _Cancelled implements Exception {
  const _Cancelled();
}
