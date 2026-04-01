/// Shared layout constants for the Home chat UI (desktop/tablet).
class ChatLayoutConstants {
  /// Base readable width when both sidebars are visible.
  static const double baseWidth = 860.0;

  /// Wider width when one sidebar is hidden.
  static const double wideWidth = 1040.0;

  /// Widest width when both sidebars are hidden.
  static const double widestWidth = 1200.0;

  /// Returns the appropriate max content/input width based on available space.
  static double maxWidthForAvailable(double available) {
    if (available >= 1650) return widestWidth;
    if (available >= 1350) return wideWidth;
    return baseWidth;
  }

  /// Max readable width for the chat message list area.
  static const double maxContentWidth = baseWidth;

  /// Max width for the chat input bar area.
  static const double maxInputWidth = baseWidth;
}
