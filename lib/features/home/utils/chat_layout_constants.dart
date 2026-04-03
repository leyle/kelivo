/// Shared layout constants for the Home chat UI (desktop/tablet).
class ChatLayoutConstants {
  /// Base readable width when both sidebars are visible.
  static const double baseWidth = 980.0;

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

  /// Computes left/right padding for the content area.
  ///
  /// When both sidebars are open (or both hidden): centers in the content area.
  /// When only one sidebar is open: centers on the full window.
  static ({double left, double right}) paddingForWindowCenter({
    required double contentAreaWidth,
    double leftSidebarWidth = 0,
    double rightSidebarWidth = 0,
  }) {
    final maxContent = maxWidthForAvailable(contentAreaWidth);
    final bothOpen = leftSidebarWidth > 0 && rightSidebarWidth > 0;
    final bothHidden = leftSidebarWidth == 0 && rightSidebarWidth == 0;

    if (bothOpen || bothHidden) {
      // Center within the content area.
      final pad = ((contentAreaWidth - maxContent) / 2)
          .clamp(0.0, double.infinity);
      return (left: pad, right: pad);
    }

    // One sidebar open — center on the full window.
    final fullWindow = leftSidebarWidth + contentAreaWidth + rightSidebarWidth;
    final contentLeft = (fullWindow - maxContent) / 2;
    final leftPad = (contentLeft - leftSidebarWidth).clamp(0.0, double.infinity);
    final rightPad = (contentAreaWidth - maxContent - leftPad).clamp(0.0, double.infinity);
    return (left: leftPad, right: rightPad);
  }

  /// Max readable width for the chat message list area.
  static const double maxContentWidth = baseWidth;

  /// Max width for the chat input bar area.
  static const double maxInputWidth = baseWidth;
}
