import 'package:shared_preferences/shared_preferences.dart';

/// Persists the shop code an employee typed once on first launch, so the
/// Caissier app never has to ask for it again on that device.
class ShopCodeStorage {
  static const _key = 'shop_code';

  static Future<String?> read() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }

  static Future<void> save(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, code);
  }
}
