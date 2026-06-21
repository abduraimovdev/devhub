# 03 · DB Backup spec (Vazifa B)

Egasining asl spec'i + kelishilgan yaxshilanishlar.

## Maqsad

Railway'dagi barcha Postgres DB'larni avtomatik backup qilib Telegram'ga (yoki R2'ga) yuborish. Railway pullik backup'iga bog'lanmaslik; to'lov/xizmat uzilsa ham ma'lumot Railwaydan **tashqarida** saqlanadi.

## Qadamlar (har cron ishga tushishida)

1. Registrdan **backup DB'si bor** loyihalarni ol (docs/05). DB'lar env'da emas — **registrda** (`/addbackup` orqali qo'shiladi). Servis o'z registr DB'sini ham ro'yxatga qo'shadi.
2. Har DB uchun ketma-ket:
   1. `pg_dump --no-owner --no-privileges "<public_url>"` → `Directory.systemTemp` ichidagi faylga.
   2. `gzip -9` → `label_YYYY-MM-DD_HH-MM.sql.gz` (vaqt UTC).
   3. **Yuborish (zanjirli fallback):**
      - `sendDocument(backupTopic, file, caption)` — caption: DB nomi, vaqt (UTC), hajm.
      - ❌ bo'lsa (>50MB yoki Telegram xato) → **R2** (S3) ga yukla → `sendMessage(backupTopic, "📦 <label> backup: <link>")`.
      - R2 ham ❌ bo'lsa → `sendMessage(backupTopic, "❌ <label> backup yuborilmadi: <xato>")`.
   4. Faylni **o'chiradi** (container joy egallamasin).
3. Bitta DB xato bersa — qolganini **to'xtatmaydi** (har DB izolyatsiya + alohida hisobot).

## Xatolarni boshqarish

- `pg_dump` muvaffaqiyatli → ✅ + fayl/link.
- `pg_dump` xato → ❌ xabar + xatoning **oxirgi qatorlari** (faylsiz). "Backup tushmadi" signali.
- Har DB'ga **timeout** (`PG_DUMP_TIMEOUT_SECONDS`, default 600) — osilib qolgan DB hammasini bloklamasin.
- Yakunda qisqa **xulosa**: `N ✅ / M ❌` (umumiy holat bitta xabarda).

## Jadval

- Kuniga 2 marta: **05:00** va **22:00 Toshkent (UTC+5)**.
- Railway cron **UTC**'da: `0 0,17 * * *` (00:00 va 17:00 UTC).
- Alohida **cron servis** — doimiy ishlamaydi, faqat shu vaqtda uyg'onadi (resurs tejaladi).

## Texnik ehtiyot nuqtalari

- **Public connection string SHART.** Railway ichki `*.railway.internal` faqat o'sha proyekt ichida; devhub alohida proyekt → har DB ning **public** URL'i kerak.
- **pg_dump major versiyasi ≥ server major versiyasi.** Image `postgres:18` (v18 client PG ≤18 server'larni dump qiladi). Railway serveri 18.x bo'lgani uchun 18 — DB PG19+ bo'lsa image tag oshiriladi. (Nega `-alpine` emas — docs/06.)
- Image tarkibi: `pg_dump` (postgres image), `curl` (apt), `gzip` (Debian).

## Yaxshilanishlar (kelishilgan)

- **R2 fallback** — yuqoridagi zanjir (50MB+ yoki Telegram xato uchun).
- **Restore testi** — backup'ni vaqti-vaqti (oyiga 1) sinov DB'ga **tiklab ko'rish**. Tiklanmaydigan backup foydasiz. (Phase 2+ ixtiyoriy cron.)
- **Bo'sh/buzilgan dump tekshiruvi** — gzip hajmi juda kichik (masalan < 1KB) bo'lsa ⚠️ ogohlantirish (ehtimol dump bo'sh).
- **Retention** — Telegram fayllarni saqlaydi; R2'da lifecycle qoidasi (masalan 90 kun) qo'yish mumkin.

## Konfiguratsiya (env)

`BOT_TOKEN`, `LOG_GROUP_CHAT_ID`, `REGISTRY_DATABASE_URL`, `R2_*`, `BACKUP_MAX_TELEGRAM_MB`, `PG_DUMP_TIMEOUT_SECONDS` — `.env.example` ga qarang. DB'lar ro'yxati env'da emas, **registrda**.
