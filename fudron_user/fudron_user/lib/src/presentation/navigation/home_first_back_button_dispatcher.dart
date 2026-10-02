import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'app_router.dart';
import 'route_names.dart';

/// Sends the system/gesture back button Home before it ever gets a chance to
/// close the app.
///
/// [RootBackButtonDispatcher.didPopRoute] (Flutter's default) resolves to
/// `false` whenever nothing in the navigator stack can pop or veto the pop —
/// which is exactly what happens on a screen reached via `go()` (e.g. cart
/// checkout replacing the stack with `/orders`) or a cold-started deep link /
/// notification tap, both of which replace navigation history instead of
/// pushing onto it. A `false` here is the platform's own signal that nothing
/// handled the back press, so Android just finishes the Activity — that is
/// the bug: back closing Orders/Profile/Cart/Search instantly instead of
/// returning Home.
///
/// [super.didPopRoute] already walks every active navigator, innermost branch
/// first, and honors any [PopScope] registered along the way (e.g. the exit
/// dialog on Home, or the branch-switch-then-exit-dialog logic in
/// MainAppShell for the Cart/Store99/Profile tabs) — none of that changes.
/// This only steps in for what's left over: nothing anywhere could pop. Since
/// Home always carries a PopScope of its own, that leftover case only occurs
/// on a non-Home screen, so the correct move is always Home — never letting
/// the platform close the app out from under it.
class HomeFirstBackButtonDispatcher extends RootBackButtonDispatcher {
  @override
  Future<bool> didPopRoute() async {
    if (await super.didPopRoute()) return true;

    final context = rootNavigatorKey.currentContext;
    if (context == null || !context.mounted) return false;
    GoRouter.of(context).go(RouteNames.home);
    return true;
  }
}
