import 'package:shared_preferences/shared_preferences.dart';

/// Remembers which shop this *device* is bound to, once a caissier enters
/// the shop code on their first login here — so it's never typed again on
/// this device afterwards. Deliberately local/per-device rather than tied to
/// any one employee: any caissier logging in later on the same device shares
/// the binding, matching how a shared shop tablet is actually used.
class ShopCodeStorage {
  static const _key = 'bound_shop_code';

  Future<String?> read() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }

  Future<void> save(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, code);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
