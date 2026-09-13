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

  group('TvFocusable — scroll-vers-focus', () {
    testWidgets('focus sur une tuile hors du viewport la ramène en vue',
        (tester) async {
      // Viewport 250px, 5 tuiles de 100px (total 500px). La dernière tuile
      // (400–500px) est hors du viewport visible mais dans le cacheExtent par
      // défaut (250px), donc montée — comme lors d'une navigation D-pad de
      // proche en proche. ensureVisible doit alors défiler jusqu'à elle.
      final controller = ScrollController();
      final lastNode = FocusNode();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 250,
            child: ListView(
              controller: controller,
              children: [
                for (int i = 0; i < 5; i++)
                  TvFocusable(
                    focusNode: i == 4 ? lastNode : null,
                    child: const SizedBox(height: 100, width: 100),
                  ),
              ],
            ),
          ),
        ),
      ));

      // Au départ, la liste est en haut (offset 0).
      expect(controller.offset, 0);

      lastNode.requestFocus();
      await tester.pumpAndSettle();

      // ensureVisible a défilé la liste pour rendre la dernière tuile visible.
      expect(controller.offset, greaterThan(0));
    });

    testWidgets('sans Scrollable ancêtre, aucun crash au focus',
        (tester) async {
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
      // Pas d'exception levée = test réussi.
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'dans une ListView horizontale, une tuile de largeur fixe ne provoque '
        'aucune exception de layout (régression: Center forçait une largeur '
        'infinie et cassait le hit-test/focus)', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 5,
              // Reproduit la structure de TvContentRow : Column mainAxisSize.min
              // + tuile de largeur fixe. Un Center à la place forcerait une
              // largeur infinie sur l'axe de défilement horizontal.
              itemBuilder: (context, i) => Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TvFocusable(
                    child: const SizedBox(width: 120, height: 68),
                  ),
                ],
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
