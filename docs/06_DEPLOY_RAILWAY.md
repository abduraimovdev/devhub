# 06 · Railway deploy

## Umumiy: 1 repo → 2 servis + 1 Postgres

Bitta GitHub repo, bitta Docker image. Railway'da uchta narsa:

1. **Postgres (registr)** — Railway "Add Postgres" → `REGISTRY_DATABASE_URL` shu yerdan.
2. **devhub-web** (Vazifa A, doimiy) — image'dan, default `CMD` (`ingest_server`). Public domen oladi (ilovalar shunga POST qiladi).
3. **devhub-cron** (Vazifa B) — bir xil repo/image, lekin:
   - **Start Command:** `/app/bin/backup`
   - **Cron Schedule:** `0 0,17 * * *` (UTC = 05:00 / 22:00 Toshkent)
   - Doimiy ishlamaydi — Railway uni jadval bo'yicha ishga tushiradi, ish tugagach o'chadi.

## Image — nega `postgres:17` (`-alpine` EMAS)

`dart compile exe` **glibc** uchun native binary chiqaradi (rasmiy Dart image Debian). `postgres:17-alpine` esa **musl** (Alpine) — binary mos kelmaydi, ishlamaydi. Shuning uchun runtime base **`postgres:17`** (Debian, glibc) — `pg_dump` ham shu image'da bor. Biroz kattaroq, lekin to'g'ri ishlaydi.

(Muqobil: `-alpine` kerak bo'lsa, Dart kodni Alpine/musl image'da AOT qilish kerak — murakkabroq. Hozircha kerak emas.)

## Env (har servisda)

`docs/.env.example` dagi barcha o'zgaruvchilar Railway > Service > **Variables** ga qo'yiladi (`.env` fayl emas). Sirlar (`BOT_TOKEN`, `R2_*`, DB URL'lar) — Railway secrets.

- **devhub-web:** `BOT_TOKEN`, `LOG_GROUP_CHAT_ID`, `REGISTRY_DATABASE_URL`, `PORT`, ingest sozlamalari.
- **devhub-cron:** `BOT_TOKEN`, `LOG_GROUP_CHAT_ID`, `REGISTRY_DATABASE_URL`, `R2_*`, backup sozlamalari.

## Public connection string

Backup qilinadigan DB'lar **boshqa** Railway proyektlarida. Ichki `*.railway.internal` faqat o'sha proyekt ichida ishlaydi → devhub'ga har DB ning **public** URL'i kerak (Railway > DB > Connect > Public Network). Bu URL'lar registr (`backup_targets.db_url`) ga `/addbackup` orqali qo'shiladi.

## Lokal dev (Windows ham)

Native o'rnatish shart emas — **Docker Desktop** yetadi:

```bash
cp .env.example .env       # to'ldiring (lokal test bot/guruh bilan)
docker compose up          # registr Postgres + ingest web
docker compose run --rm backup   # backup'ni bir marta sinash
```

Windows'da: PowerShell yoki CMD'da xuddi shu `docker` buyruqlari. `.gitattributes` (eol=lf) tufayli Dockerfile/skriptlar CRLF'siz — muammosiz.
