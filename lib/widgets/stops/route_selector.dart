import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Route identity header: line badge plus origin → destination labels.
class RouteSelector extends StatelessWidget {
  final String displayLine;
  final String originLabel;
  final String destinationLabel;

  const RouteSelector({
    super.key,
    required this.displayLine,
    required this.originLabel,
    required this.destinationLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.navy,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                displayLine,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                  color: AppColors.white,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.directions_bus,
                  size: 14, color: AppColors.white),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.navyBorder),
                  ),
                  child: Text(
                    originLabel,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.navyTextSecondary),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Text('→',
                    style: TextStyle(
                        fontSize: 11, color: AppColors.navyTextHint)),
              ),
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                  decoration: BoxDecoration(
                    color: AppColors.navyVeryLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    destinationLabel,
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.navyTextPrimary),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
