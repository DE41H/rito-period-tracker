import 'package:flutter/material.dart';

extension AppBarExtensions on BuildContext {
  TextStyle get comicTitleText => const TextStyle(
    color: Colors.black,
    fontSize: 30,
    fontFamily: 'Hey-Comic',
    fontWeight: FontWeight.bold,
  );
}
