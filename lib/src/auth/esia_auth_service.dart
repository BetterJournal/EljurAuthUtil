import 'dart:async';
import '../http/esia_http_client.dart';
import '../models/auth_exception.dart';
import '../models/auth_result.dart';
import '../models/mfa_info.dart';
import '../models/user_credentials.dart';

/// Сервис пошаговой аутентификации в ЭлЖур через Госуслуги (ESIA).
class EsiaAuthService {
  final EsiaHttpClient _client;

  EsiaAuthService({EsiaHttpClient? client})
      : _client = client ?? EsiaHttpClient();

  /// Запускает полный цикл аутентификации.
  Future<AuthResult> authenticate({
    required UserCredentials credentials,
    required Future<String> Function(MfaInfo mfaInfo) onMfaRequired,
    void Function(String stepMessage)? onStep,
    void Function(int attempt, int maxAttempts)? onPolling,
  }) async {
    final host = credentials.eljurHost;

    // -------------------------------------------------------------
    // Фаза 1 — Инициализация OAuth через ЭлЖур
    // -------------------------------------------------------------
    onStep?.call('Инициализация OAuth сессии в ЭлЖур...');
    final esiaLoginUrl = await _initiateOAuthFlow(host);

    // -------------------------------------------------------------
    // Фаза 2 — Авторизация на Госуслугах
    // -------------------------------------------------------------
    onStep?.call('Вход на Госуслугах (ESIA)...');
    final oauthRedirectUrl = await _loginToEsia(
      credentials: credentials,
      esiaUrl: esiaLoginUrl,
      onMfaRequired: onMfaRequired,
      onStep: onStep,
    );

    // -------------------------------------------------------------
    // Фаза 3 — Обмен OAuth-кода на токен ЭлЖура
    // -------------------------------------------------------------
    onStep?.call('Обмен кода авторизации с ЭлЖур...');
    final (vToken, region) = await _exchangeOAuthCode(
      host: host,
      redirectUrl: oauthRedirectUrl,
      onStep: onStep,
      onPolling: onPolling,
    );

    // -------------------------------------------------------------
    // Фаза 4 — Получение сессионного токена пользователей/школ
    // -------------------------------------------------------------
    onStep?.call('Получение профилей и сессионных токенов...');
    final users = await _fetchUsersVendors(
      host: host,
      vToken: vToken,
    );

    return AuthResult(
      vToken: vToken,
      region: region,
      host: host,
      users: users,
    );
  }

  /// Фаза 1: 1.1 -> 1.2 -> 1.3
  Future<Uri> _initiateOAuthFlow(String host) async {
    // 1.1 Начало OAuth-потока
    final startUri =
        Uri.parse('https://$host/journal-esia-region-action?flow=v2');
    final res1 = await _client.get(startUri);

    final loc1 = res1.location;
    if (loc1 == null) {
      throw ParsingException(
        'Шаг 1.1: ЭлЖур не вернул заголовок Location для старта OAuth. Статус: ${res1.statusCode}',
      );
    }

    final uri1 = _resolveUri(startUri, loc1);

    // 1.2 Переадресация на Госуслуги
    final res2 = await _client.get(uri1);
    final loc2 = res2.location;
    if (loc2 == null) {
      throw ParsingException(
        'Шаг 1.2: ЭлЖур не вернул URL переадресации на Госуслуги. Статус: ${res2.statusCode}',
      );
    }

    final esiaUri = _resolveUri(uri1, loc2);

    // 1.3 Получение сессионных cookie от Госуслуг
    final res3 = await _client.get(esiaUri);
    if (!res3.isRedirect && res3.statusCode != 200) {
      throw ParsingException(
        'Шаг 1.3: Не удалось получить сессионные cookie от Госуслуг. Статус: ${res3.statusCode}',
      );
    }

    return esiaUri;
  }

