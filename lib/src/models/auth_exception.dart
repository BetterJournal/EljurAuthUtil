/// Базовое исключение для ошибок авторизации ЭлЖур / Госуслуги (ESIA).
class EsiaAuthException implements Exception {
  final String message;
  final Object? cause;

  const EsiaAuthException(this.message, [this.cause]);

  @override
  String toString() => message;
}

/// Ошибка неверных учетных данных (логин или пароль).
class InvalidCredentialsException extends EsiaAuthException {
  const InvalidCredentialsException([
    super.message = 'Неверный логин или пароль от Госуслуг.',
    super.cause,
  ]);
}

/// Ошибка подтверждения двухфакторной аутентификации (MFA / 2FA).
class MfaFailedException extends EsiaAuthException {
  const MfaFailedException([
    super.message = 'Неверный код подтверждения двухфакторной аутентификации.',
    super.cause,
  ]);
}

/// Ошибка ожидания обработки задачи в ЭлЖур (polling timeout).
class PollingTimeoutException extends EsiaAuthException {
  const PollingTimeoutException([
    super.message =
        'Превышено время ожидания обработки авторизации на стороне ЭлЖур.',
    super.cause,
  ]);
}

/// Ошибка ответа API ЭлЖур.
class EljurApiException extends EsiaAuthException {
  final int? statusCode;

  const EljurApiException(
    String message, {
    this.statusCode,
    Object? cause,
  }) : super(message, cause);
}

/// Ошибка парсинга HTML или извлечения необходимых токенов/параметров.
class ParsingException extends EsiaAuthException {
  const ParsingException(super.message, [super.cause]);
}
