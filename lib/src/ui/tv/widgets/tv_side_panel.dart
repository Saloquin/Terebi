library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../widgets/tv_focusable.dart';

class TvSidePanelItem {
  final String label;
  final dynamic value;
  const TvSidePanelItem({required this.label, required this.value});
}

/// Panneau latéral gauche pour sélectionner un item au D-pad.
/// Largeur fixe 280px, fond semi-opaque, liste verticale TvFocusable.
/// Fermeture : flèche droite depuis le panneau, ou appel de [onClose].
class TvSidePanel extends StatelessWidget {
  final String title;
  final List<TvSidePanelItem> items;
  final void Function(TvSidePanelItem) onSelected;
  final VoidCallback onClose;

  const TvSidePanel({
    super.key,
    required this.title,
    required this.items,
    required this.onSelected,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Focus(
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.arrowRight) {
          onClose();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Container(
        width: 280,
        color: Colors.black87,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Divider(color: Colors.white24, height: 1),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: items.length,
                itemBuilder: (context, i) {
                  final item = items[i];
                  return TvFocusable(
                    autofocus: i == 0,
                    onPressed: () => onSelected(item),
                    child: GestureDetector(
                      onTap: () => onSelected(item),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        child: Text(
                          item.label,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 15),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
