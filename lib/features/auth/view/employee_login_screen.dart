import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sou9ix/features/auth/model/user.dart';
import 'package:sou9ix/features/auth/viewmodel/auth_provider.dart';
import 'package:sou9ix/features/employees/viewmodel/employees_provider.dart';
import 'package:sou9ix/core/theme/app_colors.dart';
import 'package:sou9ix/core/theme/app_theme.dart';

/// The app's real entry point (after the splash screen) — a genuine
/// login, not a "who's using this device" picker: nothing on this screen
/// reveals the roster (no names, no roles), the employee types their own
/// full name + PIN, and the role/permissions that follow are always the
/// ones already on their employee record. Admins use a separate e-mail +
/// password screen ([AdminLoginScreen]) reached from the link below.
class EmployeeLoginScreen extends ConsumerStatefulWidget {
  const EmployeeLoginScreen({super.key});

  @override
  ConsumerState<EmployeeLoginScreen> createState() =>
      _EmployeeLoginScreenState();
}

class _EmployeeLoginScreenState extends ConsumerState<EmployeeLoginScreen> {
  final _nomCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  bool _obscurePin = true;
  bool _loading = false;
  String? _error;

  bool get _formFilled =>
      _nomCtrl.text.trim().isNotEmpty && _pinCtrl.text.trim().length >= 4;

  @override
  void dispose() {
    _nomCtrl.dispose();
    _pinCtrl.dispose();
    super.dispose();
  }

  /// No real backend exists — [Employee.pin] is a deterministic mock
  /// credential, not a hashed/salted account system. Errors stay generic
  /// ("nom ou PIN incorrect") so this screen never confirms whether a
  /// given name even exists. Matching by full name relies on names being
  /// unique among active employees (enforced when creating one).
  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_formFilled) {
      setState(() => _error = 'Entrez votre nom complet et votre code PIN.');
      return;
    }
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    final typedNom = _nomCtrl.text.trim();
    final pin = _pinCtrl.text.trim();
    final employees = ref.read(activeEmployeesProvider);
    final matches = employees.where(
      (e) => e.matchesFullName(typedNom) && e.pin == pin,
    );

    if (matches.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Nom complet ou code PIN incorrect.';
      });
      return;
    }
    ref.read(authProvider.notifier).loginAsEmployee(matches.first);
    if (mounted) context.go('/app');
  }

  // TEMPORAIRE — raccourci de test pour l'installation/démo, à retirer
  // avant la mise en production. Se connecte directement avec le premier
  // employé du rôle demandé, sans passer par nom/PIN.
  void _quickLogin(UserRole role) {
    final matches = ref.read(activeEmployeesProvider).where((e) => e.role == role);
    if (matches.isEmpty) {
      setState(() => _error = 'Aucun employé "${role.name}" trouvé.');
      return;
    }
    ref.read(authProvider.notifier).loginAsEmployee(matches.first);
    context.go('/app');
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
                        'Connectez-vous à votre espace.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ).animate().fadeIn(delay: 180.ms),
                      const SizedBox(height: 32),
                      _buildField(
                        label: 'Nom complet',
                        controller: _nomCtrl,
                        icon: Icons.person_outline_rounded,
                        hint: 'Ex. Rania Mejri',
                        onChanged: (_) => setState(() => _error = null),
                      ).animate().fadeIn(delay: 220.ms).slideY(begin: 0.15, end: 0),
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
                          onPressed: () =>
                              setState(() => _obscurePin = !_obscurePin),
                          icon: Icon(
                            _obscurePin
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
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
