# 02 · Telegram sozlash

## 1. Bot yaratish

1. @BotFather → `/newbot` → nom (masalan "Dozone Dev Log") → `BOT_TOKEN` olinadi.
2. `/setprivacy` → **Disable** (bot guruhdagi xabarlarni ko'rishi uchun, `/newproject` kabi buyruqlar).

## 2. Forum guruh

1. Telegram'da yangi **guruh** yarating → nomi "Dev Log".
2. Sozlamalar → **Topics** (Mavzular) ni **yoqing** → guruh forum bo'ladi.
3. Botni guruhga qo'shing va **admin** qiling — kerakli huquqlar: *Manage Topics* (topic ochish uchun), *Send Messages*, *Post in Topics*.
4. Guruh **maxfiy** bo'lsin (faqat jamoa).

## 3. `CHAT_ID` ni olish

Guruhga bot qo'shilgach, biror xabar yozing, so'ng:
```
https://api.telegram.org/bot<BOT_TOKEN>/getUpdates
```
javobdagi `chat.id` (manfiy, `-100…`) → `LOG_GROUP_CHAT_ID`.

## 4. Topiclar — qo'lda EMAS, bot ochadi

Topiclarni qo'lda ochmaysiz. Loyiha ulashda bot avtomatik ochadi:

```
/newproject Dozone POS
```
Bot quyidagini bajaradi:
1. `createForumTopic("Dozone POS · Log")`, `… · Login"`, `… · Backup"` — 3 ta topic.
2. API key generatsiya qiladi (loyiha log yuborishda ishlatadi).
3. Registr (Postgres) ga yozadi: `{ label, apiKey, topic_log, topic_login, topic_backup }`.
4. Javob beradi: API key + (DB backup kerak bo'lsa) `DATABASE_URL` qo'shish ko'rsatmasi.

> `message_thread_id` = topic id. Bot har xabarni shu id bilan yuboradi → xabar to'g'ri topicga tushadi.

## Bot buyruqlari (Phase 3)

| Buyruq | Vazifa |
|---|---|
| `/newproject <label>` | 3 topic ochadi + API key + registr yozuvi |
| `/addbackup <label> <db_url>` | loyihaga backup DB qo'shadi |
| `/projects` | ulangan loyihalar ro'yxati |
| `/removeproject <label>` | loyihani o'chiradi (topiclar qoladi) |
| `/rotatekey <label>` | API key'ni yangilaydi |

Faqat guruh **adminlari** buyruq bera oladi (boshqalarga e'tibor berilmaydi).

## Rate limit (Telegram)

Bot bitta guruhga ~20 xabar/daqiqa, ~1 xabar/sekund (barqaror) yubora oladi. Shuning uchun **anti-flood** (docs/04): 4xx'lar yig'iladi, 429 kelsa kutib qayta urinadi (backoff).
