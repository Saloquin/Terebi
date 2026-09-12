/// Test de fumée : garantit que le shell TV et ses primitives de focus
/// compilent et exposent l'API attendue (pont navbar ↔ contenu).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terebi/src/ui/tv/app_shell_tv.dart';
import 'package:terebi/src/ui/tv/widgets/tv_focus_scope.dart';

void main() {
  group('AppShellTv — intégration focus', () {
    test('TvFocusScopeProvider expose un TvFocusController via maybeOf', () {
      // Vérifie la surface d'API utilisée par les pages TV pour remonter le
      // focus à la navbar. Le type de retour doit être TvFocusController?.
      const TvFocusController? Function(BuildContext) fn =
          TvFocusScopeProvider.maybeOf;
      expect(fn, isNotNull);
    });

    testWidgets('TvFocusScopeProvider fournit le contrôleur aux descendants',
        (tester) async {
      final controller = TvFocusController();
      TvFocusController? seen;

      await tester.pumpWidget(MaterialApp(
        home: TvFocusScopeProvider(
          controller: controller,
          child: Builder(
            builder: (context) {
              seen = TvFocusScopeProvider.maybeOf(context);
              return const SizedBox();
            },
          ),
        ),
      ));

      expect(seen, same(controller));
      controller.dispose();
    });
  });
}
