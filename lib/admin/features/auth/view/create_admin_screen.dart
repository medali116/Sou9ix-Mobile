import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sou9ix/shared/features/auth/service/admin_auth_service.dart';
import 'package:sou9ix/shared/features/auth/viewmodel/auth_provider.dart';
import 'package:sou9ix/shared/features/employees/model/employee.dart';
import 'package:sou9ix/shared/features/employees/viewmodel/employees_provider.dart';
import 'package:sou9ix/shared/features/settings/model/company_settings.dart';
import 'package:sou9ix/shared/features/settings/service/shop_code_storage.dart';
import 'package:sou9ix/shared/features/settings/viewmodel/company_settings_provider.dart';
import 'package:sou9ix/shared/features/settings/viewmodel/shop_code_provider.dart';
import 'package:sou9ix/shared/core/theme/app_colors.dart';
import 'package:sou9ix/shared/core/theme/app_theme.dart';

final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// Reached via "Créer mon espace" on [AdminLoginScreen] — always
/// available there, unlike an employee record (added only by an admin,
/// from the Employés screen). Every submission writes a fresh
/// [CompanySettings] (this app models a single shop, so re-running this
/// renames/reconfigures the existing one rather than adding a second) and
/// a new admin [Employee], then signs straight into it.
class CreateAdminScreen extends ConsumerStatefulWidget {
  const CreateAdminScreen({super.key});

  @override
  ConsumerState<CreateAdminScreen> createState() => _CreateAdminScreenState();
}

class _CreateAdminScreenState extends ConsumerState<CreateAdminScreen> {
  int _step = 0;
  String? _error;
  bool _loading = false;

  // Étape 1 — Votre compte
  final _nomCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  bool _obscurePass = true;
  bool _obscureConfirmPass = true;

  // Étape 2 — Votre commerce
  final _nomCommerceCtrl = TextEditingController();
  TypeActivite _typeActivite = TypeActivite.epicerie;
  final _telCommerceCtrl = TextEditingController();
  final _villeCtrl = TextEditingController();

  // Étape 3 — Sécurité
  final _pinCtrl = TextEditingController();
  final _confirmPinCtrl = TextEditingController();
  bool _obscurePin = true;
  bool _obscureConfirmPin = true;
  bool _acceptedTerms = false;

  @override
  void dispose() {
    _nomCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmPassCtrl.dispose();
    _nomCommerceCtrl.dispose();
    _telCommerceCtrl.dispose();
    _villeCtrl.dispose();
    _pinCtrl.dispose();
    _confirmPinCtrl.dispose();
    super.dispose();
  }

