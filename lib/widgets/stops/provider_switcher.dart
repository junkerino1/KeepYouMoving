import 'package:flutter/material.dart';
import '../../models/transit_provider.dart';
import '../../theme/app_theme.dart';

/// Short display label for a provider key (e.g. `Rapid KL`).
String providerShortLabelForKey(String providerKey) {
  switch (providerKey) {
    case 'rapid_bus_kl':
      return 'Rapid KL';
    case 'rapid_bus_mrtfeeder':
      return 'MRT Feeder';
    default:
      return providerKey;
  }
}

/// Short display label for a provider (e.g. `Rapid KL`).
String providerShortLabel(TransitProvider provider) =>
    providerShortLabelForKey(provider.providerKey);

/// Segmented toggle to switch the active provider. Communicates the selection
/// back through [onSelected]; all business logic stays in the caller.
class ProviderSwitcher extends StatelessWidget {
  final List<TransitProvider> providers;
  final TransitProvider? selectedProvider;
  final ValueChanged<TransitProvider> onSelected;

  const ProviderSwitcher({
    super.key,
    required this.providers,
    required this.selectedProvider,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: providers.map((provider) {
          final selected = selectedProvider?.id == provider.id;
          final providerTheme = ProviderTheme.of(provider.providerKey);
          final label = providerShortLabel(provider);
          return Expanded(
            child: Semantics(
              button: true,
              selected: selected,
              label: label,
              child: Material(
                color:
                    selected ? providerTheme.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(9),
                child: InkWell(
                  onTap: () => onSelected(provider),
                  borderRadius: BorderRadius.circular(9),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.directions_bus_rounded,
                          size: 14,
                          color: selected
                              ? providerTheme.onPrimary
                              : scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            label,
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: selected
                                      ? providerTheme.onPrimary
                                      : scheme.onSurfaceVariant,
                                ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
