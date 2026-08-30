import 'src/cli/cli_args.dart';
import 'src/cli/cli_helper.dart';
import 'src/models/user_credentials.dart';

export 'src/models/user_credentials.dart';

/// Совместимость с предыдущим API
typedef UserData = UserCredentials;

extension UserDataCliExtension on UserCredentials {
  static UserCredentials fillFromCLI() {
    return CliHelper.resolveCredentials(const CliOptions());
  }
}
