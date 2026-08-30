import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'cookie_jar.dart';

/// Ответ HTTP запроса.
class EsiaHttpResponse {
  final int statusCode;
  final Map<String, String> headers;
  final String body;

  const EsiaHttpResponse({
    required this.statusCode,
    required this.headers,
    required this.body,
  });

  /// Значение заголовка Location (при редиректах 301, 302, 303, 307, 308).
  String? get location => headers['location'];

  /// Декодированный JSON ответ (если применимо).
  dynamic get json {
    if (body.isEmpty) return null;
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }

  bool get isRedirect =>
      statusCode == 301 ||
      statusCode == 302 ||
      statusCode == 303 ||
      statusCode == 307 ||
      statusCode == 308;

  bool get isSuccess => statusCode >= 200 && statusCode < 300;

  @override
  String toString() =>
      'EsiaHttpResponse(status: $statusCode, location: $location, bodyLen: ${body.length})';
}

/// HTTP клиент с поддержкой ручного управления редиректами и CookieJar.
class EsiaHttpClient {
  final HttpClient _client;
  final CookieJar cookieJar;
  final String userAgent;

  EsiaHttpClient({
    CookieJar? cookieJar,
    String? userAgent,
  })  : cookieJar = cookieJar ?? CookieJar(),
        userAgent = userAgent ??
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36',
        _client = HttpClient() {
    _client.badCertificateCallback = (cert, host, port) => true;
  }

  /// Выполняет GET запрос с ручным редиректом.
  Future<EsiaHttpResponse> get(
    Uri uri, {
    Map<String, String>? headers,
  }) async {
    final request = await _client.getUrl(uri);
    _applyHeaders(request, uri, headers);
    final response = await request.close();
    return _processResponse(uri, response);
  }

  /// Выполняет POST запрос с JSON телом.
  Future<EsiaHttpResponse> postJson(
    Uri uri,
    Map<String, dynamic> body, {
    Map<String, String>? headers,
  }) async {
    final request = await _client.postUrl(uri);
    final jsonStr = jsonEncode(body);
    final customHeaders = {
      'content-type': 'application/json; charset=utf-8',
      'accept': 'application/json',
      ...?headers,
    };
    _applyHeaders(request, uri, customHeaders);
    request.add(utf8.encode(jsonStr));
    final response = await request.close();
    return _processResponse(uri, response);
  }

  /// Выполняет POST запрос с form-urlencoded телом.
  Future<EsiaHttpResponse> postForm(
    Uri uri,
    Map<String, String> fields, {
    Map<String, String>? headers,
  }) async {
    final request = await _client.postUrl(uri);
    final bodyStr = fields.entries
        .map((e) =>
            '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    final customHeaders = {
      'content-type': 'application/x-www-form-urlencoded',
      ...?headers,
    };
    _applyHeaders(request, uri, customHeaders);
    request.add(utf8.encode(bodyStr));
    final response = await request.close();
    return _processResponse(uri, response);
  }

  /// Выполняет POST запрос с multipart/form-data телом.
  Future<EsiaHttpResponse> postMultipart(
    Uri uri,
    Map<String, String> fields, {
    Map<String, String>? headers,
  }) async {
    final boundary = '----WebKitFormBoundary${_generateRandomString(16)}';
    final request = await _client.postUrl(uri);

    final buffer = StringBuffer();
    for (final entry in fields.entries) {
      buffer.write('--$boundary\r\n');
      buffer.write(
          'Content-Disposition: form-data; name="${entry.key}"\r\n\r\n');
      buffer.write('${entry.value}\r\n');
    }
    buffer.write('--$boundary--\r\n');

    final customHeaders = {
      'content-type': 'multipart/form-data; boundary=$boundary',
      ...?headers,
    };
    _applyHeaders(request, uri, customHeaders);
    request.add(utf8.encode(buffer.toString()));
    final response = await request.close();
    return _processResponse(uri, response);
  }

  void _applyHeaders(
    HttpClientRequest request,
    Uri uri,
    Map<String, String>? headers,
  ) {
    request.followRedirects = false;
    request.headers.set('User-Agent', userAgent);
    request.headers.set(
        'Accept', 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8');
    request.headers.set('Accept-Language', 'ru-RU,ru;q=0.9,en-US;q=0.8,en;q=0.7');

    final cookieHeader = cookieJar.getCookieHeader(uri);
    if (cookieHeader.isNotEmpty) {
      request.headers.set('Cookie', cookieHeader);
    }

    headers?.forEach((key, value) {
      request.headers.set(key, value);
    });
  }

  Future<EsiaHttpResponse> _processResponse(
    Uri requestUri,
    HttpClientResponse response,
  ) async {
    // Сохраняем cookies из ответа
    cookieJar.saveCookies(requestUri, response.cookies);

    final responseHeaders = <String, String>{};
    response.headers.forEach((name, values) {
      responseHeaders[name.toLowerCase()] = values.join(', ');
    });

    final bodyBytes = await response.fold<List<int>>(
      <int>[],
      (buffer, data) => buffer..addAll(data),
    );
    final body = utf8.decode(bodyBytes, allowMalformed: true);

    return EsiaHttpResponse(
      statusCode: response.statusCode,
      headers: responseHeaders,
      body: body,
    );
  }

  void close() {
    _client.close();
  }

  static String _generateRandomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rnd = Random();
    return List.generate(length, (index) => chars[rnd.nextInt(chars.length)])
        .join();
  }
}
