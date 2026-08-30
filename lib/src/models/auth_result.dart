import 'dart:convert';

/// Пользователь/вендор, привязанный к аккаунту в ЭлЖур.
final class VendorUser {
  final String token;
  final String vendor;
  final String vendorTitle;
  final String userTitle;
  final String? expires;

  const VendorUser({
    required this.token,
    required this.vendor,
    required this.vendorTitle,
    required this.userTitle,
    this.expires,
  });

  /// Формат токена для использования в API ЭлЖура (token:vendor).
  String get fullToken => '$token:$vendor';

  factory VendorUser.fromJson(Map<String, dynamic> json) {
    return VendorUser(
      token: (json['token'] ?? '').toString(),
      vendor: (json['vendor'] ?? '').toString(),
      vendorTitle: (json['vendor_title'] ?? json['vendor'] ?? '').toString(),
      userTitle: (json['user_title'] ?? '').toString(),
      expires: json['expires']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'token': token,
        'vendor': vendor,
        'vendor_title': vendorTitle,
        'user_title': userTitle,
        'expires': expires,
        'full_token': fullToken,
      };

  @override
  String toString() =>
      'VendorUser($userTitle, $vendorTitle, fullToken: $fullToken, expires: $expires)';
}

/// Итоговый результат авторизации через ESIA в ЭлЖур.
final class AuthResult {
  /// JWT токен ESIA (v_token).
  final String vToken;

  /// Хэш региона.
  final String region;

  /// Домен/хост ЭлЖура, для которого была произведена авторизация.
  final String host;

  /// Список доступных пользователей и школ (вендоров).
  final List<VendorUser> users;

  const AuthResult({
    required this.vToken,
    required this.region,
    required this.host,
    this.users = const [],
  });

  /// Главный токен первой учетной записи (если есть).
  VendorUser? get primaryUser => users.isNotEmpty ? users.first : null;

  Map<String, dynamic> toJson() => {
        'host': host,
        'v_token': vToken,
        'region': region,
        'users': users.map((u) => u.toJson()).toList(),
      };

  String toPrettyJson() => const JsonEncoder.withIndent('  ').convert(toJson());

  @override
  String toString() =>
      'AuthResult(host: $host, region: $region, users: ${users.length})';
}
