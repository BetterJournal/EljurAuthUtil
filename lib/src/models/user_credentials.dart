/// Учетные данные пользователя для авторизации в ЭлЖур через Госуслуги.
final class UserCredentials {
  final String eljurHost;
  final String login;
  final String password;

  const UserCredentials({
    required this.eljurHost,
    required this.login,
    required this.password,
  });

  /// Нормализует хост (удаляет протокол, завершающие слэши и пробелы).
  static String normalizeHost(String rawHost) {
    var host = rawHost.trim().toLowerCase();
    if (host.startsWith('http://')) {
      host = host.substring(7);
    } else if (host.startsWith('https://')) {
      host = host.substring(8);
    }
    if (host.endsWith('/')) {
      host = host.substring(0, host.length - 1);
    }
    // Если введено только название школы без домена (например "school29")
    if (!host.contains('.')) {
      host = '$host.eljur.ru';
    }
    return host;
  }

  /// Нормализует логин (телефон, email, СНИЛС).
  static String normalizeLogin(String rawLogin) {
    final trimmed = rawLogin.trim();
    // Если введен номер с 8 в начале (+7...)
    final digitsOnly = trimmed.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.length == 11 && (digitsOnly.startsWith('7') || digitsOnly.startsWith('8'))) {
      return '+7${digitsOnly.substring(1)}';
    }
    return trimmed;
  }

  factory UserCredentials.create({
    required String eljurHost,
    required String login,
    required String password,
  }) {
    return UserCredentials(
      eljurHost: normalizeHost(eljurHost),
      login: normalizeLogin(login),
      password: password,
    );
  }

  @override
  String toString() => 'UserCredentials(host: $eljurHost, login: $login)';
}
