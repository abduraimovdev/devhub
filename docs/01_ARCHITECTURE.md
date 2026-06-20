# 01 · Arxitektura

## Bitta kod, ikki runtime

Log real-time keladi (servis **doimiy** tinglashi kerak), backup esa **rejaga ko'ra** (uyg'onib-o'chadi). Shuning uchun bitta repo/image, lekin ikki entrypoint, ikki Railway servisi:

```
                       ┌─────────────────────────── umumiy yadro (lib/src/core) ──┐
                       │  config · telegram (send) · registry · scrub             │
                       └──────────────────────────────────────────────────────────┘
                                    ▲                              ▲
        ┌───────────────────────────┘                              └───────────────┐
        │                                                                          │
  bin/ingest_server.dart                                                   bin/backup.dart
  (Vazifa A — WEB, doimiy)                                                 (Vazifa B — CRON)
   shelf HTTP :8080                                                         pg_dump|gzip
   POST /v1/log  (API key)                                                  fallback zanjiri
        │                                                                          │
   ilovalar push qiladi                                                     Railway cron 0 0,17 * * *
```

Ikkala servis bir xil Docker image'dan ko'tariladi; farqi faqat **CMD** (start buyrug'i):
- web servis → `CMD ["/app/bin/ingest_server"]`
- cron servis → start buyrug'i `/app/bin/backup` (Railway cron sozlamasida)

## Repo tuzilishi

```
lib/
  devhub.dart                 # public barrel
  src/
    core/
      config.dart             # env → Config obyekti (validatsiya bilan)
      telegram.dart           # sendMessage / sendDocument / createForumTopic
      registry.dart           # Postgres: projects, topics CRUD
      scrub.dart              # maxfiy ma'lumotni maskalash
    backup/
      backup_runner.dart      # Vazifa B mantig'i (Phase 2)
      r2_uploader.dart        # R2 (S3) yuklash (Phase 2)
    ingest/
      server.dart             # shelf router + handlerlar (Phase 4)
      filter.dart             # smart anti-flood filtr (Phase 4)
      bot.dart                # televerse: /newproject va h.k. (Phase 3)
bin/
  ingest_server.dart          # entrypoint A
  backup.dart                 # entrypoint B
```

## Umumiy yadro (core) — har ikki vazifa ishlatadi

- **config.dart** — `Config.fromEnv()`; majburiy env yo'q bo'lsa aniq xato beradi (fail-fast).
- **telegram.dart** — Telegram Bot API ustidan yupqa qatlam: `sendMessage(threadId, text)`, `sendDocument(threadId, file, caption)`, `createForumTopic(name)`. Cron'da `http` paketi bilan; bot buyruqlari uchun `televerse`.
- **registry.dart** — loyiha registri (docs/05). `projectByApiKey()`, `allProjectsWithDb()`, `createProject(label) → {apiKey, topicIds}`.
- **scrub.dart** — `Authorization`, `Bearer …`, `password`, `pin`, `token`, kartalar va connection-string'lardagi parolni maskalaydi.

## Ma'lumot oqimi

**A (log):** ilova → `POST /v1/log` (`X-Api-Key`) → registr (key → loyiha+topiclar) → filtr (anti-flood) → scrub → `sendMessage(Log/Login topic)`.

**B (backup):** cron uyg'onadi → registrdan DB'li loyihalar → har biri uchun `pg_dump --no-owner --no-privileges | gzip -9` → `sendDocument(Backup topic)` → bo'lmasa R2 → bo'lmasa ❌ → faylni o'chiradi → keyingi DB.

## Build bosqichlari

1. **Phase 1** — skelet (config, Docker, docs, stub'lar). ← shu hozir
2. **Phase 2** — backup_runner + r2_uploader + telegram send.
3. **Phase 3** — registry (Postgres) + bot `/newproject` (createForumTopic).
4. **Phase 4** — ingest server + filter + scrub + Flutter klient SDK shartnomasi.
5. **Phase 5** — Dozone POS ulash.
6. **Phase 6** — Business / Admin / Qrio / Sozly.
