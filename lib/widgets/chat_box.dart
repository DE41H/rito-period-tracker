import 'package:buritto/hive/hive_database.dart';
import 'package:buritto/models/message.dart';
import 'package:buritto/widgets/message_bubble.dart';
import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/adapters.dart';

class ChatBox extends StatelessWidget {
  const ChatBox({super.key});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: ValueListenableBuilder<LazyBox<Message>>(
        valueListenable: HiveDatabase().messages.listenable(),
        builder: (context, value, _) {
          return ListView.builder(
            reverse: true,
            itemCount: value.length,
            itemBuilder: (context, index) {
              final i = value.length - 1 - index;
              return FutureBuilder<Message?>(
                future: MessageRepo().get(i),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox(height: 48);
                  final message = snapshot.data!;
                  return MessageBubble(message: message);
                },
              );
            },
          );
        },
      ),
    );
  }
}