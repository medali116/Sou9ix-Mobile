import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Holds the client attached to the sale in progress via "Scanner client"
/// (before the cart reaches checkout), so the checkout screen can
/// pre-select them for a crédit (karné) payment.
final pendingClientProvider = StateProvider<String?>((ref) => null);
