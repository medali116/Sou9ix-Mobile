import 'package:flutter/widgets.dart';

/// Lets any screen (e.g. the persistent live-camera Caisse tab) know when
/// another route has been pushed on top of it, so it can release the
/// camera instead of holding it while it's fully hidden.
final routeObserver = RouteObserver<PageRoute<void>>();
