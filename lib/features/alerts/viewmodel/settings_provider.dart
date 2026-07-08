import 'package:flutter_riverpod/flutter_riverpod.dart';

/// How many days ahead of a product's expiry date it should start showing
/// up as "expire bientôt" in the Alertes screen. Adjustable by the user.
final expiryWarningDaysProvider = StateProvider<int>((ref) => 7);
