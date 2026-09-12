/// Tests de TvFocusable : highlight au focus + scroll-vers-focus.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terebi/src/ui/widgets/tv_focusable.dart';

void main() {
  group('TvFocusable — highlight', () {
    testWidgets('scale 1.0 sans focus, 1.08 avec focus', (tester) async {
      final node = FocusNode();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TvFocusable(
            focusNode: node,
            child: const SizedBox(width: 100, height: 100),
          ),
        ),
      ));

      AnimatedScale scaleOf() =>
          tester.widget<AnimatedScale>(find.byType(AnimatedScale));
      expect(scaleOf().scale, 1.0);

      node.requestFocus();
      await tester.pumpAndSettle();
      expect(scaleOf().scale, 1.08);
    });

    testWidgets('bordure blanche visible au focus', (tester) async {
      final node = FocusNode();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TvFocusable(
            focusNode: node,
            child: const SizedBox(width: 100, height: 100),
          ),
        ),
      ));
      node.requestFocus();
      await tester.pumpAndSettle();

      final container = tester.widget<AnimatedContainer>(
        find.byType(AnimatedContainer),
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.border!.top.color, Colors.white);
    });

    testWidgets('OK/select déclenche onPressed', (tester) async {
      final node = FocusNode();
      var pressed = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TvFocusable(
            focusNode: node,
            onPressed: () => pressed = true,
            child: const SizedBox(width: 100, height: 100),
          ),
        ),
      ));
      node.requestFocus();
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      expect(pressed, isTrue);
    });
  });
}
