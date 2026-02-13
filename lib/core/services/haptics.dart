class Haptics {
  Haptics._();

  static bool _enabled = true;
  static bool get enabled => _enabled;
  static void setEnabled(bool v) {
    _enabled = v;
  }

  // macOS-only build: keep API surface as no-op.
  static void light() {}
  static void medium() {}
  static void soft() {}
  static void drawerPulse() {}
  static void cancel() {}
}
