import 'package:args/args.dart';

/// Конфигурация запуска CLI утилиты из аргументов командной строки.
final class CliOptions {
  final String? host;
  final String? login;
  final String? password;
  final bool isJsonOutput;
  final bool isHelp;
  final bool isVersion;

  const CliOptions({
    this.host,
    this.login,
    this.password,
    this.isJsonOutput = false,
    this.isHelp = false,
    this.isVersion = false,
  });

  static final ArgParser parser = ArgParser()
    ..addOption(
      'host',
      abbr: 'H',
      help: 'Хост школы в ЭлЖур (например: school.eljur.ru или keo.gov39.ru)',
    )
    ..addOption(
      'login',
      abbr: 'l',
      help: 'Логин для входа в Госуслуги (телефон, email или СНИЛС)',
    )
    ..addOption(
      'password',
      abbr: 'p',
      help: 'Пароль для входа в Госуслуги',
    )
    ..addFlag(
      'json',
      abbr: 'j',
      negatable: false,
      help: 'Вывести итоговый результат в формате JSON',
    )
    ..addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Показать справку по использованию утилиты',
    )
    ..addFlag(
      'version',
      abbr: 'v',
      negatable: false,
      help: 'Показать версию утилиты',
    );

  factory CliOptions.fromArgs(List<String> args) {
    try {
      final results = parser.parse(args);
      return CliOptions(
        host: results['host'] as String?,
        login: results['login'] as String?,
        password: results['password'] as String?,
        isJsonOutput: results['json'] as bool,
        isHelp: results['help'] as bool,
        isVersion: results['version'] as bool,
      );
    } on FormatException catch (e) {
      throw ArgumentError(e.message);
    }
  }

  static String get usage => parser.usage;
}
