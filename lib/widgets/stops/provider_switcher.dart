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
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.navyVeryLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.navyBorder),
      ),
      child: Row(
        children: providers.map((provider) {
          final selected = selectedProvider?.id == provider.id;
          final theme = ProviderTheme.of(provider.providerKey);
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelected(provider),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: selected ? theme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.directions_bus_rounded,
                      size: 13,
                      color: selected
                          ? theme.onPrimary
                          : AppColors.navyTextSecondary,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        providerShortLabel(provider),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: selected
                              ? theme.onPrimary
                              : AppColors.navyTextSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
