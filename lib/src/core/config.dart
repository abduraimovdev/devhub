import 'dart:io';

class Config {
  Config({
    required this.botToken,
    required this.logGroupChatId,
    required this.registryDatabaseUrl,
    required this.port,
    required this.maxTelegramMb,
    required this.pgDumpTimeout,
    required this.backupTopicId,
    required this.databasesEnv,
    required this.r2,
  });

  final String botToken;
  final int logGroupChatId;
  final String registryDatabaseUrl;
  final int port;

  final int maxTelegramMb;
  final Duration pgDumpTimeout;

  final int? backupTopicId;

  final String? databasesEnv;

  final R2Config? r2;

  static Config fromEnv([Map<String, String>? env]) {
    final e = env ?? Platform.environment;
    return Config(
      botToken: _require(e, 'BOT_TOKEN'),
      logGroupChatId: int.parse(_require(e, 'LOG_GROUP_CHAT_ID')),
      registryDatabaseUrl: e['REGISTRY_DATABASE_URL'] ?? '',
      port: int.tryParse(e['PORT'] ?? '') ?? 8080,
      maxTelegramMb: int.tryParse(e['BACKUP_MAX_TELEGRAM_MB'] ?? '') ?? 50,
      pgDumpTimeout: Duration(
        seconds: int.tryParse(e['PG_DUMP_TIMEOUT_SECONDS'] ?? '') ?? 600,
      ),
      backupTopicId: int.tryParse(e['BACKUP_TOPIC_ID'] ?? ''),
      databasesEnv: e['DATABASES'],
      r2: R2Config.fromEnv(e),
    );
  }

  static String _require(Map<String, String> env, String key) {
    final v = env[key];
    if (v == null || v.isEmpty) {
      throw StateError("Majburiy env yo'q: $key (.env.example ga qarang)");
    }
    return v;
  }
}

class R2Config {
  R2Config({
    required this.accountId,
    required this.accessKeyId,
    required this.secretAccessKey,
    required this.bucket,
    this.publicBaseUrl,
  });

  final String accountId;
  final String accessKeyId;
  final String secretAccessKey;
  final String bucket;
  final String? publicBaseUrl;

  String get host => '$accountId.r2.cloudflarestorage.com';

  static R2Config? fromEnv(Map<String, String> e) {
    final acc = e['R2_ACCOUNT_ID'];
    final ak = e['R2_ACCESS_KEY_ID'];
    final sk = e['R2_SECRET_ACCESS_KEY'];
    final bucket = e['R2_BUCKET'];
    if (acc == null || acc.isEmpty) return null;
    if (ak == null || ak.isEmpty) return null;
    if (sk == null || sk.isEmpty) return null;
    if (bucket == null || bucket.isEmpty) return null;
    return R2Config(
      accountId: acc,
      accessKeyId: ak,
      secretAccessKey: sk,
      bucket: bucket,
      publicBaseUrl: e['R2_PUBLIC_BASE_URL'],
    );
  }
}
