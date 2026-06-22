import 'package:devhub/devhub.dart';
import 'package:test/test.dart';

void main() {
  group('backupFileName', () {
    test('label_YYYY-MM-DD_HH-MM.sql.gz (UTC)', () {
      final ts = DateTime.utc(2026, 6, 20, 17, 5);
      expect(backupFileName('pos', ts), 'pos_2026-06-20_17-05.sql.gz');
    });
  });

  group('humanSize', () {
    test('birliklar', () {
      expect(humanSize(512), '512 B');
      expect(humanSize(1536), '1.5 KB');
      expect(humanSize(5 * 1024 * 1024), '5.0 MB');
    });
  });

  group('tailLines', () {
    test('oxirgi N qator', () {
      const text = 'a\nb\nc\nd\ne\nf\ng\nh';
      expect(tailLines(text, 3), 'f\ng\nh');
    });
  });

  group('backupCaption', () {
    test('nom va hajmni o\'z ichiga oladi', () {
      final out = backupCaption('sozly', DateTime.utc(2026, 1, 1), 2048);
      expect(out, contains('sozly'));
      expect(out, contains('2.0 KB'));
    });
  });

  group('BackupRunner.targetsFromEnv', () {
    test('label=url qatorlarini parslaydi, # va bo\'shni tashlaydi', () {
      const env = '''
# izoh
pos=postgresql://u:p@h:5432/pos

sozly=postgresql://u:p@h:5432/sozly
noto'g'ri-qator
''';
      final targets = BackupRunner.targetsFromEnv(env, backupTopicId: 7);
      expect(targets.length, 2);
      expect(targets[0].name, 'pos');
      expect(targets[0].dbUrl, 'postgresql://u:p@h:5432/pos');
      expect(targets[0].topicBackup, 7);
      expect(targets[1].name, 'sozly');
    });

    test('bo\'sh env → bo\'sh ro\'yxat', () {
      expect(BackupRunner.targetsFromEnv(null), isEmpty);
      expect(BackupRunner.targetsFromEnv('   '), isEmpty);
    });
  });

  group('R2Uploader.signingKey (AWS SigV4 rasmiy test-vektori)', () {
    test('AWS docs derivation namunasiga mos', () {
      final key = R2Uploader.signingKey(
        'wJalrXUtnFEMI/K7MDENG+bPxRfiCYEXAMPLEKEY',
        '20120215',
        'us-east-1',
        'iam',
      );
      final hex = key.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      expect(
        hex,
        'f4780e2d9f65fa895f9c67b32ce1baf0b0d8a43505a000a1a9e090d414db404d',
      );
    });
  });

  group('R2Uploader.amzTimestamp', () {
    test('YYYYMMDDTHHMMSSZ', () {
      expect(
        R2Uploader.amzTimestamp(DateTime.utc(2026, 6, 20, 17, 0, 5)),
        '20260620T170005Z',
      );
    });
  });
}
