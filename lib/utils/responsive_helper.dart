import 'package:flutter/material.dart';

class ResponsiveHelper {
  static double bottomSafe(BuildContext context) {
    return MediaQuery.of(context).padding.bottom;
  }

  static double keyboard(BuildContext context) {
    return MediaQuery.of(context).viewInsets.bottom;
  }

  static double appBottomNavSpace(BuildContext context) {
    return MediaQuery.of(context).padding.bottom + 120;
  }

  static EdgeInsets pagePadding(BuildContext context) {
    return EdgeInsets.fromLTRB(16, 16, 16, appBottomNavSpace(context));
  }

  static EdgeInsets formPadding(BuildContext context) {
    return EdgeInsets.fromLTRB(
      24,
      16,
      24,
      MediaQuery.of(context).viewInsets.bottom + 30,
    );
  }

  static EdgeInsets sheetPadding(BuildContext context) {
    return EdgeInsets.fromLTRB(
      16,
      16,
      16,
      MediaQuery.of(context).viewInsets.bottom +
          MediaQuery.of(context).padding.bottom +
          16,
    );
  }
}
