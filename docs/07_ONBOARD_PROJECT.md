# 07 · Yangi loyihani ulash

Maqsad: yangi loyiha (masalan Qrio) **~10 soniyada**, kod o'zgartirmasdan, redeploy'siz ulanadi.

## A. Loglar uchun (crash/error/login)

1. "Dev Log" guruhida botga:
   ```
   /newproject Qrio
   ```
   Bot 3 topic ochadi (`Qrio · Log`, `Qrio · Login`, `Qrio · Backup`) + **API key** beradi.
2. O'sha loyiha ilovasiga `devlog_client` SDK'ni ulang (yoki shunchaki HTTP POST):
   - `DEVHUB_URL = https://devhub-web.up.railway.app`
   - `DEVHUB_API_KEY = <bot bergan key>`
3. Tamom — loglar `POST /v1/log` orqali tegishli topicga tushadi.

## B. Backup uchun

1. Qrio DB'sining **public** connection string'ini oling (Railway > DB > Connect > Public).
2. Botga:
   ```
   /addbackup Qrio postgresql://user:pass@host:port/db
   ```
3. Tamom — keyingi cron (05:00 / 22:00) da Qrio DB ham backup bo'lib `Qrio · Backup` topicga tushadi.

## Misol: 30 loyiha

Har biri uchun A va B qadamlari takrorlanadi — registr (Postgres) o'sib boradi, **kod va deploy o'zgarmaydi**. Backup cron registrdagi hamma DB'larni aylanadi; ingest web API key bo'yicha marshrutlaydi.

## Windows'da ishlash

- Kod ustida ishlash kerak bo'lsa: **Docker Desktop** o'rnating → `docker compose up`. Dart/Postgres'ni native o'rnatish shart emas.
- Native Dart bilan ishlamoqchi bo'lsangiz: [dart.dev/get-dart](https://dart.dev/get-dart) (Windows installer) → `dart pub get` → `dart run bin/...`.
- Git CRLF muammosi bo'lmaydi (`.gitattributes` eol=lf). Agar baribir chiqsa: `git config --global core.autocrlf input`.
- `pg_dump`ni native sinash kerak bo'lsa Windows'da: PostgreSQL client (yoki shunchaki Docker ishlatish — tavsiya).

## Ulashni o'chirish

- Loglarni to'xtatish: `/removeproject Qrio` (yoki SDK'ni o'chirish).
- Backup'ni to'xtatish: `/removebackup Qrio <name>`.
- API key oqib ketsa: `/rotatekey Qrio`.
