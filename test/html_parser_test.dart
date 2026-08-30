import 'package:test/test.dart';

void main() {
  group('HTML and Parameter Parsers', () {
    test('extracts form action and code from ESIA redirect HTML', () {
      const html = '''
<html>
  <head><title>Redirect</title></head>
  <body>
    <form action="https://school.eljur.ru/journal-esia-action/action.validate" method="POST">
      <input name="code" value="esia_auth_code_xyz123_random" />
    </form>
  </body>
</html>
''';

      final formMatch = RegExp(
        r'<form[^>]+action="([^"]+)"|<form[^>]+action=\x27([^\x27]+)\x27',
        caseSensitive: false,
      ).firstMatch(html);
      expect(formMatch?.group(1) ?? formMatch?.group(2),
          'https://school.eljur.ru/journal-esia-action/action.validate');

      final codeMatch = RegExp(
        r'<input[^>]+name="code"[^>]+value="([^"]+)"|<input[^>]+name=\x27code\x27[^>]+value=\x27([^\x27]+)\x27',
        caseSensitive: false,
      ).firstMatch(html);
      expect(codeMatch?.group(1) ?? codeMatch?.group(2), 'esia_auth_code_xyz123_random');
    });

    test('extracts form code when attributes are in reverse order', () {
      const html = '''
    <form action="/journal-esia-action/action.validate">
      <input type="hidden" value="secret_code_789" name="code"/>
    </form>
''';
      final codeMatch = RegExp(
        r'<input[^>]+value="([^"]+)"[^>]+name="code"|<input[^>]+value=\x27([^\x27]+)\x27[^>]+name=\x27code\x27',
        caseSensitive: false,
      ).firstMatch(html);
      expect(codeMatch?.group(1) ?? codeMatch?.group(2), 'secret_code_789');
    });

    test('extracts esiaTaskId from script tags', () {
      const html = '''
<html>
  <script>
    var esiaTaskId = "task_9a8b7c6d5e4f";
  </script>
</html>
''';
      final match = RegExp(
        r'esiaTaskId\s*=\s*"([^"]+)"|esiaTaskId\s*=\s*\x27([^\x27]+)\x27',
        caseSensitive: false,
      ).firstMatch(html);
      expect(match?.group(1) ?? match?.group(2), 'task_9a8b7c6d5e4f');
    });

    test('extracts region hash from link', () {
      const link1 =
          '/journal-esia-region-action/redirect?region=c4ca4238a0b923820dcc509a6f75849b&token=xyz';
      final uri = Uri.parse(link1);
      expect(uri.queryParameters['region'], 'c4ca4238a0b923820dcc509a6f75849b');

      const link2 = '/journal-esia-region-action/redirect?region.c4ca4238a0b923820dcc509a6f75849b';
      final match = RegExp(r'region[=\.]([a-f0-9]{16,64})', caseSensitive: false)
          .firstMatch(link2);
      expect(match?.group(1), 'c4ca4238a0b923820dcc509a6f75849b');
    });

    test('extracts v_token from Location header', () {
      const loc =
          '/journal-app?v_token=eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.payload.sig';
      final uri = Uri.parse(loc);
      expect(uri.queryParameters['v_token'],
          'eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.payload.sig');
    });
  });
}
