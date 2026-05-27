import 'package:buritto/hive/hive_database.dart';
import 'package:buritto/widgets/chat.dart';

class Message {
  final String content;
  final bool isInput;

  const Message({
    required this.content,
    this.isInput = true,
  });
}

class MessageRepo {
  static Map<int, Future<Message?>> futures = {};

  static MessageBubble asMessageBubble(final Message message) {
    return MessageBubble(content: message.content, isInput: message.isInput);
  }

  static Future<Message?> getMessage(final int i) {
    futures[i] ??= HiveDatabase().messages.getAt(i);
    return futures[i]!;
  }

  static void sendMessage(final String content) {
    if (content.isEmpty) {
      return;
    }
    HiveDatabase().messages.add(Message(content: content, isInput: true));
  }
}
