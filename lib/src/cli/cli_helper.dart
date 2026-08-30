import 'package:interact/interact.dart';
import '../models/mfa_info.dart';
import '../models/user_credentials.dart';
import 'cli_args.dart';

final phoneRegex = RegExp(r'^\+?[78]?\d{10}$');
final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
final snilsRegex = RegExp(r'^\d{3}-?\d{3}-?\d{3}\s?\d{2}$');

final class CliHelper {
  /// Запрашивает у пользователя хост ЭлЖура (если не передан в аргументах).
  static String getAuthHost({String? initial}) {
    if (initial != null && initial.trim().isNotEmpty) {
      return UserCredentials.normalizeHost(initial);
    }

    final raw = Input(
      prompt:
          'Введите хост для авторизации (например: school.eljur.ru или keo.gov39.ru)',
      validator: (v) {
        final val = v.trim();
        if (val.isEmpty) {
          throw ValidationError('Хост не может быть пустым.');
        }
        return true;
      },
    ).interact();

    return UserCredentials.normalizeHost(raw);
  }

  /// Запрашивает у пользователя логин для Госуслуг (если не передан в аргументах).
  static String getLogin({String? initial}) {
    if (initial != null && initial.trim().isNotEmpty) {
      return UserCredentials.normalizeLogin(initial);
    }

    final raw = Input(
      prompt: 'Введите ваш логин для Госуслуг (телефон / email / СНИЛС)',
      validator: (v) {
        final val = v.trim();
        if (val.isEmpty) {
          throw ValidationError('Логин не может быть пустым.');
        }
        final cleaned = val.replaceAll(RegExp(r'[\s\-]'), '');
        final isPhone = phoneRegex.hasMatch(cleaned) || phoneRegex.hasMatch(val);
        final isEmail = emailRegex.hasMatch(val);
        final isSnils = snilsRegex.hasMatch(val) || (cleaned.length == 11 && RegExp(r'^\d{11}$').hasMatch(cleaned));

        if (!isPhone && !isEmail && !isSnils) {
          throw ValidationError(
            'Логин должен быть в одном из форматов: телефон (+7XXXXXXXXXX), email или СНИЛС (XXX-XXX-XXX XX)',
          );
        }
        return true;
      },
    ).interact();

    return UserCredentials.normalizeLogin(raw);
  }

  /// Запрашивает у пользователя пароль для Госуслуг с маскированием ввода.
  static String getPassword({String? initial}) {
    if (initial != null && initial.isNotEmpty) {
      return initial;
    }

    return Password(
      prompt: 'Введите ваш пароль для Госуслуг',
      confirmation: false,
    ).interact();
  }

  /// Запрашивает у пользователя код двухфакторной аутентификации.
  static String getMfaCode(MfaInfo mfaInfo) {
    final prompt = switch (mfaInfo.type) {
      MfaType.sms =>
        'Введите СМС-код подтверждения${mfaInfo.phoneNumberHint != null ? " (на номер ${mfaInfo.phoneNumberHint})" : ""}',
      MfaType.ttp =>
        'Введите 6-значный код из приложения-аутентификатора (TOTP)',
      MfaType.unknown => 'Введите код подтверждения двухфакторной аутентификации',
    };

    return Input(
      prompt: prompt,
      validator: (v) {
        final val = v.trim();
        if (val.isEmpty) {
          throw ValidationError('Код подтверждения не может быть пустым.');
        }
        return true;
      },
    ).interact().trim();
  }

  /// Собирает UserCredentials из CliOptions и интерактивного ввода.
  static UserCredentials resolveCredentials(CliOptions options) {
    final host = getAuthHost(initial: options.host);
    final login = getLogin(initial: options.login);
    final password = getPassword(initial: options.password);

    return UserCredentials.create(
      eljurHost: host,
      login: login,
      password: password,
    );
  }
}
