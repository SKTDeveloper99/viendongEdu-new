import 'dart:async';
import 'dart:io' show IOException;

import 'package:http/http.dart' as http;

/// How a photo is shrunk on the phone before it is sent: image_picker's own
/// resize (longest edge) and JPEG quality. One place for every photo pick
/// that ends in an upload (camera and gallery).
abstract final class PhotoShrink {
  static const double maxEdge = 2000;
  static const int quality = 80;
}

/// Where one upload stands, for the line a screen shows under its button.
class UploadStatus {
  /// 1-based attempt number and how many attempts there are in all.
  final int attempt;
  final int attempts;

  /// Bytes of this attempt handed to the connection so far, of [total]
  /// (0 / 0 while waiting before a resend).
  final int sent;
  final int total;
  const UploadStatus({
    required this.attempt,
    required this.attempts,
    this.sent = 0,
    this.total = 0,
  });

  bool get resending => attempt > 1;
  double? get fraction => total > 0 ? sent / total : null;

  /// The person's line: "Đang gửi… 40%" or, after a network failure,
  /// "Mạng yếu, đang gửi lại (lần 2/3)… 40%".
  String get text {
    final f = fraction;
    final pct = f == null ? '' : ' ${(f * 100).round()}%';
    return resending
        ? 'Mạng yếu, đang gửi lại (lần $attempt/$attempts)…$pct'
        : 'Đang gửi…$pct';
  }
}

/// The answer started to arrive and was then lost: the server may already
/// have the file, so this attempt is final (never sent again on its own).
class UploadAnswerLost implements Exception {
  final Object cause;
  const UploadAnswerLost(this.cause);
  @override
  String toString() => 'UploadAnswerLost($cause)';
}

/// The one way the app sends files: a fresh request per attempt, a time limit
/// that grows with the size, and two automatic resends after a network
/// failure. Any HTTP answer (2xx, 4xx, 429, 5xx) is final.
abstract final class UploadSender {
  /// Automatic resends after the first attempt.
  static const int retries = 2;

  /// The pause before resend 1 and resend 2.
  static const List<Duration> pauses = [
    Duration(seconds: 2),
    Duration(seconds: 5),
  ];

  /// The pause itself (tests make it instant).
  static Future<void> Function(Duration) sleep = Future<void>.delayed;

  static const Duration timeoutBase = Duration(seconds: 30);
  static const Duration timeoutPerMb = Duration(seconds: 15);
  static const Duration timeoutFloor = Duration(seconds: 60);
  static const Duration timeoutCeiling = Duration(minutes: 10);

  /// Time limit for one attempt of [bytes]: 30 s + 15 s per MB (about
  /// 0.5 Mbit/s), never under 60 s (the old fixed limit) nor over 10 min.
  static Duration timeoutFor(int bytes) {
    final perMbMs = timeoutPerMb.inMilliseconds;
    final ms =
        timeoutBase.inMilliseconds + (bytes * perMbMs / (1024 * 1024)).ceil();
    if (ms < timeoutFloor.inMilliseconds) return timeoutFloor;
    if (ms > timeoutCeiling.inMilliseconds) return timeoutCeiling;
    return Duration(milliseconds: ms);
  }

  /// A failure of the network itself (socket, DNS, connection reset, TLS
  /// handshake, timeout) as opposed to an answer from the server.
  static bool isNetworkFailure(Object e) =>
      e is IOException || e is TimeoutException || e is http.ClientException;

  /// Sends what [build] makes (called again for each attempt: a multipart
  /// body stream can be read only once) through [client]. Returns the first
  /// HTTP answer whatever its status; throws the last network failure when
  /// every attempt failed, or [UploadAnswerLost].
  static Future<http.Response> send(
    http.BaseRequest Function() build, {
    required http.Client client,
    required Duration timeout,
    void Function(UploadStatus)? onStatus,
    Future<void> Function(Duration)? pause,
    int retries = UploadSender.retries,
  }) async {
    final attempts = retries + 1;
    for (var attempt = 1; ; attempt++) {
      try {
        return await _once(build(), client, timeout, (sent, total) {
          onStatus?.call(
            UploadStatus(
              attempt: attempt,
              attempts: attempts,
              sent: sent,
              total: total,
            ),
          );
        });
      } catch (e) {
        if (!isNetworkFailure(e) || attempt >= attempts) rethrow;
        onStatus?.call(UploadStatus(attempt: attempt + 1, attempts: attempts));
        final i = attempt - 1 < pauses.length ? attempt - 1 : pauses.length - 1;
        await (pause ?? sleep)(pauses[i]);
      }
    }
  }

  static Future<http.Response> _once(
    http.BaseRequest req,
    http.Client client,
    Duration timeout,
    void Function(int sent, int total) progress,
  ) async {
    final abort = Completer<void>();
    final watch = Stopwatch()..start();
    final streamed = await client
        .send(_Counted(req, progress, abort.future))
        .timeout(
          timeout,
          onTimeout: () {
            if (!abort.isCompleted) abort.complete();
            throw TimeoutException('upload', timeout);
          },
        );
    // The status line is here: from now on the server has answered.
    final left = timeout - watch.elapsed;
    const least = Duration(seconds: 5);
    try {
      return await http.Response.fromStream(
        streamed,
      ).timeout(left > least ? left : least);
    } catch (e) {
      if (!abort.isCompleted) abort.complete();
      throw UploadAnswerLost(e);
    }
  }
}

/// A request that sends [inner]'s body in 64 KB slices and reports each one
/// (upload progress). The connection pauses the slices it cannot take yet,
/// so the count follows what has really left. Aborted when [abortTrigger]
/// completes (the time limit), so a stuck connection is closed.
class _Counted extends http.BaseRequest with http.Abortable {
  final http.BaseRequest inner;
  final void Function(int sent, int total) onProgress;
  @override
  final Future<void>? abortTrigger;
  _Counted(this.inner, this.onProgress, this.abortTrigger)
    : super(inner.method, inner.url);

  @override
  http.ByteStream finalize() {
    final total = inner.contentLength;
    final body = inner.finalize();
    headers.addAll(inner.headers);
    contentLength = total;
    super.finalize();
    return http.ByteStream(_slices(body, total ?? 0));
  }

  Stream<List<int>> _slices(Stream<List<int>> body, int total) async* {
    const step = 64 * 1024;
    var sent = 0;
    onProgress(0, total);
    await for (final chunk in body) {
      for (var i = 0; i < chunk.length; i += step) {
        final end = i + step < chunk.length ? i + step : chunk.length;
        yield chunk.sublist(i, end);
        sent += end - i;
        onProgress(sent, total);
      }
    }
  }
}
