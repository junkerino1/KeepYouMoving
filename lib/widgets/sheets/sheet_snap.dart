/// Shared bottom-sheet snap heights for the live-map and stop-detail sheets.
///
/// Both sheets use the same compact / medium / expanded set so their drag
/// behaviour feels identical. Medium is the resting (default) height.
const double kSheetMinHeight = 140.0;
const double kSheetCompactHeight = 140.0;
const double kSheetMediumHeight = 380.0;
const double kSheetExpandedHeight = 600.0;
const double kSheetDefaultHeight = kSheetMediumHeight;

/// Ordered compact → expanded snap points.
const List<double> kSheetSnapHeights = [
  kSheetCompactHeight,
  kSheetMediumHeight,
  kSheetExpandedHeight,
];
