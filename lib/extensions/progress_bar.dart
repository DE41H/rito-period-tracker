import 'package:flutter/material.dart';

extension WidgetExtension on Widget {
  Widget align(Alignment alignment) => Align(alignment: alignment, child: this);
  Widget paddingAll(double value) => Padding(padding: EdgeInsetsGeometry.all(value), child: this);
}