  /// Фаза 2: 2.1 (логин+пароль) -> 2.2 (2FA / skip quiz)
  Future<String> _loginToEsia({
    required UserCredentials credentials,
    required Uri esiaUrl,
    required Future<String> Function(MfaInfo mfaInfo) onMfaRequired,
    void Function(String message)? onStep,
  }) async {
    final loginApiUri =
        Uri.parse('https://esia.gosuslugi.ru/aas/oauth2/api/login');

    final loginRes = await _client.postJson(loginApiUri, {
      'login': credentials.login,
      'password': credentials.password,
    });

    if (loginRes.statusCode == 400 ||
        loginRes.statusCode == 401 ||
        loginRes.statusCode == 403) {
      final json = loginRes.json;
      final errorMsg = _extractErrorMessage(json) ??
          'Неверный логин или пароль от учетной записи Госуслуг.';
      throw InvalidCredentialsException(errorMsg);
    }

    final loginJson = loginRes.json as Map<String, dynamic>? ?? {};
    var action = loginJson['action'] as String?;

    // Если 2FA не требуется и сразу DONE
    if (action == 'DONE') {
      final redirectUrl = loginJson['redirect_url'] as String?;
      if (redirectUrl != null) return redirectUrl;
    }

    // Если требуется MFA
    if (action == 'ENTER_MFA') {
      final mfaInfo = MfaInfo.fromJson(loginJson);
      onStep?.call(
          'Требуется двухфакторная аутентификация (${mfaInfo.type.description})...');
      final code = await onMfaRequired(mfaInfo);

      // ЕСИА ожидает /login/totp/verify (для TTP) или /login/otp/verify (для SMS)
      final verifyPath = mfaInfo.type.apiPath;
      final verifyUri = Uri.parse(
          'https://esia.gosuslugi.ru/aas/oauth2/api/login/$verifyPath/verify?code=${Uri.encodeQueryComponent(code.trim())}');

      var verifyRes = await _client.postJson(verifyUri, {});

      // Fallback на случай нестандартного пути
      if (verifyRes.statusCode == 404) {
        final fallbackPath = mfaInfo.type == MfaType.sms ? 'sms' : 'ttp';
        final fallbackUri = Uri.parse(
            'https://esia.gosuslugi.ru/aas/oauth2/api/login/$fallbackPath/verify?code=${Uri.encodeQueryComponent(code.trim())}');
        final fallbackRes = await _client.postJson(fallbackUri, {});
        if (fallbackRes.statusCode != 404) {
          verifyRes = fallbackRes;
        }
      }

      if (!verifyRes.isSuccess && verifyRes.statusCode != 202) {
        final errJson = verifyRes.json;
        final errorMsg = _extractErrorMessage(errJson) ??
            (verifyRes.statusCode == 404
                ? 'Эндпоинт подтверждения ЕСИА не найден (404).'
                : 'Неверный код подтверждения двухфакторной аутентификации.');
        throw MfaFailedException(errorMsg);
      }

      final verifyJson = verifyRes.json as Map<String, dynamic>? ?? {};
      action = verifyJson['action'] as String?;

      if (action == 'DONE') {
        final redirectUrl = verifyJson['redirect_url'] as String?;
        if (redirectUrl != null) return redirectUrl;
      }
    }

    // Обработка опроса (MAX_QUIZ)
    if (action == 'MAX_QUIZ') {
      onStep?.call('Пропуск опроса Госуслуг...');
      final skipUri =
          Uri.parse('https://esia.gosuslugi.ru/aas/oauth2/api/login/quiz-max/skip');
      final skipRes = await _client.postJson(skipUri, {});
      final skipJson = skipRes.json as Map<String, dynamic>? ?? {};
      final redirectUrl = skipJson['redirect_url'] as String?;
      if (redirectUrl != null) {
        return redirectUrl;
      }
    }

    throw EsiaAuthException(
      'Не удалось завершить авторизацию в Госуслугах. Неизвестное действие: $action',
    );
  }

  /// Фаза 3: 3.1 -> 3.2 -> 3.3 (polling) -> 3.4
  Future<(String vToken, String region)> _exchangeOAuthCode({
    required String host,
    required String redirectUrl,
    void Function(String message)? onStep,
    void Function(int attempt, int maxAttempts)? onPolling,
  }) async {
    // 3.1 Переход по redirect_url
    final redUri = Uri.parse(redirectUrl);
    final res31 = await _client.get(redUri);

    final formAction = _extractFormAction(res31.body);
    final oauthCode = _extractFormCode(res31.body);

    if (formAction == null || oauthCode == null) {
      throw ParsingException(
        'Шаг 3.1: Не удалось извлечь форму или код авторизации из ответа Госуслуг.',
      );
    }

    final validateUri = _resolveUri(redUri, formAction);

    // 3.2 Отправка OAuth-кода в ЭлЖур
    final res32 = await _client.postMultipart(
      validateUri,
      {'code': oauthCode},
    );

    final esiaTaskId = _extractEsiaTaskId(res32.body);
    if (esiaTaskId == null) {
      throw ParsingException(
        'Шаг 3.2: Не удалось извлечь esiaTaskId из ответа ЭлЖур.',
      );
    }

    // 3.3 Polling задачи
    onStep?.call('Ожидание обработки задачи в ЭлЖур ($esiaTaskId)...');
    const maxAttempts = 10;
    String? checkLink;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      onPolling?.call(attempt, maxAttempts);

      final checkUri = Uri.parse(
          'https://$host/journal-esia-action/action.check?taskId=${Uri.encodeQueryComponent(esiaTaskId)}');
      final checkRes = await _client.get(checkUri);

      if (checkRes.isSuccess) {
        final json = checkRes.json;
        if (json is Map<String, dynamic> && json['link'] != null) {
          checkLink = json['link'].toString();
          break;
        }
      }

      if (attempt < maxAttempts) {
        await Future.delayed(const Duration(seconds: 5));
      }
    }

