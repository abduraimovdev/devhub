import 'package:devhub/devhub.dart';
import 'package:test/test.dart';

void main() {
  group('isAlwaysSend', () {
    test('crash/freeze/login/5xx → true; 4xx/error → false', () {
      expect(isAlwaysSend(LogEvent(type: 'crash', message: '')), isTrue);
      expect(isAlwaysSend(LogEvent(type: 'freeze', message: '')), isTrue);
      expect(isAlwaysSend(LogEvent(type: 'login', message: '')), isTrue);
      expect(
        isAlwaysSend(LogEvent(type: 'api', message: '', statusCode: 500)),
        isTrue,
      );
      expect(
        isAlwaysSend(LogEvent(type: 'api', message: '', statusCode: 404)),
        isFalse,
      );
      expect(isAlwaysSend(LogEvent(type: 'error', message: '')), isFalse);
    });
  });

  group('routeTopic', () {
    final p = Project(
      id: 1,
      label: 'x',
      slug: 'x',
      apiKey: 'k',
      topicLog: 10,
      topicLogin: 20,
    );
    test('login → topicLogin, qolgani → topicLog', () {
      expect(routeTopic(LogEvent(type: 'login', message: ''), p), 20);
      expect(routeTopic(LogEvent(type: 'api', message: ''), p), 10);
      expect(routeTopic(LogEvent(type: 'crash', message: ''), p), 10);
    });
  });

  group('dedupeKey', () {
    test('bir xil → bir xil; endpoint farqi → farqli', () {
      final a = dedupeKey(
        1,
        LogEvent(type: 'api', message: 'x', statusCode: 404, endpoint: '/a'),
      );
      final b = dedupeKey(
        1,
        LogEvent(type: 'api', message: 'x', statusCode: 404, endpoint: '/a'),
      );
      final c = dedupeKey(
        1,
        LogEvent(type: 'api', message: 'x', statusCode: 404, endpoint: '/b'),
      );
      expect(a, b);
      expect(a, isNot(c));
    });
  });

  group('formatLogMessage', () {
    test('status/endpoint chiqadi va maxfiy ma\'lumot scrub qilinadi', () {
      final e = LogEvent(
        type: 'api',
        message: 'failed Bearer abc.def.ghi',
        statusCode: 500,
        endpoint: '/sale',
      );
      final out = formatLogMessage(e);
      expect(out, contains('500'));
      expect(out, contains('/sale'));
      expect(out, isNot(contains('abc.def.ghi')));
    });
  });

  group('LogFilter', () {
    test('alwaysSend har doim yuboriladi', () {
      final f = LogFilter(window: const Duration(seconds: 60));
      final t0 = DateTime(2026);
      expect(f.decide('k', alwaysSend: true, now: t0).send, isTrue);
      expect(
        f
            .decide('k',
                alwaysSend: true, now: t0.add(const Duration(seconds: 1)))
            .send,
        isTrue,
      );
    });

    test('non-always: oyna ichida bostiriladi, keyingi oynada ×N bilan', () {
      final f = LogFilter(window: const Duration(seconds: 60));
      final t0 = DateTime(2026);
      expect(f.decide('k', alwaysSend: false, now: t0).send, isTrue);
      expect(
        f
            .decide('k',
                alwaysSend: false, now: t0.add(const Duration(seconds: 5)))
            .send,
        isFalse,
      );
      expect(
        f
            .decide('k',
                alwaysSend: false, now: t0.add(const Duration(seconds: 10)))
            .send,
        isFalse,
      );
      final next = f.decide(
        'k',
        alwaysSend: false,
        now: t0.add(const Duration(seconds: 61)),
      );
      expect(next.send, isTrue);
      expect(next.suppressedBefore, 2);
    });
  });
}
