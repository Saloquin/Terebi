/// Tests de TvSlideIndicators : plafonnement des points pour ne jamais
/// déborder la largeur de l'écran (régression: un point par item faisait
/// déborder le Row du hero de 192px et cassait le layout en cascade).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terebi/src/ui/tv/widgets/tv_slide_indicators.dart';

void main() {
  group('TvSlideIndicators — plafonnement', () {
    testWidgets('affiche un point par item quand peu nombreux', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: TvSlideIndicators(count: 5, current: 2),
        ),
      ));

      expect(find.byType(AnimatedContainer), findsNWidgets(5));
    });

    testWidgets('plafonne à maxDots quand trop nombreux', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: TvSlideIndicators(count: 50, current: 0),
        ),
      ));

      expect(
        find.byType(AnimatedContainer),
        findsNWidgets(TvSlideIndicators.maxDots),
      );
    });

    testWidgets(
        'avec beaucoup d\'items dans une largeur contrainte, aucune exception '
        'de layout (régression: débordement 192px + infinite width)',
        (tester) async {
      // Reproduit la contrainte du hero : Positioned(left:0,right:0) sur un
      // écran TV 1920px -> largeur ~960px après gradients. 50 points non
      // plafonnés déborderaient largement.
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 960,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: TvSlideIndicators(count: 50, current: 25),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('la fenêtre glissante garde le point courant visible',
        (tester) async {
      // current en fin de liste : le start doit être clampé pour rester valide.
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: TvSlideIndicators(count: 50, current: 49),
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        find.byType(AnimatedContainer),
        findsNWidgets(TvSlideIndicators.maxDots),
      );
    });
  });
}
