import 'dart:ui';

import 'package:flutter/material.dart';

class GreyscaleImage extends StatelessWidget {
  final String imagePath;
  final bool enable;

  GreyscaleImage({required this.imagePath, required this.enable});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.width /
          4, // Ensuring the buttons are square
      child: enable
          ? Image.asset(
              imagePath,
              fit: BoxFit.cover,
            )
          : ColorFiltered(
              colorFilter: ColorFilter.matrix(_greyscaleColorMatrix),
              child: Image.asset(
                imagePath,
                fit: BoxFit.cover,
              ),
            ),
    );
  }

  // Greyscale color matrix
  static const List<double> _greyscaleColorMatrix = <double>[
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ];
}
