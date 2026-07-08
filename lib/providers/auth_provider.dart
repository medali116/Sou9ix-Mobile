import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user.dart';

class AuthNotifier extends StateNotifier<AppUser?> {
  AuthNotifier() : super(null);

  void loginAsAdmin() {
    state = const AppUser(
      id: 'u_admin',
      nom: 'Yassine Karoui',
      email: 'yassine@sou9ix.tn',
      role: UserRole.admin,
      magasin: 'Épicerie El Baraka — La Marsa',
    );
  }

  void loginAsCaissier() {
    state = const AppUser(
      id: 'u_caissier',
      nom: 'Rania Mejri',
      email: 'rania@sou9ix.tn',
      role: UserRole.caissier,
      magasin: 'Épicerie El Baraka — La Marsa',
    );
  }

  void logout() => state = null;
}

final authProvider = StateNotifierProvider<AuthNotifier, AppUser?>(
  (ref) => AuthNotifier(),
);
