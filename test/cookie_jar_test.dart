import 'dart:io';
import 'package:eljur_auth_util/eljur_auth_util.dart';
import 'package:test/test.dart';

void main() {
  group('CookieJar', () {
    late CookieJar cookieJar;

    setUp(() {
      cookieJar = CookieJar();
    });

    test('saves and retrieves cookies for exact domain', () {
      final uri = Uri.parse('https://esia.gosuslugi.ru/login');
      cookieJar.saveCookies(uri, [
        Cookie('acc_t', 'token123'),
        Cookie('session_id', 'sess456'),
      ]);

      final header = cookieJar.getCookieHeader(uri);
      expect(header, contains('acc_t=token123'));
      expect(header, contains('session_id=sess456'));
    });

    test('matches subdomain cookies with parent domain', () {
      final rootUri = Uri.parse('https://gosuslugi.ru');
      final cookie = Cookie('global_val', 'abc')..domain = 'gosuslugi.ru';
      cookieJar.saveCookies(rootUri, [cookie]);

      final subUri = Uri.parse('https://esia.gosuslugi.ru/aas/oauth2/ac');
      final header = cookieJar.getCookieHeader(subUri);
      expect(header, contains('global_val=abc'));
    });

    test('parses raw Set-Cookie strings', () {
      final uri = Uri.parse('https://esia.gosuslugi.ru');
      cookieJar.saveFromRawSetCookie(
        uri,
        'acc_t=jwt_content_here; Path=/; Secure; HttpOnly, user_pref=dark; Path=/',
      );

      final header = cookieJar.getCookieHeader(uri);
      expect(header, contains('acc_t=jwt_content_here'));
      expect(header, contains('user_pref=dark'));
    });

    test('clears cookies', () {
      final uri = Uri.parse('https://school.eljur.ru');
      cookieJar.saveCookies(uri, [Cookie('test', '123')]);
      expect(cookieJar.getCookieHeader(uri), isNotEmpty);

      cookieJar.clear();
      expect(cookieJar.getCookieHeader(uri), isEmpty);
    });
  });
}
