import 'dart:convert';
import 'dart:math';

import 'package:postgres/postgres.dart';

// Loyiha registri (Postgres). Sxema: docs/05_REGISTRY_SCHEMA.md.

class Project {
  Project({
    required this.id,
    required this.label,
    required this.slug,
    required this.apiKey,
    this.topicLog,
    this.topicLogin,
    this.topicBackup,
  });

  final int id;
  final String label;
  final String slug;
  final String apiKey;
  final int? topicLog;
  final int? topicLogin;
  final int? topicBackup;
}

class BackupTarget {
  BackupTarget({
    required this.name,
    required this.dbUrl,
    this.topicBackup,
    this.projectLabel = '',
  });

  final String name;
  final String dbUrl; // public connection string (SIR — scrub/encrypt)
  final int? topicBackup;
  final String projectLabel;
}

abstract class Registry {
  Future<Project?> projectByApiKey(String apiKey);
  Future<List<BackupTarget>> activeBackupTargets();
  Future<Project> createProject({
    required String label,
    required String slug,
    required String apiKey,
    int? topicLog,
    int? topicLogin,
    int? topicBackup,
  });
  Future<void> addBackupTarget(String label, String name, String dbUrl);
  Future<List<Project>> allProjects();
}

/// Postgres-backed registr. URL'da `?sslmode=` bo'lmasa default `require`
/// (Railway uchun OK; lokal docker uchun `?sslmode=disable` qo'shing).
class PgRegistry implements Registry {
  PgRegistry(this._url);

  final String _url;
  Connection? _conn;

  Future<Connection> _c() async {
    final existing = _conn;
    if (existing != null && existing.isOpen) return existing;
    return _conn = await Connection.openFromUrl(_url);
  }

  /// Jadvallarni yaratadi (idempotent) — startup'da chaqiriladi.
  Future<void> bootstrap() async {
    final c = await _c();
    await c.execute('''
      CREATE TABLE IF NOT EXISTS projects (
        id           BIGSERIAL PRIMARY KEY,
        label        TEXT NOT NULL,
        slug         TEXT NOT NULL UNIQUE,
        api_key      TEXT NOT NULL UNIQUE,
        topic_log    BIGINT,
        topic_login  BIGINT,
        topic_backup BIGINT,
        is_active    BOOLEAN NOT NULL DEFAULT TRUE,
        created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
      )''');
    await c.execute('''
      CREATE TABLE IF NOT EXISTS backup_targets (
        id          BIGSERIAL PRIMARY KEY,
        project_id  BIGINT NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
        name        TEXT NOT NULL,
        db_url      TEXT NOT NULL,
        is_active   BOOLEAN NOT NULL DEFAULT TRUE,
        created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
        UNIQUE (project_id, name)
      )''');
  }

  @override
  Future<Project?> projectByApiKey(String apiKey) async {
    final c = await _c();
    final rows = await c.execute(
      Sql.named(
        'SELECT * FROM projects WHERE api_key = @k AND is_active LIMIT 1',
      ),
      parameters: {'k': apiKey},
    );
    if (rows.isEmpty) return null;
    return _project(rows.first.toColumnMap());
  }

  @override
  Future<List<BackupTarget>> activeBackupTargets() async {
    final c = await _c();
    final rows = await c.execute('''
      SELECT bt.name, bt.db_url, p.label AS project_label, p.topic_backup
      FROM backup_targets bt
      JOIN projects p ON p.id = bt.project_id
      WHERE bt.is_active AND p.is_active''');
    return rows.map((r) {
      final m = r.toColumnMap();
      return BackupTarget(
        name: m['name'] as String,
        dbUrl: m['db_url'] as String,
        topicBackup: m['topic_backup'] as int?,
        projectLabel: (m['project_label'] as String?) ?? '',
      );
    }).toList();
  }

  @override
  Future<Project> createProject({
    required String label,
    required String slug,
    required String apiKey,
    int? topicLog,
    int? topicLogin,
    int? topicBackup,
  }) async {
    final c = await _c();
    final rows = await c.execute(
      Sql.named('''
        INSERT INTO projects
          (label, slug, api_key, topic_log, topic_login, topic_backup)
        VALUES (@label, @slug, @key, @tl, @tlogin, @tb)
        RETURNING *'''),
      parameters: {
        'label': label,
        'slug': slug,
        'key': apiKey,
        'tl': topicLog,
        'tlogin': topicLogin,
        'tb': topicBackup,
      },
    );
    return _project(rows.first.toColumnMap());
  }

  @override
  Future<void> addBackupTarget(String label, String name, String dbUrl) async {
    final c = await _c();
    final p = await c.execute(
      Sql.named('SELECT id FROM projects WHERE slug = @l OR label = @l LIMIT 1'),
      parameters: {'l': label},
    );
    if (p.isEmpty) throw StateError('Loyiha topilmadi: $label');
    final pid = p.first.toColumnMap()['id'];
    await c.execute(
      Sql.named('''
        INSERT INTO backup_targets (project_id, name, db_url)
        VALUES (@pid, @name, @url)
        ON CONFLICT (project_id, name)
        DO UPDATE SET db_url = @url, is_active = TRUE'''),
      parameters: {'pid': pid, 'name': name, 'url': dbUrl},
    );
  }

  @override
  Future<List<Project>> allProjects() async {
    final c = await _c();
    final rows = await c.execute(
      'SELECT * FROM projects WHERE is_active ORDER BY created_at',
    );
    return rows.map((r) => _project(r.toColumnMap())).toList();
  }

  Future<void> close() async {
    await _conn?.close();
    _conn = null;
  }

  static Project _project(Map<String, dynamic> m) => Project(
        id: m['id'] as int,
        label: m['label'] as String,
        slug: m['slug'] as String,
        apiKey: m['api_key'] as String,
        topicLog: m['topic_log'] as int?,
        topicLogin: m['topic_login'] as int?,
        topicBackup: m['topic_backup'] as int?,
      );
}

/// "Dozone POS" → "dozone-pos". Sof — test qilinadi.
String slugify(String s) {
  final out = s
      .toLowerCase()
      .replaceAll(RegExp('[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return out.isEmpty ? 'project' : out;
}

/// `dl_<slug>_<random>` API key. Random — format/prefix test qilinadi.
String generateApiKey(String slug, {Random? random}) {
  final rnd = random ?? Random.secure();
  final bytes = List<int>.generate(24, (_) => rnd.nextInt(256));
  final token = base64Url.encode(bytes).replaceAll('=', '');
  return 'dl_${slug}_$token';
}
