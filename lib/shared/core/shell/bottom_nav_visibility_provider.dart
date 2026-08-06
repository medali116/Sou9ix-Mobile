import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Lets a scrollable tab (e.g. the Stock list) hide the floating bottom
/// nav while the user scrolls down, and reveal it again on scroll up.
final bottomNavVisibleProvider = StateProvider<bool>((ref) => true);
