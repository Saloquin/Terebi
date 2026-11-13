/// Test de fumée : garantit que le shell TV et ses primitives de focus
/// compilent et exposent l'API attendue (pont navbar ↔ contenu).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terebi/src/ui/tv/widgets/tv_focus_scope.dart';

void main() {
  group('AppShellTv — intégration focus', () {
    testWidgets('TvFocusScope intègre navBar et content avec son contrôleur',
        (tester) async {
      final controller = TvFocusController();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TvFocusScope(
            controller: controller,
            navBar: const Text('NavBar'),
            content: const Text('Content'),
          ),
        ),
      ));

      expect(find.text('NavBar'), findsOneWidget);
      expect(find.text('Content'), findsOneWidget);
      controller.dispose();
    });
  });
}
