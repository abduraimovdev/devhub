# devhub

Ko'p loyihali **DevOps Telegram servisi** — bitta yadro, ikki vazifa:

| Vazifa | Nima | Rejim |
|---|---|---|
| **A · Log ingest** | Ilovalardan xato / crash / freeze / login → Telegram topic | Doimiy (web) |
| **B · DB backup** | `pg_dump` barcha Postgres DB → Telegram fayl / R2 link | Cron (05:00, 22:00) |

Natija: 30+ loyihaga **redeploy'siz** ulanadi — botga `/newproject <nom>` deysiz, bot topiclarni ochib API key beradi.

## Tezkor start (lokal)

```bash
cp .env.example .env      # qiymatlarni to'ldiring
dart pub get
docker compose up         # registr Postgres + ingest web
dart run bin/backup.dart  # backup'ni bir marta sinash
```

## Tuzilma

```
devhub/
├── docs/            # TZ — haqiqat manbai (00..07)
├── bin/             # ikkita entrypoint: ingest_server.dart, backup.dart
├── lib/src/
│   ├── core/        # umumiy yadro: config, telegram, registry, scrub
│   ├── backup/      # Vazifa B
│   └── ingest/      # Vazifa A
├── Dockerfile       # AOT exe → postgres:18 (pg_dump bilan)
├── docker-compose.yaml
└── CLAUDE.md
```

To'liq hujjat: **[`docs/00_OVERVIEW.md`](docs/00_OVERVIEW.md)** dan boshlang. Deploy: [`docs/06_DEPLOY_RAILWAY.md`](docs/06_DEPLOY_RAILWAY.md). Yangi loyiha ulash: [`docs/07_ONBOARD_PROJECT.md`](docs/07_ONBOARD_PROJECT.md).

## 🔒 Xavfsizlik

Bu repo **public**. Shuning uchun bironta ham sir kod ichida saqlanmaydi:

- **Barcha sirlar env'dan** — `BOT_TOKEN`, `REGISTRY_DATABASE_URL`, `R2_*` faqat
  `Platform.environment`dan o'qiladi ([`lib/src/core/config.dart`](lib/src/core/config.dart),
  fail-fast: yo'q bo'lsa aniq xato). Kodda hardcoded fallback yo'q.
- **API kalit / DB URL'lar kodda emas** — loyiha registri (kalitlar, backup
  ulanish stringlari) runtime'da Postgres'da yashaydi, repo'da emas.
- **`.gitignore`** `.env*` (namunadan tashqari), `*.sql*`, `*.pem/.key`, backup
  artefaktlari va hisob ma'lumotlarini bloklaydi — tasodifan ham tushmaydi.
- **Konfiguratsiya namunasi** — [`.env.example`](.env.example) faqat soxta
  placeholder qiymatlar (`123456789:AA-xxx`, `user:pass@host`).

Sir yo'qolsa (token oshkor bo'lsa) — uni **bekor qilib (revoke), yangisini**
Railway Variables'ga qo'ying; repo'ni o'zgartirish shart emas.

## Stack

Server-side Dart · `shelf` · `televerse` · `postgres` · Docker · Railway · Cloudflare R2.
