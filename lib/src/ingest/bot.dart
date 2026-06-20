import 'dart:io';

import 'package:devhub/src/core/config.dart';
import 'package:devhub/src/core/registry.dart';
import 'package:devhub/src/core/telegram.dart';
import 'package:televerse/televerse.dart';

/// Telegram boti — onboarding buyruqlari. Faqat `LOG_GROUP_CHAT_ID` guruhida
/// ishlaydi (boshqa chatlarda e'tibor bermaydi). docs/02_TELEGRAM_SETUP.md.
class DevHubBot {
  DevHubBot({
    required this.config,
    required this.registry,
    required this.telegram,
  });

  final Config config;
  final PgRegistry registry;
  final TelegramClient telegram;

  late final Bot _bot = Bot(config.botToken);

  Future<void> start() async {
    _bot
      ..command('newproject', _onNewProject)
      ..command('addbackup', _onAddBackup)
      ..command('projects', _onProjects)
      ..onError((err) => stdout.writeln('bot xato: $err'));
    stdout.writeln('devhub bot ishga tushdi');
    await _bot.start();
  }

  bool _inGroup(Context ctx) => ctx.chat?.id == config.logGroupChatId;

  Future<void> _onNewProject(Context ctx) async {
    if (!_inGroup(ctx)) return;
    final label = ctx.args.join(' ').trim();
    if (label.isEmpty) {
      await ctx.reply('Foydalanish: /newproject <nom>');
      return;
    }
    final slug = slugify(label);
    try {
      final topicLog = await telegram.createForumTopic('$label · Log');
      final topicLogin = await telegram.createForumTopic('$label · Login');
      final topicBackup = await telegram.createForumTopic('$label · Backup');
      final p = await registry.createProject(
        label: label,
        slug: slug,
        apiKey: generateApiKey(slug),
        topicLog: topicLog,
        topicLogin: topicLogin,
        topicBackup: topicBackup,
      );
      await ctx.reply(
        '✅ <b>$label</b> ulandi.\n\n'
        'API key:\n<code>${p.apiKey}</code>\n\n'
        "Backup qo'shish:\n"
        '<code>/addbackup $slug postgresql://user:pass@host:port/db</code>',
        parseMode: ParseMode.html,
      );
    } on Object catch (e) {
      await ctx.reply('❌ Xato: $e');
    }
  }

  Future<void> _onAddBackup(Context ctx) async {
    if (!_inGroup(ctx)) return;
    final args = ctx.args;
    if (args.length < 2) {
      await ctx.reply('Foydalanish: /addbackup <loyiha> <db_url>');
      return;
    }
    try {
      await registry.addBackupTarget(
        args[0],
        args[0],
        args.sublist(1).join(' '),
      );
      await ctx.reply(
        "✅ <b>${args[0]}</b> backup nishoni qo'shildi.",
        parseMode: ParseMode.html,
      );
    } on Object catch (e) {
      await ctx.reply('❌ Xato: $e');
    }
  }

  Future<void> _onProjects(Context ctx) async {
    if (!_inGroup(ctx)) return;
    final all = await registry.allProjects();
    if (all.isEmpty) {
      await ctx.reply("Loyiha yo'q");
      return;
    }
    await ctx.reply(all.map((p) => '• ${p.label} (${p.slug})').join('\n'));
  }
}
