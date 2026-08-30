import 'dart:io';
import '../models/auth_result.dart';

final class CliRenderer {
  // ANSI Цвета
  static const _reset = '\x1B[0m';
  static const _bold = '\x1B[1m';
  static const _dim = '\x1B[2m';
  static const _cyan = '\x1B[36m';
  static const _green = '\x1B[32m';
  static const _yellow = '\x1B[33m';
  static const _red = '\x1B[31m';
  static const _magenta = '\x1B[35m';

  /// Отображает приветственный баннер утилиты.
  static void printBanner() {
    stdout.writeln('$_cyan$_bold╔════════════════════════════════════════════════════════════════════╗$_reset');
    stdout.writeln('$_cyan$_bold║                 Eljur Auth Util (ESIA / Госуслуги)                 ║$_reset');
    stdout.writeln('$_cyan$_bold║                 Утилита авторизации для BetterJournal              ║$_reset');
    stdout.writeln('$_cyan$_bold╚════════════════════════════════════════════════════════════════════╝$_reset\n');
  }

  /// Отображает текущий статус/шаг.
  static void printStep(String message) {
    stdout.writeln('$_cyan$_bold➔$_reset $message');
  }

  /// Отображает прогресс поллинга задачи.
  static void printPolling(int attempt, int maxAttempts) {
    stdout.writeln('  $_dim[Попытка $attempt из $maxAttempts] Проверка статуса задачи...$_reset');
  }

  /// Отображает ошибку.
  static void printError(String message, [Object? error]) {
    stderr.writeln('\n$_red$_bold✖ Ошибка: $message$_reset');
    if (error != null && error.toString() != message) {
      stderr.writeln('$_dimПодробности: $error$_reset');
    }
  }

  /// Отображает успешный результат авторизации в консоль.
  static void printSuccess(AuthResult result) {
    stdout.writeln('\n$_green$_bold══════════════════════ [ АВТОРИЗАЦИЯ УСПЕШНА ] ══════════════════════$_reset\n');

    stdout.writeln('$_bold Хост ЭлЖура:$_reset       $_cyan${result.host}$_reset');
    stdout.writeln('$_bold Регион (hash):$_reset     $_yellow${result.region}$_reset');
    stdout.writeln('$_bold ESIA JWT (v_token):$_reset');
    stdout.writeln('  $_dim${result.vToken}$_reset\n');

    if (result.users.isNotEmpty) {
      stdout.writeln('$_bold$_magenta Найдено профилей/школ: ${result.users.length}$_reset');
      stdout.writeln('────────────────────────────────────────────────────────────────────────');

      for (var i = 0; i < result.users.length; i++) {
        final user = result.users[i];
        final num = i + 1;
        stdout.writeln('$_bold[$num] ${user.userTitle}$_reset — ${user.vendorTitle} (${user.vendor})');
        stdout.writeln('    $_boldИтоговый токен (token:vendor):$_reset $_green${user.fullToken}$_reset');
        if (user.expires != null) {
          stdout.writeln('    $_dimСрок действия: ${user.expires}$_reset');
        }
      }
      stdout.writeln('────────────────────────────────────────────────────────────────────────\n');

      final primary = result.primaryUser!;
      stdout.writeln('$_bold$_green Совет по использованию:$_reset');
      stdout.writeln('  • Для вкладки "Токен" используйте:       $_bold${primary.fullToken}$_reset');
      stdout.writeln('  • Для вкладки "ESIA (JWT)" используйте:  v_token + регион (${result.region})');
    } else {
      stdout.writeln('$_yellow Не удалось автоматически получить список пользователей из apiv3/getusersvendors.$_reset');
      stdout.writeln('$_yellow Вы можете использовать ESIA JWT (v_token) и регион для входа в приложение.$_reset');
    }

    stdout.writeln('\n$_green$_bold═════════════════════════════════════════════════════════════════════$_reset\n');
  }
}
