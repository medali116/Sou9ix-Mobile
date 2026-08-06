import 'package:flutter_riverpod/flutter_riverpod.dart';

/// This device's shop code, seeded once at app startup (see `main()` in
/// `main_admin.dart`/`main_caissier.dart`, which read it from
/// [ShopCodeStorage] before `runApp` and pass it in via a `ProviderScope`
/// override) — every Firestore repository reads its `shops/{shopCode}/...`
/// path from here rather than re-reading local storage itself.
///
/// A [StateProvider], not a plain [Provider], because it can also change
/// *within* a running session: the Caissier app's [EnterShopCodeScreen]
/// persists a freshly-validated code to [ShopCodeStorage] and must also
/// push it here immediately (`ref.read(shopCodeProvider.notifier).state =
/// code`) so repositories pick it up without needing an app restart.
final shopCodeProvider = StateProvider<String?>(
  (ref) => throw UnimplementedError(
    'shopCodeProvider must be overridden in main() before runApp — '
    'see main_admin.dart / main_caissier.dart.',
  ),
);
