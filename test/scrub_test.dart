import 'package:devhub/devhub.dart';
import 'package:test/test.dart';

void main() {
  group('Scrub.text', () {
    test('Bearer token maskalanadi', () {
      final out = Scrub.text('Authorization: Bearer abc.def.ghi123');
      expect(out, isNot(contains('abc.def.ghi123')));
      expect(out, contains('***'));
    });

    test('connection-string paroli maskalanadi', () {
      final out = Scrub.text('postgresql://user:s3cr3t@host:5432/db');
      expect(out, contains('://user:***@'));
      expect(out, isNot(contains('s3cr3t')));
    });

    test('password=... maskalanadi', () {
      expect(Scrub.text('{"password":"hunter2"}'), isNot(contains('hunter2')));
    });

    test('oddiy matn o\'zgarmaydi', () {
      expect(Scrub.text('Savdo yakunlandi'), 'Savdo yakunlandi');
    });
  });

  group('Scrub.phone', () {
    test("o'rtasini yashiradi", () {
      expect(Scrub.phone('+998901234567'), '+99890***4567');
    });

    test('juda qisqa raqam o\'zgarmaydi', () {
      expect(Scrub.phone('12345'), '12345');
    });
  });
}