  String? _validateStep0() {
    final nom = _nomCtrl.text.trim();
    if (nom.isEmpty) return 'Entrez votre nom complet.';
    final normalized = normalizeEmployeeName(nom);
    final employees = ref.read(activeEmployeesProvider);
    if (employees.any((e) => normalizeEmployeeName(e.nom) == normalized)) {
      return 'Un employé actif nommé "$nom" existe déjà — utilisez un nom complet différent.';
    }
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !_emailPattern.hasMatch(email)) {
      return 'Adresse e-mail invalide.';
    }
    final normalizedEmail = email.toLowerCase();
    if (employees.any((e) => e.loginEmail.toLowerCase() == normalizedEmail)) {
      return 'Un compte utilise déjà cette adresse e-mail.';
    }
    final pass = _passCtrl.text;
    final hasLetter = pass.contains(RegExp(r'[A-Za-z]'));
    final hasDigit = pass.contains(RegExp(r'[0-9]'));
    if (pass.length < 8 || !hasLetter || !hasDigit) {
      return 'Le mot de passe doit contenir au moins 8 caractères, avec au moins une lettre et un chiffre.';
    }
    if (_confirmPassCtrl.text != pass) {
      return 'Les mots de passe ne correspondent pas.';
    }
    return null;
  }

  String? _validateStep1() {
    if (_nomCommerceCtrl.text.trim().isEmpty) {
      return 'Entrez le nom de votre commerce.';
    }
    return null;
  }

  String? _validateStep2() {
    final pin = _pinCtrl.text.trim();
    if (pin.length < 4 || pin.length > 6) {
      return 'Le code PIN doit contenir 4 à 6 chiffres.';
    }
    if (isWeakPin(pin)) {
      return 'Ce code PIN est trop simple (ex. 1234, 0000) — choisissez-en un autre.';
    }
    if (_confirmPinCtrl.text.trim() != pin) {
      return 'Les codes PIN ne correspondent pas.';
    }
    if (!_acceptedTerms) {
      return 'Vous devez accepter les conditions d\'utilisation pour continuer.';
    }
    return null;
  }

  void _next() {
    final error = switch (_step) {
      0 => _validateStep0(),
      1 => _validateStep1(),
      _ => null,
    };
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() {
      _error = null;
      _step++;
    });
  }

  void _back() => setState(() {
    _error = null;
    _step--;
  });

  Future<void> _submit() async {
    final error = _validateStep2();
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() {
      _error = null;
      _loading = true;
    });

    final nomCommerce = _nomCommerceCtrl.text.trim();
    final adminNom = _nomCtrl.text.trim();

    final AdminAuthResult result;
    try {
      result = await ref
          .read(adminAuthServiceProvider)
          .signUp(
            name: adminNom,
            email: _emailCtrl.text.trim(),
            password: _passCtrl.text,
            pin: _pinCtrl.text.trim(),
          );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = firebaseAuthErrorMessage(e);
      });
      return;
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error =
            'Impossible de créer votre compte — vérifiez votre connexion internet et réessayez.';
      });
      return;
    }
    final companyCode = result.shopCode;

    await ShopCodeStorage.save(companyCode);
    if (!mounted) return;
    ref.read(shopCodeProvider.notifier).state = companyCode;

    ref
        .read(companySettingsProvider.notifier)
        .updateStoreInfo(
          nom: nomCommerce,
          typeActivite: _typeActivite,
          telephone: _telCommerceCtrl.text.trim().isEmpty
              ? null
              : _telCommerceCtrl.text.trim(),
          ville: _villeCtrl.text.trim().isEmpty ? null : _villeCtrl.text.trim(),
        );
    ref.read(companySettingsProvider.notifier).setCompanyCode(companyCode);

    ref.read(authProvider.notifier).loginAsEmployee(result.employee);
    if (mounted) context.go('/app');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Créer votre espace Sou9ix')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          children: [
            Text(
              'Étape ${_step + 1}/3',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textFaint,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              switch (_step) {
                0 => 'Votre compte',
                1 => 'Votre commerce',
                _ => 'Sécurité',
              },
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            if (_step == 0) ..._buildStep0(),
            if (_step == 1) ..._buildStep1(),
            if (_step == 2) ..._buildStep2(),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: const TextStyle(
                  color: AppColors.danger,
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                ),
              ),
            ],
            const SizedBox(height: 22),
            Row(
              children: [
                if (_step > 0) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _loading ? null : _back,
                      child: const Text('Retour'),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _loading ? null : (_step < 2 ? _next : _submit),
                    child: _loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: Colors.white,
                            ),
                          )
                        : Text(_step < 2 ? 'Suivant' : 'Créer mon espace'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildStep0() => [
    _buildField(
      label: 'Nom complet',
      controller: _nomCtrl,
      icon: Icons.person_outline_rounded,
      hint: 'Ex. Yassine Karoui',
      onChanged: (_) => setState(() => _error = null),
    ),
    const SizedBox(height: 16),
    _buildField(
      label: 'Adresse e-mail',
      controller: _emailCtrl,
      icon: Icons.mail_outline_rounded,
      keyboardType: TextInputType.emailAddress,
      onChanged: (_) => setState(() => _error = null),
    ),
    const SizedBox(height: 16),
    _buildField(
      label: 'Mot de passe',
      controller: _passCtrl,
      icon: Icons.lock_outline_rounded,
      obscure: _obscurePass,
      onChanged: (_) => setState(() => _error = null),
      trailing: IconButton(
        onPressed: () => setState(() => _obscurePass = !_obscurePass),
        icon: Icon(
          _obscurePass ? Icons.visibility_off_rounded : Icons.visibility_rounded,
          color: AppColors.textFaint,
          size: 20,
        ),
      ),
    ),
    const SizedBox(height: 16),
    _buildField(
      label: 'Confirmer le mot de passe',
      controller: _confirmPassCtrl,
      icon: Icons.lock_outline_rounded,
      obscure: _obscureConfirmPass,
      onChanged: (_) => setState(() => _error = null),
      trailing: IconButton(
        onPressed: () =>
            setState(() => _obscureConfirmPass = !_obscureConfirmPass),
        icon: Icon(
          _obscureConfirmPass
              ? Icons.visibility_off_rounded
              : Icons.visibility_rounded,
          color: AppColors.textFaint,
          size: 20,
        ),
      ),
    ),
  ];

  List<Widget> _buildStep1() => [
    _buildField(
      label: 'Nom du commerce',
      controller: _nomCommerceCtrl,
      icon: Icons.storefront_rounded,
      hint: 'Ex. Épicerie El Baraka',
      onChanged: (_) => setState(() => _error = null),
    ),
    const SizedBox(height: 16),
    const Text(
      'Type d\'activité',
      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
    ),
    const SizedBox(height: 8),
    Wrap(
      spacing: 8,
      runSpacing: 8,
      children: TypeActivite.values.map((t) {
        return ChoiceChip(
          label: Text(t.label),
          selected: _typeActivite == t,
          onSelected: (_) => setState(() => _typeActivite = t),
        );
      }).toList(),
    ),
    const SizedBox(height: 16),
    _buildField(
      label: 'Téléphone (optionnel)',
      controller: _telCommerceCtrl,
      icon: Icons.call_outlined,
      keyboardType: TextInputType.phone,
    ),
    const SizedBox(height: 16),
    _buildField(
      label: 'Ville (optionnel)',
      controller: _villeCtrl,
      icon: Icons.location_city_outlined,
    ),
  ];

  List<Widget> _buildStep2() => [
    _buildField(
      label: 'Code PIN administrateur (4 à 6 chiffres)',
      controller: _pinCtrl,
      icon: Icons.pin_outlined,
      obscure: _obscurePin,
      keyboardType: TextInputType.number,
      maxLength: 6,
      onChanged: (_) => setState(() => _error = null),
      trailing: IconButton(
        onPressed: () => setState(() => _obscurePin = !_obscurePin),
        icon: Icon(
          _obscurePin ? Icons.visibility_off_rounded : Icons.visibility_rounded,
          color: AppColors.textFaint,
          size: 20,
        ),
      ),
    ),
    const SizedBox(height: 16),
    _buildField(
      label: 'Confirmer le code PIN',
      controller: _confirmPinCtrl,
      icon: Icons.pin_outlined,
      obscure: _obscureConfirmPin,
      keyboardType: TextInputType.number,
      maxLength: 6,
      onChanged: (_) => setState(() => _error = null),
      trailing: IconButton(
        onPressed: () =>
            setState(() => _obscureConfirmPin = !_obscureConfirmPin),
        icon: Icon(
          _obscureConfirmPin
              ? Icons.visibility_off_rounded
              : Icons.visibility_rounded,
          color: AppColors.textFaint,
          size: 20,
        ),
      ),
    ),
    const SizedBox(height: 16),
    InkWell(
      onTap: () => setState(() {
        _acceptedTerms = !_acceptedTerms;
        _error = null;
      }),
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: _acceptedTerms,
              onChanged: (v) => setState(() {
                _acceptedTerms = v ?? false;
                _error = null;
              }),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'J\'accepte les Conditions d\'utilisation et la Politique de confidentialité.',
                  style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  ];

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    bool obscure = false,
    Widget? trailing,
    TextInputType? keyboardType,
    int? maxLength,
    String? hint,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      maxLength: maxLength,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20, color: AppColors.textFaint),
        suffixIcon: trailing,
        counterText: '',
      ),
    );
  }
}
