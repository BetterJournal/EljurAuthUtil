import 'dart:io';
import 'package:eljur_auth_util/eljur_auth_util.dart';

const appVersion = '1.0.0';

Future<void> main(List<String> args) async {
  CliOptions options;
  try {
    options = CliOptions.fromArgs(args);
  } catch (e) {
    stderr.writeln('Ошибка аргументов: $e\n');
    stderr.writeln('Использование:');
    stderr.writeln(CliOptions.usage);
    exit(1);
  }

  if (options.isHelp) {
    stdout.writeln('Утилита авторизации в ЭлЖур через Госуслуги (ESIA).\n');
    stdout.writeln('Использование: dart run bin/eljur_auth_util.dart [опции]\n');
    stdout.writeln('Опции:');
    stdout.writeln(CliOptions.usage);
    exit(0);
  }

  if (options.isVersion) {
    stdout.writeln('eljur_auth_util версия $appVersion');
    exit(0);
  }

  if (!options.isJsonOutput) {
    CliRenderer.printBanner();
  }

  int exitCode = 0;

  try {
    final credentials = CliHelper.resolveCredentials(options);
    final authService = EsiaAuthService();

    final result = await authService.authenticate(
      credentials: credentials,
      onStep: (step) {
        if (!options.isJsonOutput) {
          CliRenderer.printStep(step);
        }
      },
      onPolling: (attempt, maxAttempts) {
        if (!options.isJsonOutput) {
          CliRenderer.printPolling(attempt, maxAttempts);
        }
      },
      onMfaRequired: (mfaInfo) async {
        return CliHelper.getMfaCode(mfaInfo);
      },
    );

    if (options.isJsonOutput) {
      stdout.writeln(result.toPrettyJson());
    } else {
      CliRenderer.printSuccess(result);
    }
  } on EsiaAuthException catch (e) {
    exitCode = 1;
    if (options.isJsonOutput) {
      stderr.writeln('{"error": "${e.message}"}');
    } else {
      CliRenderer.printError(e.message, e.cause);
    }
  } catch (e, stack) {
    exitCode = 1;
    if (options.isJsonOutput) {
      stderr.writeln('{"error": "$e"}');
    } else {
      CliRenderer.printError('Непредвиденная ошибка: $e', stack);
    }
  } finally {
    if (!options.isJsonOutput) {
      stdout.writeln('Нажмите Enter для выхода...');
      try {
        stdin.readLineSync();
      } catch (_) {}
    }
    if (exitCode != 0) {
      exit(exitCode);
    }
  }
}
