import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:dio/dio.dart';

/// A bridge between [Dio] and the standard [http] package.
/// Used to leverage Native SSL providers (like Conscrypt) on Android.
class NativeHttpAdapter implements HttpClientAdapter {
  final http.Client _client = http.Client();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<dynamic>? cancelFuture,
  ) async {
    final request = http.StreamedRequest(options.method, options.uri);
    request.headers.addAll(options.headers.map((k, v) => MapEntry(k, v.toString())));

    if (requestStream != null) {
      requestStream.listen(
        request.sink.add,
        onError: request.sink.addError,
        onDone: request.sink.close,
        cancelOnError: true,
      );
    } else {
      request.sink.close();
    }

    final response = await _client.send(request);

    return ResponseBody(
      response.stream.cast<Uint8List>(),
      response.statusCode,
      headers: response.headers.map((k, v) => MapEntry(k.toLowerCase(), v.split(','))),
      statusMessage: response.reasonPhrase,
      isRedirect: response.isRedirect,
    );
  }

  @override
  void close({bool force = false}) {
    _client.close();
  }
}
