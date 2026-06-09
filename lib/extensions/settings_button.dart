import 'package:flutter/material.dart';

extension SettingsButtonExtensions on BuildContext {
  TextStyle get comicMessageText => const TextStyle(
    fontSize: 20,
    color: Colors.black,
    fontFamily: 'Hey-Comic',
  );

  double get maxMessageWidth => MediaQuery.sizeOf(this).width * 0.7;
}

extension WidgetAlignment on Widget {
  Widget center() => Center(child: this);
  Widget paddingAll(double value) => Padding(padding: EdgeInsetsGeometry.all(value), child: this);
}
