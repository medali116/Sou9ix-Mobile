import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Lets any screen inside [MainShell] (e.g. the dashboard's "Actions
/// rapides" row) jump straight to another bottom-nav tab without a route
/// push. [MainShell] consumes the value once via `ref.listen` and resets it
/// to null right after switching tabs.
final requestedTabIndexProvider = StateProvider<int?>((ref) => null);
