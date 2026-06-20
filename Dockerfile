# ─── 1-bosqich: Dart kodni native AOT exe'ga kompilyatsiya ───
# Rasmiy Dart image Debian (glibc) — chiqgan binary glibc runtime talab qiladi.
FROM dart:stable AS build

WORKDIR /app
COPY pubspec.* ./
RUN dart pub get
COPY . .
RUN dart pub get --offline
RUN dart compile exe bin/ingest_server.dart -o /app/bin/ingest_server
RUN dart compile exe bin/backup.dart        -o /app/bin/backup

# ─── 2-bosqich: runtime (pg_dump bilan) ───
# postgres:17 — Debian (glibc) → AOT binary mos. `pg_dump` shu image'da bor.
# `-alpine` EMAS: musl glibc binary'ni ishlatolmaydi (docs/06).
FROM postgres:17

RUN apt-get update \
 && apt-get install -y --no-install-recommends curl ca-certificates gzip \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=build /app/bin/ingest_server /app/bin/ingest_server
COPY --from=build /app/bin/backup        /app/bin/backup

ENV PORT=8080
EXPOSE 8080

# Default = web ingest (Vazifa A). Cron servis Start Command'ni
# `/app/bin/backup` ga o'zgartiradi (docs/06).
CMD ["/app/bin/ingest_server"]
