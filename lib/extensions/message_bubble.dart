import 'package:flutter/material.dart';

extension MessageBubbleExtensions on BuildContext {
  TextStyle get comicMessageText => const TextStyle(
    color: Colors.black,
    fontFamily: 'Hey-Comic',
  );

  double get maxMessageWidth => MediaQuery.sizeOf(this).width * 0.7;
}

extension WidgetAlignment on Widget {
  Widget align(Alignment alignment) => Align(alignment: alignment, child: this);
}
