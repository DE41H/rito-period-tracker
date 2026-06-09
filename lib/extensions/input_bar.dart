import 'package:flutter/material.dart';

extension InputBarExtensions on BuildContext {
  TextStyle get comicInputText => const TextStyle(
    fontFamily: 'Hey-Comic',
    color: Colors.black,
  );

  TextStyle get comicButtonText => const TextStyle(
    fontFamily: 'Hey-Comic',
    fontSize: 16,
    color: Colors.black,
    fontWeight: FontWeight.bold,
  );
}
