import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sou9ix/features/auth/model/user.dart';

class AuthNotifier extends StateNotifier<AppUser?> {
  AuthNotifier() : super(null);

  void loginAsAdmin() {
    state = const AppUser(
      id: 'u_admin',
      nom: 'Yassine Karoui',
      email: 'yassine@sou9ix.tn',
      telephone: '+216 20 123 456',
      role: UserRole.admin,
      magasin: 'Épicerie El Baraka — La Marsa',
      employeeId: 'e1',
    );
  }

  void loginAsCaissier() {
    state = const AppUser(
      id: 'u_caissier',
      nom: 'Rania Mejri',
      email: 'rania@sou9ix.tn',
      telephone: '+216 22 987 654',
      role: UserRole.caissier,
      magasin: 'Épicerie El Baraka — La Marsa',
      employeeId: 'e2',
    );
  }

  void logout() => state = null;

  void updateProfile({
    String? nom,
    String? email,
    String? telephone,
    String? magasin,
    Uint8List? photoBytes,
  }) {
    final current = state;
    if (current == null) return;
    state = current.copyWith(
      nom: nom,
      email: email,
      telephone: telephone,
      magasin: magasin,
      photoBytes: photoBytes,
    );
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AppUser?>(
  (ref) => AuthNotifier(),
);
