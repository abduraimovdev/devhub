# CLAUDE.md

Bu fayl Claude Code'ga (claude.ai/code) ushbu repozitoriyda ishlashda yo'l-yo'riq beradi. Ko'rsatmalar majburiy — aniq bajaring.

## Loyiha nima

**devhub** — ko'p loyihali (multi-project) DevOps Telegram servisi. Bitta umumiy yadro, ikki vazifa:

- **A · Log ingest** — ilovalardan real-time xato/crash/freeze/login keladi (HTTP push) va Telegram topic'ga yo'naltiriladi. **Doimiy ishlaydigan** web servis.
- **B · DB backup** — Railway'dagi barcha Postgres DB'lar `pg_dump` qilinib, Telegram'ga (yoki R2'ga) yuboriladi. **Cron** — uyg'onib ishlab-o'chadi.

Maqsad: bitta servis 30+ loyihaga **redeploy'siz** ulanadi (bot buyrug'i bilan). Dozone (POS/Business/Admin), Qrio, Sozly va boshqalar uchun umumiy.

> Bu — Dozone'ning `dozone_pos` repozitoriyasidan **alohida**, mustaqil loyiha. Dozone backend/ilovalari faqat **iste'molchi** (log yuboradi, backup qilinadi).

## Hujjat — haqiqat manbai

Barcha dizayn qarorlari `docs/` ichidagi raqamli fayllarda. Kod va hujjat ziddiyatga tushsa — **hujjat ustun**. Yangi sessiyada shu tartibda o'qing:

1. `docs/00_OVERVIEW.md` — nima/nega, locked qarorlar
2. `docs/01_ARCHITECTURE.md` — 2 runtime, umumiy yadro, repo tuzilishi
3. `docs/02_TELEGRAM_SETUP.md` — guruh, topiclar, bot, `/newproject`
4. `docs/03_BACKUP_SPEC.md` — backup pipeline + fallback zanjiri
5. `docs/04_LOG_INGEST_SPEC.md` — HTTP shartnoma, smart filtr, klient SDK
6. `docs/05_REGISTRY_SCHEMA.md` — projects/topics jadvallari
7. `docs/06_DEPLOY_RAILWAY.md` — 2 servis, cron, env
8. `docs/07_ONBOARD_PROJECT.md` — yangi loyihani ulash (Windows-friendly)

## Locked qarorlar (o'zgartirmang — egasi tasdiqlagan)

- **Til/stack:** server-side **Dart**, `shelf` (+`shelf_router`) web uchun, `televerse` bot uchun, `postgres` registr uchun, `http` oddiy yuborish uchun.
- **Deploy:** **1 repo → 2 Railway servisi** (bir xil image, har xil entrypoint): `bin/ingest_server.dart` (web, doimiy) va `bin/backup.dart` (cron, ephemeral).
- **Registr:** Postgres jadval. Ulash — bot buyrug'i **`/newproject <label>`** (avto `createForumTopic` + API key + registr yozuvi). Kod o'zgartirilmaydi.
- **Topiclar:** har loyiha **3 ta** — `Log` / `Login` / `Backup`.
- **Log filtri (anti-flood):** `5xx` + crash + freeze + login = **doim**; `4xx` (401/404 va h.k.) = **yig'ib** ("×N marta").
- **Backup jadval:** cron `0 0,17 * * *` (UTC) = 05:00 va 22:00 Toshkent.
- **Backup fayl yuborish (zanjirli fallback):** `sendDocument` (topic) → bo'lmasa **R2 + link** → u ham xato bersa **❌ xato xabari**.
- **Sentry:** iste'molchi ilovalarda Sentry SAQLANADI (chuqur saqlash); devhub — Telegram real-time qatlami. Biri ikkinchisini almashtirmaydi.
- **Image:** Dart AOT exe (`dart compile exe`) glibc talab qiladi → runtime base **`postgres:17`** (Debian, `-alpine` EMAS — musl mos kelmaydi). Sabab: docs/06.

## Maxfiylik / xavfsizlik

- Sirlar (`BOT_TOKEN`, DB URL'lar, R2 kalitlari) faqat **env** orqali (Railway Variables / lokal `.env`). `.env` commit qilinmaydi.
- Log'lar yuborishdan oldin **scrub** qilinadi: token/PIN/parol/`Authorization` header/`Bearer ...` maskalanadi (`lib/src/core/scrub.dart`).
- "Dev Log" guruhi **maxfiy** bo'lsin (faqat jamoa). DB connection string'lar log'da paydo bo'lmasin.
- Egasidan so'rang: yangi sir kerak bo'lsa, tashqi xizmat (R2 hisob) tanlovi, yoki guruh/bot tokeni. Sirlarni kodga yozmang.

## Build holati (PROGRESS)

`tasks/PROGRESS.md` hali yo'q — "davom ettir" deyilsa, uni yarating va bosqichlarni belgilang. Bosqichlar (docs/01 oxirida ham bor):

- [ ] **Phase 1 — Skelet** (shu commit): tuzilma, config, Docker, docs, stub'lar.
- [ ] **Phase 2 — Backup cron**: `pg_dump | gzip` → fallback zanjiri → tozalash.
- [ ] **Phase 3 — Registr + `/newproject`** boti (avto-topic).
- [ ] **Phase 4 — Log ingest web** + Flutter klient SDK + smart filtr + scrub.
- [ ] **Phase 5 — Dozone POS** ulash (backup + log + login backend'dan).
- [ ] **Phase 6 — Business/Admin/Qrio/Sozly** ulash.

## Buyruqlar

Skelet hali tashqi paket import qilmaydi — `dart pub get`siz ham `dart analyze` o'tadi.

```bash
dart pub get            # paketlarni o'rnatish (implement bosqichida)
dart analyze            # statik tahlil
dart test               # testlar
dart run bin/ingest_server.dart   # web ingest (lokal)
dart run bin/backup.dart          # backup cron (lokal, bir martalik)
docker compose up                 # lokal: registr Postgres + ingest server
```

## Konvensiyalar

- `prefer_single_quotes`, `prefer_final_locals`. `print` o'rniga logger (cron stdout mustasno — Railway loglari uchun).
- Sof Dart (Flutter EMAS). `dart:io` to'g'ridan-to'g'ri ishlatiladi (Process, HttpClient, File).
- Fayl yo'llari **cross-platform**: vaqtinchalik fayllar `Directory.systemTemp` da; `path` ajratgichini qattiq yozmang. Bu Windows'da ishlash uchun muhim.
- Yangi loyiha qo'shish kod o'zgartirishni TALAB QILMASLIGI kerak (registr + bot buyrug'i). Agar talab qilsa — dizayn buzilgan, docs'ni qayta o'qing.

## Windows'da ishlash (muhim)

Egasi keyinchalik Windows'da ishlashi mumkin. Shuning uchun:
- **Docker-first**: `pg_dump`, Dart — hammasi Docker ichida. Windows'da faqat **Docker Desktop** kerak, native o'rnatish shart emas.
- `.gitattributes` (`eol=lf`) CRLF muammosini oldini oladi — o'chirmang.
- Skriptlar Dart yoki Docker buyruqlari bo'lsin (bash-only `.sh` ga bog'lanib qolmang). Kerak bo'lsa `.ps1` ham qo'shing.
- Batafsil: `docs/06_DEPLOY_RAILWAY.md` va `docs/07_ONBOARD_PROJECT.md`.
