// TODO: Figure out if I need this file...
import 'package:flutter/material.dart';

const Map<String, Color> carColors = {
  "white": Colors.white,
  "black": Colors.black,
  "gray": Colors.grey,
  "blue": Colors.blue,
  "orange": Colors.orange,
  "purple": Colors.purple,
  "green": Colors.green,
  "yellow": Colors.yellow,
  "pink": Colors.pink,
  "red": Colors.red
};

String? getColorName(Color color) {
  for (var colorName in carColors.keys) {
    // Convert to ARGB32 in order to avoid floating-point imprecision.
    if (color.toARGB32() == carColors[colorName]?.toARGB32()) return colorName;
  }

  return null;
}