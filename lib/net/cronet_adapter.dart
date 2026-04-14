import 'dart:typed_data';
import 'package:cronet_http/cronet_http.dart';
import 'package:http/http.dart';
import 'package:dio/dio.dart';

/// A simple bridge between [Dio] and [cronet_http].
class CronetAdapter implements HttpClientAdapter {
  final CronetEngine engine;
  late final CronetClient _client;

  CronetAdapter(this.engine) {
    _client = CronetClient(engine);
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<dynamic>? cancelFuture,
  ) async {
    final response = await _client.send(
      await _convertToStreamedRequest(options, requestStream),
    );

    return ResponseBody(
      response.stream,
      response.statusCode,
      headers: response.headers.map((k, v) => MapEntry(k.toLowerCase(), v.split(','))),
      statusMessage: response.reasonPhrase,
      isRedirect: response.isRedirect,
    );
  }

  Future<StreamedRequest> _convertToStreamedRequest(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
  ) async {
    final request = StreamedRequest(options.method, options.uri);
    request.headers.addAll(options.headers.map((k, v) => MapEntry(k, v.toString())));
    
    // Set content-length if provided by Dio to help Cronet optimize
    if (options.headers.containsKey('content-length')) {
      request.contentLength = int.tryParse(options.headers['content-length'].toString());
    }

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
    return request;
  }

  @override
  void close({bool force = false}) {
    _client.close();
  }
}
