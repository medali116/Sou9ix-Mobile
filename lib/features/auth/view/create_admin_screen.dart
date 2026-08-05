import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sou9ix/features/auth/model/user.dart';
import 'package:sou9ix/features/auth/viewmodel/auth_provider.dart';
import 'package:sou9ix/features/employees/model/employee.dart';
import 'package:sou9ix/features/employees/model/employee_module.dart';
import 'package:sou9ix/features/employees/service/employee_directory.dart';
import 'package:sou9ix/features/employees/service/employees_repository.dart';
import 'package:sou9ix/features/settings/model/activity_type.dart';
import 'package:sou9ix/features/settings/model/company_settings.dart';
import 'package:sou9ix/features/settings/service/company_settings_repository.dart';
import 'package:sou9ix/features/settings/viewmodel/activity_types_provider.dart';
import 'package:sou9ix/core/theme/app_colors.dart';
import 'package:sou9ix/core/theme/app_theme.dart';

final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// Reached via "Créer mon espace" on [AdminLoginScreen] — always available
/// there, unlike an employee record (added only by an admin, from the
/// Employés screen). Every submission creates a brand-new, isolated shop:
/// a unique code (2 uppercase letters + 6 digits) roots a fresh
/// `shops/{code}/...` subtree holding this shop's [CompanySettings] and its
/// first (admin) [Employee] — no other shop's data is ever visible from it.
/// The generated code is shown once for the admin to confirm before they're
/// signed in; every login afterwards resolves the shop from credentials
/// alone (see [EmployeeDirectory]), the code is never typed again.
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
  final _telCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  bool _obscurePass = true;
  bool _obscureConfirmPass = true;

  // Étape 2 — Votre commerce
  final _nomCommerceCtrl = TextEditingController();
  String _typeActiviteId = TypeActivite.epicerie.name;
  final _telCommerceCtrl = TextEditingController();
  final _villeCtrl = TextEditingController();

  // Étape 3 — Sécurité
  final _pinCtrl = TextEditingController();
  final _confirmPinCtrl = TextEditingController();
  bool _obscurePin = true;
  bool _obscureConfirmPin = true;
  bool _acceptedTerms = false;

  // Étape 4 — Code de commerce
  String? _generatedShopCode;
  Employee? _pendingEmployee;

  @override
  void dispose() {
    _nomCtrl.dispose();
    _emailCtrl.dispose();
    _telCtrl.dispose();
    _passCtrl.dispose();
    _confirmPassCtrl.dispose();
    _nomCommerceCtrl.dispose();
    _telCommerceCtrl.dispose();
    _villeCtrl.dispose();
    _pinCtrl.dispose();
    _confirmPinCtrl.dispose();
    super.dispose();
  }

  // An admin may share a full name with an existing employee — logging in
  // as a caissier now also requires a matching phone number (see
  // EmployeeLoginScreen), so the name alone is no longer the sole
  // disambiguator and doesn't need to be unique. Email and phone, on the
  // other hand, each identify one specific account, so both are checked
  // for uniqueness against every existing employee, in every shop — this is
  // the one signup-time check that has to look across shop boundaries
  // (there's no shop to scope it to yet), hence [EmployeeDirectory].
  Future<String?> _validateStep0() async {
    final nom = _nomCtrl.text.trim();
    if (nom.isEmpty) return 'Entrez votre nom complet.';

    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !_emailPattern.hasMatch(email)) {
      return 'Adresse e-mail invalide.';
    }
    final telephone = _telCtrl.text.trim();
    final normalizedPhone = normalizePhone(telephone);
    if (normalizedPhone.length < 8) {
      return 'Numéro de téléphone invalide.';
    }

    final allEmployees = await EmployeeDirectory().findAll();
    final normalizedEmail = email.toLowerCase();
    if (allEmployees.any((e) => e.loginEmail.toLowerCase() == normalizedEmail)) {
      return 'Cette adresse e-mail est déjà utilisée par un compte existant.';
    }
    if (allEmployees.any(
      (e) => e.telephone.isNotEmpty && normalizePhone(e.telephone) == normalizedPhone,
    )) {
      return 'Ce numéro de téléphone est déjà utilisé par un compte existant.';
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
    if (_telCommerceCtrl.text.trim().isEmpty) {
      return 'Entrez le téléphone de votre commerce.';
    }
    return null;
  }

  Future<void> _createNewActivityType() async {
    final nameCtrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Nouveau type d\'activité'),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Ex. Pharmacie'),
          onSubmitted: (v) => Navigator.pop(dialogContext, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, nameCtrl.text),
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
    final trimmed = name?.trim();
    if (trimmed == null || trimmed.isEmpty) return;

    final type = ActivityType(
      id: 'act${DateTime.now().microsecondsSinceEpoch}',
      name: trimmed,
    );
    ref.read(activityTypesProvider.notifier).add(type);
    setState(() => _typeActiviteId = type.id);
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

  Future<void> _next() async {
    if (_step == 0) {
      setState(() => _loading = true);
      String? error;
      try {
        error = await _validateStep0();
      } catch (e) {
        debugPrint('CreateAdminScreen step 0 validation failed: $e');
        error = 'Connexion au serveur impossible — vérifiez votre connexion et réessayez.';
      }
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (error != null) {
          _error = error;
        } else {
          _error = null;
          _step++;
        }
      });
      return;
    }
    final error = _validateStep1();
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

  /// Random 2 uppercase letters + 6 digits, retried on the (vanishingly
  /// unlikely) chance of a collision with an existing shop.
  Future<String> _generateUniqueShopCode() async {
    final random = Random();
    for (var attempt = 0; attempt < 8; attempt++) {
      final letters = String.fromCharCodes(
        List.generate(2, (_) => 65 + random.nextInt(26)),
      );
      final digits = List.generate(6, (_) => random.nextInt(10)).join();
      final code = '$letters$digits';
      final doc = await FirebaseFirestore.instance
          .collection('shops')
          .doc(code)
          .get();
      if (!doc.exists) return code;
    }
    throw StateError('Impossible de générer un code de commerce unique — réessayez.');
  }

  /// Creates the new shop (writes its [CompanySettings] doc and its first
  /// admin [Employee] directly through fresh repositories, bypassing the
  /// ref-watched providers — those are still scoped to "no shop" until
  /// [_confirmAndEnter] signs in), then advances to the code-confirmation
  /// step instead of navigating away immediately.
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

    try {
      final shopCode = await _generateUniqueShopCode();
      final settings = CompanySettings(
        nom: _nomCommerceCtrl.text.trim(),
        typeActiviteId: _typeActiviteId,
        telephone: _telCommerceCtrl.text.trim(),
        ville: _villeCtrl.text.trim().isEmpty ? null : _villeCtrl.text.trim(),
      );
      final employee = Employee(
        id: 'e${DateTime.now().microsecondsSinceEpoch}',
        shopCode: shopCode,
        nom: _nomCtrl.text.trim(),
        telephone: _telCtrl.text.trim(),
        poste: 'Gérant',
        modules: EmployeeModule.values.toSet(),
        pin: _pinCtrl.text.trim(),
        role: UserRole.admin,
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );

      await CompanySettingsRepository(shopCode: shopCode).save(settings);
      await EmployeesRepository(shopCode: shopCode).upsert(employee);

      if (!mounted) return;
      setState(() {
        _loading = false;
        _generatedShopCode = shopCode;
        _pendingEmployee = employee;
        _step = 3;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Une erreur est survenue — réessayez.';
      });
    }
  }

  Future<void> _enterApp() async {
    setState(() => _loading = true);
    await ref.read(authProvider.notifier).loginAsEmployee(_pendingEmployee!);
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
              'Étape ${_step + 1}/4',
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
                2 => 'Sécurité',
                _ => 'Confirmation',
              },
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            if (_step == 0) ..._buildStep0(),
            if (_step == 1) ..._buildStep1(),
            if (_step == 2) ..._buildStep2(),
            if (_step == 3) ..._buildStep3(),
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
                if (_step > 0 && _step < 3) ...[
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
                    onPressed: _loading
                        ? null
                        : switch (_step) {
                            0 || 1 => _next,
                            2 => _submit,
                            _ => _enterApp,
                          },
                    child: _loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: Colors.white,
                            ),
                          )
                        : Text(switch (_step) {
                            0 || 1 => 'Suivant',
                            2 => 'Créer mon espace',
                            _ => 'Continuer',
                          }),
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
      label: 'Téléphone',
      controller: _telCtrl,
      icon: Icons.call_outlined,
      keyboardType: TextInputType.phone,
      hint: '+216 XX XXX XXX',
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
    Consumer(
      builder: (context, ref, _) {
        final customTypes = ref.watch(activityTypesProvider);
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...TypeActivite.values.map((t) {
              return ChoiceChip(
                label: Text(t.label),
                selected: _typeActiviteId == t.name,
                onSelected: (_) => setState(() => _typeActiviteId = t.name),
              );
            }),
            ...customTypes.map((t) {
              return ChoiceChip(
                label: Text(t.name),
                selected: _typeActiviteId == t.id,
                onSelected: (_) => setState(() => _typeActiviteId = t.id),
              );
            }),
            ActionChip(
              avatar: const Icon(
                Icons.add_rounded,
                size: 18,
                color: AppColors.teal,
              ),
              label: const Text(
                'Nouveau type',
                style: TextStyle(
                  color: AppColors.teal,
                  fontWeight: FontWeight.w700,
                ),
              ),
              onPressed: _createNewActivityType,
            ),
          ],
        );
      },
    ),
    const SizedBox(height: 16),
    _buildField(
      label: 'Téléphone',
      controller: _telCommerceCtrl,
      icon: Icons.call_outlined,
      keyboardType: TextInputType.phone,
      onChanged: (_) => setState(() => _error = null),
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

  List<Widget> _buildStep3() => [
    Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.teal.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.teal.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Votre code de magasin',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            'Donnez ce code à vos employés — ils le saisiront une seule fois, à leur première connexion, pour rejoindre votre magasin. Vous le retrouverez toujours dans Profil.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Text(
                _generatedShopCode ?? '',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: () {
                  Clipboard.setData(
                    ClipboardData(text: _generatedShopCode ?? ''),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Code copié')),
                  );
                },
                icon: const Icon(Icons.copy_rounded, color: AppColors.teal),
              ),
            ],
          ),
        ],
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
