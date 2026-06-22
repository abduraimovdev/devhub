import 'package:devlog_client/devlog_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('scrubText', () {
    test('Bearer / parol / connection-string maskalanadi', () {
      expect(scrubText('Bearer abc.def.ghi'), isNot(contains('abc.def.ghi')));
      expect(scrubText('{"password":"hunter2"}'), isNot(contains('hunter2')));
      final conn = scrubText('postgresql://u:s3cr3t@h:5432/db');
      expect(conn, contains('u:***@'));
      expect(conn, isNot(contains('s3cr3t')));
    });

    test('oddiy matn o\'zgarmaydi', () {
      expect(scrubText('Sotuv bo\'ldi'), 'Sotuv bo\'ldi');
    });
  });

  group('maskPhone', () {
    test('o\'rtasini yashiradi', () {
      expect(maskPhone('+998901234567'), '+99890***4567');
    });
  });

  group('DevLogEvent.scrubbed', () {
    test('message va string context maskalanadi', () {
      final e = DevLogEvent(
        type: 'error',
        message: 'token=abc123',
        context: {'auth': 'Bearer xyz', 'count': 5},
      );
      final s = e.scrubbed();
      expect(s.message, isNot(contains('abc123')));
      expect(s.context['auth'], isNot(contains('xyz')));
      expect(s.context['count'], 5);
    });
  });
}
