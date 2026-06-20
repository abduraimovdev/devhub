# PROGRESS

devhub qurish bosqichlari. "davom ettir" deyilsa — birinchi belgilanmagan vazifani ol, tegishli `docs/` ni o'qi, bajar, sana bilan belgila.

## Phase 1 — Skelet
- [x] Repo tuzilishi + config + Docker + docs + pure-Dart stub'lar (2026-06-20)

## Phase 2 — Backup cron (docs/03)  ✅ (2026-06-20)
- [x] `http`+`crypto` qo'shildi; `TelegramClient.sendMessage/sendDocument/createForumTopic`
- [x] `backup/dump.dart` — pg_dump → gzip (dart:io, cross-platform) + timeout + bo'sh-dump tekshiruvi
- [x] Zanjirli fallback: Telegram → R2 (SigV4 PUT) → ❌ (`r2_uploader.dart`)
- [x] Har-DB izolyatsiya + ✅/❌ xulosa; faylni o'chirish (`backup_runner.dart`)
- [x] `bin/backup.dart` ulandi; `targetsFromEnv` (DATABASES bootstrap)
- [x] Testlar: filename/caption/humanSize/tailLines/targetsFromEnv + **AWS SigV4 vektori**
- [ ] (keyin) presigned R2 GET link (public domen yo'q bo'lsa); multipart upload (GB+ fayl)

## Phase 3 — Registr + bot (docs/05, docs/02)  ✅ (2026-06-20)
- [x] `postgres` qo'shildi; `PgRegistry` (openFromUrl) + jadval bootstrap (IF NOT EXISTS)
- [x] `slugify` + `generateApiKey` (sof, test qilingan)
- [x] `televerse` qo'shildi; `DevHubBot`: `/newproject`, `/addbackup`, `/projects`
- [x] `createForumTopic` (HTTP) + API key — `/newproject` 3 topic ochadi
- [x] `bin/ingest_server.dart` — registr bootstrap + bot start
- [ ] (keyin) admin-only tekshiruv (getChatAdministrators), `/rotatekey`, `/removeproject`

## Phase 4 — Log ingest web (docs/04)  ✅ (2026-06-20)
- [x] `shelf`+`shelf_router`; `IngestServer`: `POST /v1/log`, `/v1/log/batch`, `GET /health`
- [x] API key → loyiha (kesh bilan); 401 noto'g'ri keyda
- [x] `LogFilter` smart anti-flood (alwaysSend / oynali dedupe + ×N) — test qilingan
- [x] `formatLogMessage` + `Scrub` (token/parol/conn-string maskalanadi)
- [x] Login → Login topic, qolgani → Log topic; fire-and-forget → 202
- [x] `bin/ingest_server.dart` — HTTP server + bot bir vaqtda
- [ ] (keyin) Redis-backed dedupe (ko'p-instans); 429 backoff

## Phase 5 — Dozone POS ulash
- [x] **5a** Flutter `devlog_client` paketi (`clients/flutter/devlog_client/`) ✅ (2026-06-20)
      crash hooks + apiError + login + freeze; xotira navbati + batch; klient scrub; testlar
- [ ] **5b** Dozone POS'ga ulash: `DevLog.init` + `runZonedGuarded` + Dio interceptor
- [ ] **5b** Backend (Serverpod) login eventlari → `POST /v1/log` (server biladi)
- [ ] (prerekvizit) devhub'ni GitHub'ga push (git-dependency uchun) yoki lokal `path:` dep

## Phase 5 — Dozone POS ulash
- [ ] SDK ulash (crash/API/login) + backend login eventlari + backup target

## Phase 6 — Boshqalar
- [ ] Business · Admin · Qrio · Sozly
