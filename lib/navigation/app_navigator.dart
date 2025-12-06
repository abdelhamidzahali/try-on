import 'package:flutter/material.dart';

class AppNavigator {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  // Bottom tab coordination
  static final ValueNotifier<int> tabIndex = ValueNotifier<int>(0);

  static void goHome() => tabIndex.value = 0;
  static void goHistory() => tabIndex.value = 1;
  static void goSettings() => tabIndex.value = 2;
}