    if (checkLink == null) {
      throw const PollingTimeoutException();
    }

    final region = _extractRegion(checkLink);
    if (region == null) {
      throw ParsingException(
        'Шаг 3.3: Не удалось извлечь region из ссылки: $checkLink',
      );
    }

    // 3.4 Финальный редирект -> v_token
    final finalRedirectUri = _resolveUri(Uri.parse('https://$host'), checkLink);
    final res34 = await _client.get(finalRedirectUri);

    final finalLocation = res34.location;
    if (finalLocation == null) {
      throw ParsingException(
        'Шаг 3.4: ЭлЖур не вернул Location с v_token. Статус: ${res34.statusCode}',
      );
    }

    final vToken = _extractVToken(finalLocation);
    if (vToken == null) {
      throw ParsingException(
        'Шаг 3.4: Не удалось найти параметр v_token в Location: $finalLocation',
      );
    }

    return (vToken, region);
  }

  /// Фаза 4: Получение сессионного токена пользователей
  Future<List<VendorUser>> _fetchUsersVendors({
    required String host,
    required String vToken,
  }) async {
    final uri = Uri.parse(
      'https://$host/apiv3/getusersvendors?out_format=json&v_token=${Uri.encodeQueryComponent(vToken)}&auth_token=true',
    );

    try {
      final res = await _client.get(uri);
      if (res.statusCode != 200) {
        return const [];
      }

      final json = res.json;
      if (json is Map<String, dynamic> && json['result'] is List) {
        final list = json['result'] as List;
        return list
            .whereType<Map<String, dynamic>>()
            .map((item) => VendorUser.fromJson(item))
            .toList();
      }
      return const [];
    } catch (_) {
      return const [];
    }
  }

  void close() {
    _client.close();
  }

  // --- Вспомогательные методы парсинга ---

  static String? _extractErrorMessage(dynamic json) {
    if (json is! Map) return null;
    return json['error_description']?.toString() ??
        json['message']?.toString() ??
        json['error']?.toString();
  }

  static String? _extractFormAction(String html) {
    final formMatch = RegExp(
      r'<form[^>]+action="([^"]+)"|<form[^>]+action=\x27([^\x27]+)\x27',
      caseSensitive: false,
    ).firstMatch(html);
    return formMatch?.group(1) ?? formMatch?.group(2);
  }

  static String? _extractFormCode(String html) {
    final codeMatch1 = RegExp(
      r'<input[^>]+name="code"[^>]+value="([^"]+)"|<input[^>]+name=\x27code\x27[^>]+value=\x27([^\x27]+)\x27',
      caseSensitive: false,
    ).firstMatch(html);
    if (codeMatch1 != null) {
      return codeMatch1.group(1) ?? codeMatch1.group(2);
    }

    final codeMatch2 = RegExp(
      r'<input[^>]+value="([^"]+)"[^>]+name="code"|<input[^>]+value=\x27([^\x27]+)\x27[^>]+name=\x27code\x27',
      caseSensitive: false,
    ).firstMatch(html);
    return codeMatch2?.group(1) ?? codeMatch2?.group(2);
  }

  static String? _extractEsiaTaskId(String html) {
    final match = RegExp(
      r'esiaTaskId\s*=\s*"([^"]+)"|esiaTaskId\s*=\s*\x27([^\x27]+)\x27',
      caseSensitive: false,
    ).firstMatch(html);
    return match?.group(1) ?? match?.group(2);
  }

  static String? _extractRegion(String link) {
    final uri = Uri.tryParse(link);
    if (uri != null && uri.queryParameters.containsKey('region')) {
      return uri.queryParameters['region'];
    }

    final match = RegExp(r'region[=\.]([a-f0-9]{16,64})', caseSensitive: false)
        .firstMatch(link);
    return match?.group(1);
  }

  static String? _extractVToken(String location) {
    final uri = Uri.tryParse(location);
    if (uri != null && uri.queryParameters.containsKey('v_token')) {
      return uri.queryParameters['v_token'];
    }

    final match =
        RegExp(r'v_token=([^&]+)', caseSensitive: false).firstMatch(location);
    return match != null ? Uri.decodeComponent(match.group(1)!) : null;
  }

  static Uri _resolveUri(Uri base, String location) {
    if (location.startsWith('http://') || location.startsWith('https://')) {
      return Uri.parse(location);
    }
    return base.resolve(location);
  }
}
