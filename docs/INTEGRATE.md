# 🔌 devhub — yangi loyihani ulash qo'llanmasi

Istalgan loyihani devhub'ga ulab, **crash / xato / API-xato / login** hodisalarini
va **DB backup**'ini Telegram'ga olib chiqish. Flutter, Dart backend yoki
**istalgan til** (raw HTTP) ishlaydi.

> Bir loyiha ~3 daqiqada ulanadi. 30 ta ham, 100 ta ham — bir xil.

---

## 0. Talablar

- devhub **deploy qilingan** (`DEVLOG_URL`, masalan `https://devhub-web.up.railway.app`)
- "Dev Log" Telegram guruhi + bot ishlayapti

---

## 1. Loyihani ro'yxatdan o'tkazish

"Dev Log" guruhida botga yozing:

```
/newproject Qrio
```

Bot quyidagini qaytaradi:
- 3 ta topic ochadi: **Qrio · Log**, **Qrio · Login**, **Qrio · Backup**
- **API key** beradi (masalan `dl_qrio_AbC123...`) — saqlab qo'ying

Bu API key — loyihaning kalitidir. Faqat shu loyiha loglari o'z topiclariga tushadi.

---

## 2. Flutter ilovani ulash

### 2.1 Bog'liqlik (git dependency)

`pubspec.yaml`:

```yaml
dependencies:
  devlog_client:
    git:
      url: https://github.com/abduraimovdev/devhub.git
      path: clients/flutter/devlog_client
      ref: main
```

```bash
flutter pub get
```

> Private repo → `flutter pub get` git-ruxsat talab qiladi (gh / SSH bilan
> kompyuteringizda ishlaydi).

### 2.2 Ishga tushirish (`main.dart`)

```dart
import 'dart:async';
import 'package:devlog_client/devlog_client.dart';
import 'package:flutter/widgets.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  DevLog.init(
    baseUrl: const String.fromEnvironment('DEVLOG_URL'),
    apiKey: const String.fromEnvironment('DEVLOG_API_KEY'),
    appVersion: '1.0.0',
  );

  // Tutilmagan async xatolar uchun:
  runZonedGuarded(() => runApp(const App()), DevLog.zoneError);
}
```

`DevLog.init` **crash hook'larini avtomatik ulaydi** (`FlutterError.onError` +
`PlatformDispatcher.onError`) — Sentry kabi mavjud handlerlarni **buzmaydi**
(zanjirlaydi). API key bo'sh bo'lsa — jim o'chiq turadi.

### 2.3 Crash — avtomatik ✅

Hech narsa qilish shart emas. Tutilmagan xatolar `Log` topic'ga tushadi.

### 2.4 API xatolar (non-2xx)

**Dio bilan:**

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

