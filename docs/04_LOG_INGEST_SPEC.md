# 04 · Log ingest spec (Vazifa A)

## HTTP shartnoma

Ilovalar (yoki backendlar) shu yagona endpointga POST qiladi:

```
POST /v1/log
Headers:
  X-Api-Key: <loyiha API key'i>          (registrdan)
  Content-Type: application/json
Body:
{
  "type":    "crash" | "error" | "api" | "freeze" | "login",
  "level":   "info" | "warning" | "error" | "fatal",   (ixtiyoriy; type'dan kelib chiqadi)
  "message": "qisqa sarlavha",
  "context": { ... }   (ixtiyoriy: route, statusCode, method, url, durationMs, stack, device, appVersion, userId ...)
  "ts":      "2026-06-20T17:00:00Z"   (ixtiyoriy; server qo'yadi)
}
```

Javob: `202 Accepted` (fire-and-forget). Xato bo'lsa ham ilova **bloklanmaydi** — klient SDK fonda yuboradi.

Batch variant: `POST /v1/log/batch` — `{ "events": [ ... ] }` (offline navbat flush uchun).

## Topic marshruti

- `type == "login"` → loyihaning **Login** topic'i.
- qolgan hammasi (crash/error/api/freeze) → loyihaning **Log** topic'i.

## Smart filtr (anti-flood) — locked

| Hodisa | Harakat |
|---|---|
| `crash`, `freeze`, `login` | **DOIM** yuboriladi |
| API `5xx` | **DOIM** yuboriladi |
| API `4xx` (401/403/404/422...) | **yig'iladi** — bir xil (loyiha+endpoint+status) oynada (masalan 1 daqiqa) bir marta "×N marta" bilan |
| `error` (umumiy) | dedupe: bir xil xabar+stack oynada bir marta + hisob |

Dedupe kaliti: `hash(project + type + endpoint/route + statusCode + message[:120])`. Telegram `429` kelsa — backoff bilan qayta urinish.

## Maxfiylik (scrub)

Yuborishdan oldin `lib/src/core/scrub.dart`:
- `Authorization` header, `Bearer <...>`, `token`, `apiKey`, `password`, `pin`, `secret` qiymatlari → `***`.
- DB connection-string parollari → `***`.
- Kerak bo'lsa userId'ni saqlaymiz (kim), lekin PII'ni minimallashtiramiz.

## Klient SDK (iste'molchi ilovalarda — Phase 4/5)

Flutter ilovalarga kichik `devlog_client` (yoki mavjud logger'ga hook). Tutadi:
- **Crash:** `FlutterError.onError` + `PlatformDispatcher.instance.onError` + `runZonedGuarded`.
- **API xato:** Dio/Serverpod interceptor — non-2xx javoblar (status, method, url, durationMs).
- **Login:** `DevLog.login(success, phone, ...)` — yoki ishonchliroq, **backend**'dan (server haqiqiy natijani biladi).
- **Freeze (ixtiyoriy):** kadr vaqti > N ms watchdog yoki heartbeat.

Talablar: **UI bloklanmaydi** (fire-and-forget), **offline navbat** (Hive/fayl) → online bo'lganda flush, **scrub** klientda ham, **batch** + backoff.

## Login topic — nima ko'rsatadi

- Kim login qildi: telefon (maskalangan, masalan `+99890***4567`), vaqt, qurilma/platforma, natija ✅.
- Login **urinishi** (muvaffaqiyatsiz) ham: telefon + sabab (noto'g'ri OTP/PIN) + IP (server'dan) → ❌. Bu eng ishonchli **backend** auth endpoint'dan yuboriladi.
