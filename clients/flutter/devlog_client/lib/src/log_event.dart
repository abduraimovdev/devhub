import 'package:devlog_client/src/scrub.dart';

class DevLogEvent {
  DevLogEvent({
    required this.type,
    required this.message,
    this.context = const {},
  });

  final String type;
  final String message;
  final Map<String, dynamic> context;

  DevLogEvent scrubbed() => DevLogEvent(
        type: type,
        message: scrubText(message),
        context: context.map(
          (k, v) => MapEntry(k, v is String ? scrubText(v) : v),
        ),
      );

  Map<String, dynamic> toJson() => {
        'type': type,
        'message': message,
        'context': context,
        'ts': DateTime.now().toUtc().toIso8601String(),
      };
}
