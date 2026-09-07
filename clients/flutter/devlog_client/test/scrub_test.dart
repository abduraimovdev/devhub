import 'package:devlog_client/devlog_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('scrubText', () {
    test('Bearer va connection-string maskalanadi, parol/telefon qoladi', () {
      expect(scrubText('Bearer abc.def.ghi'), isNot(contains('abc.def.ghi')));
      expect(scrubText('{"password":"hunter2"}'), contains('hunter2'));
      final conn = scrubText('postgresql://u:s3cr3t@h:5432/db');
      expect(conn, contains('u:***@'));
      expect(conn, isNot(contains('s3cr3t')));
    });

    test('oddiy matn o\'zgarmaydi', () {
      expect(scrubText('Sotuv bo\'ldi'), 'Sotuv bo\'ldi');
    });
  });

  group('maskPhone', () {
    test('telefon raqami to\'liq saqlanadi', () {
      expect(maskPhone('+998901234567'), '+998901234567');
    });
  });

  group('DevLogEvent.scrubbed', () {
    test('token maskalanadi, lekin telefon/parol saqlanadi', () {
      final e = DevLogEvent(
        type: 'error',
        message: 'secret_token=abc123 phone=+998901234567',
        context: {'auth': 'Bearer xyz', 'phone': '+998901234567'},
      );
      final s = e.scrubbed();
      expect(s.context['auth'], isNot(contains('xyz')));
      expect(s.context['phone'], '+998901234567');
    });
  });
}
