import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sou9ix/features/auth/model/user.dart';
import 'package:sou9ix/features/auth/service/shop_code_storage.dart';
import 'package:sou9ix/features/auth/viewmodel/auth_provider.dart';
import 'package:sou9ix/features/employees/model/employee.dart';
import 'package:sou9ix/features/employees/service/employee_directory.dart';
import 'package:sou9ix/features/employees/service/employees_repository.dart';
import 'package:sou9ix/core/theme/app_colors.dart';
import 'package:sou9ix/core/theme/app_theme.dart';

/// The app's real entry point (after the splash screen) — a genuine login,
/// not a "who's using this device" picker. Two stages, both gated behind
/// [ShopCodeStorage]:
/// 1. **First time on this device**: a caissier types the shop code their
///    admin gave them (shown permanently on the admin's Profil) — this binds
///    the device to that shop so every roster lookup below stays scoped to
///    it, never searching across other shops.
/// 2. **Every time after**: nothing on screen reveals the roster (no names,
///    no roles) — the employee types their own full name + téléphone + PIN,
///    and the role/permissions that follow are always the ones already on
///    their employee record. Admins use a separate e-mail + password screen
///    ([AdminLoginScreen]) reached from the link below — that one never
///    needs a shop code, since e-mail alone finds it across every shop.
class EmployeeLoginScreen extends ConsumerStatefulWidget {
  const EmployeeLoginScreen({super.key});

  @override
  ConsumerState<EmployeeLoginScreen> createState() =>
      _EmployeeLoginScreenState();
}

class _EmployeeLoginScreenState extends ConsumerState<EmployeeLoginScreen> {
  bool _checkingBinding = true;
  String? _boundShopCode;
  final _shopCodeCtrl = TextEditingController();

  final _nomCtrl = TextEditingController();
  final _telCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  bool _obscurePin = true;
  bool _loading = false;
  String? _error;

  bool get _formFilled =>
      _nomCtrl.text.trim().isNotEmpty &&
      _telCtrl.text.trim().isNotEmpty &&
      _pinCtrl.text.trim().length >= 4;

  @override
  void initState() {
    super.initState();
    _loadBinding();
  }

  Future<void> _loadBinding() async {
    final code = await ShopCodeStorage().read();
    if (!mounted) return;
    setState(() {
      _boundShopCode = code;
      _checkingBinding = false;
    });
  }

  @override
  void dispose() {
    _shopCodeCtrl.dispose();
    _nomCtrl.dispose();
    _telCtrl.dispose();
    _pinCtrl.dispose();
    super.dispose();
  }

