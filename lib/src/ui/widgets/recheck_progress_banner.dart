/// Bandeau compact affichant la progression d'actualisation en arrière-plan
/// de la bibliothèque (Desktop, Android TV et Mobile).
library;

import 'package:flutter/material.dart';

class RecheckProgressBanner extends StatelessWidget {
  final bool visible;
  final int current;
  final int total;
  final String? currentTitle;

  const RecheckProgressBanner({
    super.key,
    required this.visible,
    required this.current,
    required this.total,
    this.currentTitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final progress = total > 0 ? (current / total).clamp(0.0, 1.0) : 0.0;

    return ClipRect(
      child: AnimatedSize(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        alignment: Alignment.bottomCenter,
        child: visible
            ? Material(
                color: colorScheme.surfaceContainerHighest,
                elevation: 4,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                      tween: Tween<double>(begin: 0.0, end: progress),
                      builder: (context, val, _) {
                        return LinearProgressIndicator(
                          value: total > 0 ? val : null,
                          minHeight: 3,
                          backgroundColor: colorScheme.surfaceContainerHighest,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            colorScheme.primary,
                          ),
                        );
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Actualisation de la bibliothèque',
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          if (currentTitle != null &&
                              currentTitle!.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Text(
                              '•',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.6),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                currentTitle!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ] else
                            const Spacer(),
                          const SizedBox(width: 12),
                          Text(
                            '$current / $total · ${(progress * 100).toInt()}%',
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}
