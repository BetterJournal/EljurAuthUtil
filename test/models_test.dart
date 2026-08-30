import 'package:eljur_auth_util/eljur_auth_util.dart';
import 'package:test/test.dart';

void main() {
  group('UserCredentials', () {
    test('normalizes hostnames', () {
      expect(
        UserCredentials.normalizeHost('https://school.eljur.ru/'),
        'school.eljur.ru',
      );
      expect(
        UserCredentials.normalizeHost('http://keo.gov39.ru'),
        'keo.gov39.ru',
      );
      expect(
        UserCredentials.normalizeHost('school29'),
        'school29.eljur.ru',
      );
    });

    test('normalizes logins', () {
      expect(
        UserCredentials.normalizeLogin('8 (900) 123-45-67'),
        '+79001234567',
      );
      expect(
        UserCredentials.normalizeLogin('+79001234567'),
        '+79001234567',
      );
      expect(
        UserCredentials.normalizeLogin('user@example.com'),
        'user@example.com',
      );
      expect(
        UserCredentials.normalizeLogin('123-456-789 00'),
        '123-456-789 00',
      );
    });
  });

  group('AuthResult and VendorUser', () {
    test('formats fullToken as token:vendor', () {
      const user = VendorUser(
        token: 'b3f1c2d4e5a67890abcdef1234567890',
        vendor: 'school29',
        vendorTitle: 'Школа №29',
        userTitle: 'Иванов Иван',
      );

      expect(user.fullToken, 'b3f1c2d4e5a67890abcdef1234567890:school29');
    });

    test('serializes to JSON correctly', () {
      const user = VendorUser(
        token: 'tok123',
        vendor: 'school',
        vendorTitle: 'Школа',
        userTitle: 'Иван',
        expires: '2027-01-01',
      );

      final result = AuthResult(
        vToken: 'vtok_abc',
        region: 'reg_123',
        host: 'school.eljur.ru',
        users: [user],
      );

      final json = result.toJson();
      expect(json['host'], 'school.eljur.ru');
      expect(json['v_token'], 'vtok_abc');
      expect(json['region'], 'reg_123');
      expect(json['users'], hasLength(1));
    });
  });

  group('CliOptions', () {
    test('parses options correctly', () {
      final opts = CliOptions.fromArgs([
        '--host',
        'keo.gov39.ru',
        '-l',
        '+79001234567',
        '-p',
        'pass123!',
        '--json',
      ]);

      expect(opts.host, 'keo.gov39.ru');
      expect(opts.login, '+79001234567');
      expect(opts.password, 'pass123!');
      expect(opts.isJsonOutput, isTrue);
      expect(opts.isHelp, isFalse);
    });

    test('parses help flag', () {
      final opts = CliOptions.fromArgs(['--help']);
      expect(opts.isHelp, isTrue);
    });
  });
}
