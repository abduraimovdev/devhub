# 00 · Umumiy ko'rinish (Overview)

## Muammo

1. **Loglar tarqoq.** Dozone POS/Business/Admin (va kelajakda Qrio, Sozly...) da crash, API xato (4xx/5xx), qotish (freeze), login hodisalari bor — lekin ularni bitta joyda real-time ko'rish yo'q.
2. **Backuplar Railwayga bog'liq.** Railway'ning pullik backup'iga bog'lanib qolmaslik kerak; to'lov/xizmat uzilsa ham ma'lumot **Railwaydan tashqarida** (Telegramda / R2'da) saqlanishi shart.

## Yechim

Bitta **devhub** servisi — har ikkala ehtiyojni qoplaydi, chunki ikkalasining ham yadrosi bir xil: **rejaga/hodisaga ko'ra ishlaydi va natijani Telegram'ga yuboradi**.

- **A · Log ingest** (doimiy web): ilovalar HTTP orqali log yuboradi → filtr/dedupe/scrub → tegishli topic.
- **B · DB backup** (cron): barcha DB'larni `pg_dump` → gzip → Telegram fayl (yoki R2 link).

Har loyiha Telegram forum guruhida **3 ta topic**ga ega: `Log`, `Login`, `Backup`.

## Asosiy talab: oson va miqyoslanadigan ulash

Yangi loyiha qo'shish **kod o'zgartirishsiz, redeploy'siz** bo'lishi kerak — 30 ta ham, 100 ta ham. Buning uchun:
- Loyihalar **registr** (Postgres) da saqlanadi.
- Bot buyrug'i **`/newproject <label>`** → 3 topic avtomatik ochiladi (`createForumTopic`) + API key generatsiya qilinadi + registrga yoziladi. ~10 soniya.

## Locked qarorlar (egasi tasdiqlagan)

| Mavzu | Qaror |
|---|---|
| Stack | Dart · `shelf` · `televerse` · `postgres` · `http` |
| Deploy | 1 repo → 2 Railway servisi (web + cron), bir xil image |
| Registr / ulash | Postgres + `/newproject` bot buyrug'i |
| Topiclar | har loyiha 3 ta: Log / Login / Backup |
| Log filtri | 5xx+crash+freeze+login doim; 4xx yig'ib |
| Backup jadval | `0 0,17 * * *` UTC (05:00 / 22:00 Toshkent) |
| Backup fayl | Telegram → bo'lmasa R2+link → bo'lmasa ❌ xato |
| Sentry | iste'molchilarda saqlanadi (devhub uni almashtirmaydi) |

## Bo'lmaydigan narsalar (non-goals)

- Stack-trace qidiruv/guruhlash UI'si — buni **Sentry** qiladi (devhub real-time bildirishnoma).
- Metrika/dashboard (CPU, RPS) — bu monitoring emas, log+backup yetkazish servisi.
- Ilovalarning o'ziga bot tokenini bermaymiz — loglar **server orqali** o'tadi (xavfsizlik + marshrut + scrub).
