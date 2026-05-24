import 'package:flutter/material.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:provider/provider.dart';

import '../providers/home_provider.dart';

class Message extends StatelessWidget {
  final String message;
  final bool isInput;

  const Message({super.key, required this.message, required this.isInput});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isInput ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7
        ),
        padding: EdgeInsets.all(7),
        decoration: BoxDecoration(
          border: BoxBorder.all(color: Colors.black, width: 2),
          borderRadius: BorderRadius.circular(5),
          color: Colors.white,
        ),
        child: Text(
          message,
          style: TextStyle(
            color: Colors.black,
            fontFamily: 'Hey-Comic',
          ),
        )
      ),
    );
  }
}

class InputBar extends StatelessWidget {
  const InputBar({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<HomeProvider>();

    return Container(
      margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      padding: EdgeInsets.all(7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        border: BoxBorder.all(color: Colors.black, width: 2),
        color: Colors.white,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              style: TextStyle(
                fontFamily: 'Hey-Comic'
              ),
              maxLines: null,
              controller: provider.inputController,
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: '...',
                isDense: true,
              ),
            ),
          ),
          TextButton(
            onPressed: provider.sendMessage,
            child: Text(
              '->',
              style: TextStyle(
                fontSize: 15,
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ConversationArea extends StatelessWidget {
  const ConversationArea({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<HomeProvider>();
    
    return ValueListenableBuilder(
      valueListenable: Hive.lazyBox('messages').listenable(),
      builder: (context, value, child) {
        return Expanded(
          child: ListView.builder(
            reverse: true,
            itemCount: value.length,
            itemBuilder: (context, index) {
              final i = value.length - 1 - index;
              return FutureBuilder(
                future: provider.getFutureMessage(i),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return Container(
                      height: 40,
                      margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    );
                  }
                  final data = snapshot.data as Map;
                  return Message(message: data['message'], isInput: data['isInput']);
                }
              );
            },
          ),
        );
      }
    );
  }
}

class ChoicesArea extends StatelessWidget {
  const ChoicesArea({super.key});
  
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 2, horizontal: 4),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: MessageChoice(id: 0)),
              Expanded(child: MessageChoice(id: 1)),
              Expanded(child: MessageChoice(id: 2)),
            ]
          ),
          Row(
            children: [
              Expanded(child: MessageChoice(id: 3)),
              Expanded(child: MessageChoice(id: 4)),
              Expanded(child: MessageChoice(id: 5)),
            ],
          )
        ],
      ),
    );
  }
}

class MessageChoice extends StatelessWidget {
  final int id;

  const MessageChoice({super.key, required this.id});
  
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HomeProvider>();

    return Container(
      decoration: BoxDecoration(
        border: BoxBorder.all(color: Colors.black, width: 2),
        borderRadius: BorderRadius.circular(7),
        color: Colors.white
      ),
      margin: EdgeInsets.all(7),
      child: TextButton(
        onPressed: () => print('pressed button ${id.toString()}'),
        child: Text(
          provider.choices[id],
          style: TextStyle(
            color: Colors.black
          ),
        ),
      ),
    );
  }
}