**Markaziy error-handler bilan** (loyihangizda bitta xato-mapper bo'lsa) — shu
yerda `DevLog.apiError(statusCode: ..., message: ...)` chaqiring.
`200`/`201` avtomatik e'tiborga olinmaydi.

### 2.5 Login eventlari

```dart
DevLog.login(success: true,  phone: '+998901234567'); // telefon maskalanadi
DevLog.login(success: false, phone: phone, context: {'reason': 'PIN'});
```

`login` → **Login** topic'ga tushadi.

### 2.6 Sirlarni berish (build vaqtida)

```bash
flutter build apk --release \
  --dart-define=DEVLOG_URL=https://devhub-web.up.railway.app \
  --dart-define=DEVLOG_API_KEY=dl_qrio_AbC123...
```

> Tamom — Flutter tomoni ulandi. `DEVLOG_API_KEY` bo'sh bo'lsa SDK o'chiq
> (masalan lokal debug'da loglashni xohlamasangiz).

---

## 3. Backend ulash (ixtiyoriy)

Login **urinishlarini** (kim noto'g'ri kirdi) yoki server xatolarini yuborish
uchun. SDK shart emas — oddiy HTTP POST.

### 3.1 Dart / Serverpod

```dart
import 'dart:convert';
import 'dart:io';

Future<void> devlog(Map<String, dynamic> event) async {
  final url = Platform.environment['DEVLOG_URL'] ?? '';
  final key = Platform.environment['DEVLOG_API_KEY'] ?? '';
  if (url.isEmpty || key.isEmpty) return;
  try {
    final c = HttpClient();
    final req = await c.postUrl(Uri.parse('$url/v1/log'));
    req.headers..set('Content-Type', 'application/json')..set('X-Api-Key', key);
    req.add(utf8.encode(jsonEncode(event)));
    await (await req.close()).drain<void>();
    c.close();
  } catch (_) {/* logni bloklamaymiz */}
}

// Foydalanish:
devlog({'type': 'login', 'message': 'login ❌', 'context': {'success': false}});
```

### 3.2 Node.js

```js
await fetch(`${process.env.DEVLOG_URL}/v1/log`, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json', 'X-Api-Key': process.env.DEVLOG_API_KEY },
  body: JSON.stringify({ type: 'api', message: 'failed', context: { statusCode: 500 } }),
}).catch(() => {});
```

---

## 4. DB backup qo'shish

Loyiha DB'sining **public** ulanish manzili bilan, botga:

```
/addbackup qrio postgresql://user:pass@host:port/db
```

Keyingi cron'da (05:00 / 22:00) Qrio DB ham `pg_dump` bo'lib **Qrio · Backup**
topic'ga tushadi (50MB'dan oshsa R2 link).

> Railway DB bo'lsa — **public** (`Connect → Public Network`) manzil kerak,
> ichki `*.railway.internal` emas.

---

## 5. Tekshirish

- Ilovada qasddan xato chiqaring → `<Loyiha> · Log` topic'da ko'rinishi kerak.
- `GET <DEVLOG_URL>/health` → `ok` qaytaradi.
- Backup uchun cron'ni qo'lda ishga tushiring (Railway) yoki keyingi vaqtni
  kuting.

---

## 6. HTTP shartnoma (har qanday til uchun)

SDK ishlatmasangiz, to'g'ridan-to'g'ri shu endpointga POST qiling:

```
POST {DEVLOG_URL}/v1/log
Headers:
  X-Api-Key: <loyiha key'i>
  Content-Type: application/json
Body:
{
  "type": "crash | error | api | freeze | login",
  "message": "qisqa sarlavha",
  "context": { "statusCode": 500, "route": "/sale", "userId": "...", ... },
  "ts": "2026-06-20T17:00:00Z"   // ixtiyoriy
}
```

Javob: **202 Accepted** (fire-and-forget). Ko'p hodisa uchun:
`POST /v1/log/batch` → `{ "events": [ ... ] }`.

**curl misol:**

```bash
curl -X POST "$DEVLOG_URL/v1/log" \
  -H "X-Api-Key: $DEVLOG_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"type":"error","message":"Test xato","context":{"foo":"bar"}}'
```

### Marshrut va filtr

- `type=login` → **Login** topic; qolgani → **Log** topic.
- **Doim yuboriladi:** `crash`, `freeze`, `login`, `api` 5xx.
- **Yig'iladi (anti-flood):** `api` 4xx va umumiy `error` — bir xil hodisa 60s
  oynada bir marta, keyin "×N" bilan.
- Maxfiy ma'lumot (token / parol / connection-string) avtomatik `***` ga
  aylanadi (klientda ham, serverda ham).

---

## 7. Muammolar (troubleshooting)

| Belgi | Sabab / yechim |
|---|---|
| Loglar kelmayapti | `DEVLOG_API_KEY` to'g'rimi? `/health` `ok` beradimi? |
| Web ilova (brauzer) yubormayapti | CORS — devhub'da yoqilgan; `DEVLOG_URL` https bo'lsin |
| `flutter pub get` git xatosi | private repo — `gh auth login` / SSH kalit kerak |
| Backup tushmayapti | DB **public** URL'mi? `pg_dump` versiyasi DB'dan past emasmi? |
| Telegram "too many" | bot rate-limit — anti-flood yig'adi; jiddiy bo'lsa oynani oshiring |

---

### Qisqa eslatma (cheat-sheet)

```
/newproject <Nom>                 → API key + 3 topic
/addbackup <slug> <public_db_url> → backup ro'yxatiga
DevLog.init(baseUrl, apiKey)      → crash avtomatik
DevLog.apiError / login / error   → qo'lda
POST /v1/log  (X-Api-Key)         → istalgan til
```
