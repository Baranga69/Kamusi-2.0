import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/app_providers.dart';

/// Wraps the app and says, quietly, when what you are reading is a saved copy.
///
/// Showing stale content without saying so would be worse than an error: a
/// dictionary has to be trustworthy about what it knows. The banner is calm
/// rather than alarming, per DESIGN_SYSTEM.md — nothing is broken, there is
/// just no connection.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.watch(servingCachedDataProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return ValueListenableBuilder<bool>(
      valueListenable: notifier,
      builder: (context, offline, _) {
        if (!offline) {
          return child;
        }
        final l10n = AppLocalizations.of(context);
        return Column(
          children: [
            Material(
              color: colorScheme.secondaryContainer,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.cloud_off_outlined,
                        size: 18,
                        color: colorScheme.onSecondaryContainer,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          l10n?.offlineBanner ?? 'Offline — showing saved words.',
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSecondaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(child: child),
          ],
        );
      },
    );
  }
}
