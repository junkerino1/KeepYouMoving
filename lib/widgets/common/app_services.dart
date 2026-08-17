import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/favourite_service.dart';

/// Provides [AuthService] and [FavouriteService] to the widget tree.
class AppServices extends InheritedWidget {
  final AuthService authService;
  final FavouriteService favouriteService;

  const AppServices({
    super.key,
    required this.authService,
    required this.favouriteService,
    required super.child,
  });

  static AppServices of(BuildContext context) {
    final widget = context.dependOnInheritedWidgetOfExactType<AppServices>();
    assert(widget != null, 'No AppServices found in context');
    return widget!;
  }

  static AuthService auth(BuildContext context) => of(context).authService;
  static FavouriteService favs(BuildContext context) =>
      of(context).favouriteService;

  @override
  bool updateShouldNotify(AppServices oldWidget) =>
      authService != oldWidget.authService ||
      favouriteService != oldWidget.favouriteService;
}