  /// Validates the typed code against a real `shops/{code}` document, then
  /// binds this device to it — every login afterwards on this device stays
  /// scoped to that one shop.
  Future<void> _submitShopCode() async {
    final code = _shopCodeCtrl.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() => _error = 'Entrez le code de votre magasin.');
      return;
    }
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      final doc = await FirebaseFirestore.instance
          .collection('shops')
          .doc(code)
          .get();
      if (!doc.exists) {
        setState(() {
          _loading = false;
          _error = 'Code de magasin introuvable — vérifiez et réessayez.';
        });
        return;
      }
      await ShopCodeStorage().save(code);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _boundShopCode = code;
      });
    } catch (e) {
      debugPrint('EmployeeLoginScreen shop code check failed: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Connexion au serveur impossible — vérifiez votre connexion et réessayez.';
      });
    }
  }

  Future<void> _changeShop() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Changer de magasin ?'),
        content: const Text(
          'Cet appareil oubliera le code de magasin actuel — vous devrez en saisir un nouveau pour vous reconnecter.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Changer', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ShopCodeStorage().clear();
    if (!mounted) return;
    setState(() {
      _boundShopCode = null;
      _shopCodeCtrl.clear();
      _error = null;
    });
  }

  /// No real backend exists — [Employee.pin] is a deterministic mock
  /// credential, not a hashed/salted account system. Errors stay generic
  /// ("nom, téléphone ou PIN incorrect") so this screen never confirms
  /// whether a given name even exists. All three of nom + téléphone + PIN
  /// must match the same employee — the phone number is what lets two
  /// employees share a full name (see `create_admin_screen.dart`). Looked up
  /// directly within the device's bound shop (see [ShopCodeStorage]), not
  /// across every shop.
  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_formFilled) {
      setState(
        () => _error = 'Entrez votre nom complet, votre téléphone et votre code PIN.',
      );
      return;
    }
    setState(() => _loading = true);

    final typedNom = _nomCtrl.text.trim();
    final typedPhone = normalizePhone(_telCtrl.text.trim());
    final pin = _pinCtrl.text.trim();
    List<Employee> employees;
    try {
      employees = await EmployeesRepository(shopCode: _boundShopCode!).fetchOnce();
    } catch (e) {
      debugPrint('EmployeeLoginScreen lookup failed: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Connexion au serveur impossible — vérifiez votre connexion et réessayez.';
      });
      return;
    }
    if (!mounted) return;
    final matches = employees.where(
      (e) =>
          e.actif &&
          e.matchesFullName(typedNom) &&
          e.pin == pin &&
          normalizePhone(e.telephone) == typedPhone,
    );

    if (matches.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Nom complet, téléphone ou code PIN incorrect.';
      });
      return;
    }
    await ref.read(authProvider.notifier).loginAsEmployee(matches.first);
    if (mounted) context.go('/app');
  }

  // TEMPORAIRE — raccourci de test pour l'installation/démo, à retirer
  // avant la mise en production. Se connecte directement avec le premier
  // employé du rôle demandé, sans passer par nom/PIN.
  Future<void> _quickLogin(UserRole role) async {
    List<Employee> employees;
    try {
      if (role == UserRole.admin) {
        employees = await EmployeeDirectory().findAll();
      } else {
        employees = await EmployeesRepository(shopCode: _boundShopCode!).fetchOnce();
      }
    } catch (e) {
      debugPrint('EmployeeLoginScreen quick login failed: $e');
      if (!mounted) return;
      setState(() => _error = 'Connexion au serveur impossible — vérifiez votre connexion et réessayez.');
      return;
    }
    if (!mounted) return;
    final matches = employees.where((e) => e.actif && e.role == role);
    if (matches.isEmpty) {
      setState(() => _error = 'Aucun employé "${role.name}" trouvé.');
      return;
    }
    await ref.read(authProvider.notifier).loginAsEmployee(matches.first);
    if (mounted) context.go('/app');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              gradient: AppColors.tealGradient,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.teal.withValues(alpha: 0.18),
                                  blurRadius: 14,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.storefront_rounded,
                              color: Colors.white,
                              size: 30,
                            ),
                          )
                          .animate()
                          .fadeIn(duration: 400.ms)
                          .scale(begin: const Offset(0.7, 0.7)),
                      const SizedBox(height: 24),
                      Text(
                        'Bienvenue 👋',
                        style: Theme.of(context).textTheme.displaySmall,
                      ).animate().fadeIn(delay: 100.ms).slideX(begin: -0.05, end: 0),
                      const SizedBox(height: 6),
                      Text(
                        _checkingBinding
                            ? ' '
                            : (_boundShopCode == null
                                  ? 'Entrez le code de votre magasin pour continuer.'
                                  : 'Connectez-vous à votre espace.'),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ).animate().fadeIn(delay: 180.ms),
                      const SizedBox(height: 32),
                      if (_checkingBinding)
                        const Center(child: CircularProgressIndicator())
                      else if (_boundShopCode == null)
                        ..._buildShopCodeGate()
                      else
                        ..._buildLoginForm(),
                      const Spacer(),
                      const SizedBox(height: 24),
                      Center(
                        child: Column(
                          children: [
                            Text(
                              'Sou9ix',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Gérez votre commerce simplement',
                              style: TextStyle(
                                color: AppColors.textFaint,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildShopCodeGate() => [
    _buildField(
      label: 'Code du magasin',
      controller: _shopCodeCtrl,
      icon: Icons.qr_code_rounded,
      hint: 'Ex. AB123456',
      onChanged: (_) => setState(() => _error = null),
    ).animate().fadeIn(delay: 220.ms).slideY(begin: 0.15, end: 0),
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
    SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _loading ? null : _submitShopCode,
        child: _loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Colors.white,
                ),
              )
            : const Text('Continuer'),
      ),
    ).animate().fadeIn(delay: 280.ms).slideY(begin: 0.15, end: 0),
    const SizedBox(height: 28),
    Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'Vous êtes administrateur ?',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        const Expanded(child: Divider()),
      ],
    ),
    const SizedBox(height: 14),
    Center(
      child: TextButton(
        onPressed: () => context.push('/login/admin'),
        child: const Text('Connexion administrateur →'),
      ),
    ),
  ];

  List<Widget> _buildLoginForm() => [
    _buildField(
      label: 'Nom complet',
      controller: _nomCtrl,
      icon: Icons.person_outline_rounded,
      hint: 'Ex. Rania Mejri',
      onChanged: (_) => setState(() => _error = null),
    ).animate().fadeIn(delay: 220.ms).slideY(begin: 0.15, end: 0),
    const SizedBox(height: 16),
    _buildField(
      label: 'Téléphone',
      controller: _telCtrl,
      icon: Icons.call_outlined,
      keyboardType: TextInputType.phone,
      hint: '+216 XX XXX XXX',
      onChanged: (_) => setState(() => _error = null),
    ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.15, end: 0),
    const SizedBox(height: 16),
    _buildField(
      label: 'Code PIN',
      controller: _pinCtrl,
      icon: Icons.lock_outline_rounded,
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
    ).animate().fadeIn(delay: 280.ms).slideY(begin: 0.15, end: 0),
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
    SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: (_loading || !_formFilled) ? null : _submit,
        child: _loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Colors.white,
                ),
              )
            : const Text('Se connecter'),
      ),
    ).animate().fadeIn(delay: 340.ms).slideY(begin: 0.15, end: 0),
    const SizedBox(height: 14),
    Center(
      child: TextButton(
        onPressed: _loading ? null : _changeShop,
        child: Text(
          'Magasin ${_boundShopCode ?? ''} — changer',
          style: const TextStyle(color: AppColors.textFaint),
        ),
      ),
    ),
    const SizedBox(height: 14),
    Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'Vous êtes administrateur ?',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        const Expanded(child: Divider()),
      ],
    ),
    const SizedBox(height: 14),
    Center(
      child: TextButton(
        onPressed: () => context.push('/login/admin'),
        child: const Text('Connexion administrateur →'),
      ),
    ),
    const SizedBox(height: 24),
    // TEMPORAIRE — à retirer avant la mise en production.
    Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.4),
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Accès rapide (test — temporaire)',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: AppColors.warning,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _quickLogin(UserRole.admin),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.warning),
                    foregroundColor: AppColors.warning,
                  ),
                  child: const Text('Admin'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _quickLogin(UserRole.caissier),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.warning),
                    foregroundColor: AppColors.warning,
                  ),
                  child: const Text('Caissière'),
                ),
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
