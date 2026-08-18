import 'package:flutter/material.dart';

class AppMotion {
  const AppMotion._();

  static const microDuration = Duration(milliseconds: 180);
  static const transitionDuration = Duration(milliseconds: 300);
  static const staggerStep = Duration(milliseconds: 40);
  static const entranceCurve = Curves.easeOutQuart;
  static const microCurve = Curves.easeOutCubic;

  static Duration durationOrInstant(BuildContext context, Duration duration) =>
      MediaQuery.of(context).disableAnimations ? Duration.zero : duration;
}
