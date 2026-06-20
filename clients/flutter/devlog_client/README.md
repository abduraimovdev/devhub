# devlog_client

devhub log ingest klienti — crash / API xato / freeze / login ni tutib
`POST /v1/log` orqali devhub'ga yuboradi. UI'ni bloklamaydi, offline navbat,
klient tomonda ham scrub.

## Ulash (git-dependency)

Har qanday loyiha (Dozone, Qrio, Sozly...) `pubspec.yaml` ga:

```yaml
dependencies:
  devlog_client:
    git:
      url: https://github.com/<you>/devhub.git
      path: clients/flutter/devlog_client
      ref: main
```

## Ishlatish

`main.dart`:

```dart
import 'dart:async';
import 'package:devlog_client/devlog_client.dart';
import 'package:flutter/widgets.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  DevLog.init(
    baseUrl: 'https://devhub-web.up.railway.app',
    apiKey: const String.fromEnvironment('DEVLOG_API_KEY'), // /newproject bergan key
    appVersion: '1.0.0+4',
  );
  // Tutilmagan async xatolar uchun:
  runZonedGuarded(() => runApp(const App()), DevLog.zoneError);
}
```

`DevLog.init` `FlutterError.onError` va `PlatformDispatcher.onError` ni avtomatik
ulaydi (crash). Qolganlari qo'lda:

```dart
DevLog.error('Savatni saqlashda xato', context: {'cartId': id});
DevLog.login(success: true, phone: '+998901234567'); // telefon maskalanadi
```

### API xatolar (Dio interceptor namunasi)

```dart
dio.interceptors.add(InterceptorsWrapper(
  onError: (e, handler) {
    final r = e.response;
    if (r != null) {
      DevLog.apiError(
        statusCode: r.statusCode ?? 0,
        method: e.requestOptions.method,
        url: e.requestOptions.uri.toString(),
      );
    }
    handler.next(e);
  },
));
```

Serverpod/`http` uchun ham xuddi shunday — non-2xx javobda `DevLog.apiError(...)`.

## Xulq

- **Fire-and-forget**: hodisalar xotira navbatiga tushadi, har 3s da batch
  yuboriladi. Tarmoq yo'q bo'lsa navbatda qoladi (max 200, eng eskisi tashlanadi).
- **Scrub**: token/parol/connection-string yuborishdan oldin `***` ga aylanadi.
- **200/201** API javoblari yuborilmaydi (faqat xato statuslar).

> Eslatma: hozircha navbat **xotirada** (ilova qayta ishga tushsa yo'qoladi).
> Doimiy (disk) navbat — keyingi yaxshilanish.
