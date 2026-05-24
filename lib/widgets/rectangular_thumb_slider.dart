import 'package:flutter/material.dart';

class RectangularThumbSlider extends SliderComponentShape {
  final double width;
  final double height;
  final double radius;

  const RectangularThumbSlider({
    this.width = 20,
    this.height = 20,
    this.radius = 4,
  });

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) {
    return Size(width, height);
  }

  @override
  void paint(PaintingContext context, Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    context.canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: center, width: width, height: height),
        Radius.circular(radius),
      ),
      Paint()..color = sliderTheme.thumbColor!,
    );
  }
}
