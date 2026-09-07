import 'package:devlog_client/src/scrub.dart';

class DevLogEvent {
  DevLogEvent({
    required this.type,
    required this.message,
    this.context = const {},
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String type;
  final String message;
  final Map<String, dynamic> context;
  final DateTime createdAt;

  DevLogEvent scrubbed() => DevLogEvent(
        type: type,
        message: scrubText(message),
        context: context.map(
          (k, v) => MapEntry(k, v is String ? scrubText(v) : v),
        ),
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'type': type,
        'message': message,
        'context': context,
        'ts': createdAt.toUtc().toIso8601String(),
      };
}
