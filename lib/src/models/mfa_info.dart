/// Тип двухфакторной аутентификации ESIA.
enum MfaType {
  sms('SMS', 'otp', 'СМС-код'),
  ttp('TTP', 'totp', 'Код из приложения-аутентификатора (TOTP)'),
  unknown('UNKNOWN', 'totp', 'Код подтверждения');

  /// Код типа в ответе ЕСИА (например: "SMS" или "TTP").
  final String code;

  /// Путь в API ЕСИА для верификации (например: "otp" или "totp").
  final String apiPath;

  /// Человекочитаемое описание.
  final String description;

  const MfaType(this.code, this.apiPath, this.description);

  static MfaType fromString(String? type) {
    if (type == null) return MfaType.unknown;
    final upper = type.toUpperCase();
    if (upper == 'SMS' || upper == 'OTP') return MfaType.sms;
    if (upper == 'TTP' || upper == 'TOTP') return MfaType.ttp;
    return MfaType.unknown;
  }
}

/// Информация о требуемом шаге двухфакторной аутентификации.
final class MfaInfo {
  final MfaType type;
  final String? phoneNumberHint;
  final Map<String, dynamic> rawDetails;

  const MfaInfo({
    required this.type,
    this.phoneNumberHint,
    this.rawDetails = const {},
  });

  factory MfaInfo.fromJson(Map<String, dynamic> json) {
    final details = json['mfa_details'] as Map<String, dynamic>? ?? {};
    final typeStr = details['type'] as String?;
    final phone = details['phone'] as String?;

    return MfaInfo(
      type: MfaType.fromString(typeStr),
      phoneNumberHint: phone,
      rawDetails: details,
    );
  }
}
