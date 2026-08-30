import 'dart:io';

/// Хранилище сессионных cookie для управления сессией между запросами.
class CookieJar {
  final Map<String, Cookie> _cookies = {};

  /// Сохраняет список cookie.
  void saveCookies(Uri uri, List<Cookie> cookies) {
    for (final cookie in cookies) {
      final domain = (cookie.domain ?? uri.host).toLowerCase().replaceAll(RegExp(r'^\.'), '');
      final key = '$domain:${cookie.name}';
      _cookies[key] = cookie;
    }
  }

  /// Парсит и сохраняет cookie из raw строки или заголовка `Set-Cookie`.
  void saveFromRawSetCookie(Uri uri, String rawHeader) {
    // В некоторых случаях несколько Set-Cookie склеиваются.
    // Разбиваем с учетом возможных дат в Expires (например 'Expires=Wed, 21 Oct 2025')
    final parts = _splitSetCookieHeaders(rawHeader);
    final cookies = <Cookie>[];
    for (final part in parts) {
      try {
        cookies.add(Cookie.fromSetCookieValue(part));
      } catch (_) {
        // Если не удалось распарсить стандартно, пробуем базовый парсинг key=value
        final nameVal = part.split(';').first.trim();
        final eqIdx = nameVal.indexOf('=');
        if (eqIdx > 0) {
          final name = nameVal.substring(0, eqIdx).trim();
          final val = nameVal.substring(eqIdx + 1).trim();
          cookies.add(Cookie(name, val));
        }
      }
    }
    saveCookies(uri, cookies);
  }

  /// Формирует строку заголовка `Cookie` для заданного URI.
  String getCookieHeader(Uri uri) {
    final host = uri.host.toLowerCase();
    final matchingCookies = <String, String>{};

    for (final entry in _cookies.entries) {
      final domain = entry.key.split(':').first;
      final cookie = entry.value;

      if (_domainMatches(host, domain)) {
        matchingCookies[cookie.name] = cookie.value;
      }
    }

    return matchingCookies.entries
        .map((e) => '${e.key}=${e.value}')
        .join('; ');
  }

  /// Получает все сохраненные cookie в виде `Map<String, String>`.
  Map<String, String> getAllCookiesForHost(String host) {
    final cleanHost = host.toLowerCase();
    final result = <String, String>{};
    for (final entry in _cookies.entries) {
      final domain = entry.key.split(':').first;
      if (_domainMatches(cleanHost, domain)) {
        result[entry.value.name] = entry.value.value;
      }
    }
    return result;
  }

  /// Очищает хранилище.
  void clear() {
    _cookies.clear();
  }

  bool _domainMatches(String requestHost, String cookieDomain) {
    if (requestHost == cookieDomain) return true;
    if (requestHost.endsWith('.$cookieDomain')) return true;
    return false;
  }

  static List<String> _splitSetCookieHeaders(String setCookieHeader) {
    // Регулярное выражение для разделения нескольких Set-Cookie
    final result = <String>[];
    final regex = RegExp(r'(?:,\s*)(?=[A-Za-z0-9_\-]+=[^;]+)');
    final matches = setCookieHeader.split(regex);
    for (final match in matches) {
      if (match.trim().isNotEmpty) {
        result.add(match.trim());
      }
    }
    return result;
  }
}
