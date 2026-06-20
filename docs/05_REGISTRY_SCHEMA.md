# 05 · Loyiha registri (Postgres)

Servisning O'Z Postgres'i (`REGISTRY_DATABASE_URL`). Loyihalar, topiclar va backup DB'lari shu yerda — yangi loyiha **kod o'zgartirmasdan** qo'shiladi.

## Jadvallar

```sql
CREATE TABLE projects (
  id           BIGSERIAL PRIMARY KEY,
  label        TEXT        NOT NULL,              -- "Dozone POS"
  slug         TEXT        NOT NULL UNIQUE,       -- "dozone-pos"
  api_key      TEXT        NOT NULL UNIQUE,       -- log yuborishda X-Api-Key
  topic_log    BIGINT,                            -- message_thread_id
  topic_login  BIGINT,
  topic_backup BIGINT,
  is_active    BOOLEAN     NOT NULL DEFAULT TRUE,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Bitta loyihaning bir nechta backup DB'si bo'lishi mumkin.
CREATE TABLE backup_targets (
  id          BIGSERIAL PRIMARY KEY,
  project_id  BIGINT      NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  name        TEXT        NOT NULL,               -- fayl labeli: "pos", "sozly"
  db_url      TEXT        NOT NULL,               -- public connection string (sir!)
  is_active   BOOLEAN     NOT NULL DEFAULT TRUE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (project_id, name)
);

-- Anti-flood dedupe hisoblagichlari (ixtiyoriy — Redis ham bo'lishi mumkin).
CREATE TABLE dedupe_counters (
  key        TEXT        PRIMARY KEY,             -- hash(project+type+endpoint+status+msg)
  count      INTEGER     NOT NULL DEFAULT 1,
  window_end TIMESTAMPTZ NOT NULL
);
```

## API key

- Generatsiya: `dl_<slug>_<random32>` (yoki `base64url(32 bayt)`). Faqat hash'i saqlanishi ham mumkin (xavfsizroq) — MVP'da ochiq saqlash ham yetadi, lekin guruh maxfiy.
- `/rotatekey <label>` yangilaydi.

## `db_url` xavfsizligi

`backup_targets.db_url` — parolli connection string (sir). Registr DB'sining o'zi maxfiy/ichki bo'lsin. Loglarda, Telegram'da hech qachon ko'rsatilmaydi (scrub). Kerak bo'lsa `pgcrypto` bilan shifrlash mumkin (Phase 2+).

## Asosiy so'rovlar (registry.dart)

- `projectByApiKey(key)` → loyiha + topic id'lari (ingest uchun).
- `activeBackupTargets()` → barcha `backup_targets` + project.topic_backup (backup uchun).
- `createProject(label) → {id, slug, apiKey, topicLog, topicLogin, topicBackup}` (bot avval `createForumTopic` ×3 qiladi, keyin yozadi).
- `addBackupTarget(label, name, dbUrl)`.

## Migratsiya

Phase 3'da: `lib/src/core/registry.dart` ishga tushganda jadvallarni `CREATE TABLE IF NOT EXISTS` bilan yaratadi (oddiy bootstrap), yoki `migrations/*.sql` papkasi. MVP uchun `IF NOT EXISTS` yetarli.
