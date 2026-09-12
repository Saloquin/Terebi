/// Tests de TvFocusScope : pont navbar ↔ contenu.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terebi/src/ui/tv/widgets/tv_focus_scope.dart';

void main() {
  group('TvFocusScope — pont navbar/contenu', () {
    testWidgets('focusContent restaure le dernier enfant focalisé',
        (tester) async {
      final controller = TvFocusController();
      final navNode = FocusNode(debugLabel: 'nav');
      final contentA = FocusNode(debugLabel: 'contentA');
      final contentB = FocusNode(debugLabel: 'contentB');

      await tester.pumpWidget(MaterialApp(
        home: TvFocusScope(
          controller: controller,
          navBar: Focus(focusNode: navNode, child: const SizedBox()),
          content: Column(
            children: [
              Focus(focusNode: contentA, child: const SizedBox()),
              Focus(focusNode: contentB, child: const SizedBox()),
            ],
          ),
        ),
      ));

      // La navbar est le point d'entrée : navNode a le focus au départ.
      navNode.requestFocus();
      await tester.pump();

      // L'utilisateur descend dans le contenu et focalise contentB, puis remonte.
      contentB.requestFocus();
      await tester.pump();
      controller.focusNavBar();
      await tester.pump();
      expect(navNode.hasFocus, isTrue);

      // arrowDown : le focus revient à contentB (dernier focalisé), pas contentA.
      controller.focusContent();
      await tester.pump();
      expect(contentB.hasFocus, isTrue);
    });

    testWidgets('focusNavBar restaure le dernier élément navbar focalisé',
        (tester) async {
      final controller = TvFocusController();
      final navNode1 = FocusNode(debugLabel: 'nav1');
      final navNode2 = FocusNode(debugLabel: 'nav2');
      final contentNode = FocusNode(debugLabel: 'content');

      await tester.pumpWidget(MaterialApp(
        home: TvFocusScope(
          controller: controller,
          navBar: Row(
            children: [
              Focus(focusNode: navNode1, child: const SizedBox()),
              Focus(focusNode: navNode2, child: const SizedBox()),
            ],
          ),
          content: Focus(focusNode: contentNode, child: const SizedBox()),
        ),
      ));

      // L'utilisateur navigue jusqu'à nav2, puis descend dans le contenu.
      navNode2.requestFocus();
      await tester.pump();
      controller.focusContent();
      await tester.pump();
      expect(contentNode.hasFocus, isFalse); // contentScope n'a pas d'historique

      // Remonte : doit revenir à nav2, pas nav1 (defaultNavNode).
      controller.focusNavBar();
      await tester.pump();
      expect(navNode2.hasFocus, isTrue);
    });
  });
}
