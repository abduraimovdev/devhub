import 'dart:math';

import 'package:devhub/devhub.dart';
import 'package:test/test.dart';

void main() {
  group('slugify', () {
    test('bo\'shliq va belgilarni - ga aylantiradi', () {
      expect(slugify('Dozone POS'), 'dozone-pos');
      expect(slugify('Qrio!!!'), 'qrio');
      expect(slugify('  Sozly  App '), 'sozly-app');
    });

    test('bo\'sh → project', () {
      expect(slugify('---'), 'project');
      expect(slugify(''), 'project');
    });
  });

  group('generateApiKey', () {
    test('dl_<slug>_ prefiksi + token', () {
      final key = generateApiKey('dozone-pos', random: Random(42));
      expect(key, startsWith('dl_dozone-pos_'));
      expect(key.length, greaterThan('dl_dozone-pos_'.length + 10));
    });

    test('= belgisi yo\'q (URL-safe)', () {
      expect(generateApiKey('x', random: Random(1)), isNot(contains('=')));
    });
  });
}
