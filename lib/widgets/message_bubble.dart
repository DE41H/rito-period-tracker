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
      alignment: message.isInput ? Alignment.centerRight : Alignment.centerLeft,
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      padding: const EdgeInsets.all(7),
      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.7),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 2),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        message.content,
        style: const TextStyle(
          color: Colors.black,
          fontFamily: 'Hey-Comic',
        ),
      ),
    );
  }
}
