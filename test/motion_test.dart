import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawfolio/motion.dart';

void main() {
  testWidgets('returns the given duration when animations are enabled', (tester) async {
    late Duration result;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: false),
        child: Builder(
          builder: (context) {
            result = AppMotion.durationOrInstant(context, AppMotion.microDuration);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(result, AppMotion.microDuration);
  });

  testWidgets('collapses to zero when reduced motion is enabled', (tester) async {
    late Duration result;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Builder(
          builder: (context) {
            result = AppMotion.durationOrInstant(context, AppMotion.microDuration);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(result, Duration.zero);
  });
}
