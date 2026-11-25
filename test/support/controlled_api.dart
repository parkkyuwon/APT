import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Keeps every request in-process and lets tests choose response ordering.
class ControlledApi implements HttpClientAdapter {
  final _requests = StreamController<PendingRequest>();
  late final _iterator = StreamIterator(_requests.stream);
  final List<PendingRequest> pending = [];

  Future<PendingRequest> next() async {
    if (!await _iterator.moveNext().timeout(const Duration(seconds: 3))) {
      throw StateError('No further request');
    }
    return _iterator.current;
  }

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) {
    final request = PendingRequest(options);
    pending.add(request);
    _requests.add(request);
    return request.response.future;
  }

  @override
  void close({bool force = false}) {
    for (final request in pending) {
      if (!request.response.isCompleted) request.reply();
    }
    unawaited(_iterator.cancel());
    unawaited(_requests.close());
  }
}

class PendingRequest {
  PendingRequest(this.options);
  final RequestOptions options;
  final response = Completer<ResponseBody>();

  void reply({int status = 200, Map<String, dynamic>? body}) {
    response.complete(ResponseBody.fromString(
      jsonEncode(body ?? {'ok': true, 'state': <String, dynamic>{}}),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    ));
  }

  void fail() {
    response.completeError(DioException(
      requestOptions: options,
      type: DioExceptionType.connectionError,
      message: 'Test transport failure',
    ));
  }
}
