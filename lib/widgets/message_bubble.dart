import 'package:buritto/extensions/message_bubble.dart';
import 'package:buritto/models/message.dart';
import 'package:flutter/material.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message
  });

  final Message message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      padding: const EdgeInsets.all(7),
      constraints: BoxConstraints(maxWidth: context.maxMessageWidth),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 2),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        message.content,
        style: context.comicMessageText,
      ),
    )
    .align(message.isInput ? Alignment.centerRight : Alignment.centerLeft);
  }
}