import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sou9ix/features/auth/model/user.dart';
import 'package:sou9ix/features/auth/viewmodel/auth_provider.dart';
import 'package:sou9ix/features/employees/viewmodel/employees_provider.dart';
import 'package:sou9ix/core/theme/app_colors.dart';
import 'package:sou9ix/core/theme/app_theme.dart';

final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// Reached only via "Vous êtes administrateur ?" on [EmployeeLoginScreen]
/// — kept as a separate screen, not a toggle on the same form, so the
/// default entry point never even hints that an e-mail/password path
/// exists. No real backend exists here either — an admin created via the
/// onboarding wizard has a real (plain, in-memory) [Employee.password]
/// that's actually checked; a legacy/seed admin with none set (e.g.
/// Yassine) keeps the old any-non-empty-password mock behavior.
///
/// "Créer mon espace" is always visible here, unlike an employee record
/// (added only by an admin, from the Employés screen) — creating a new
/// admin/commerce space isn't gated the way a random person self-promoting
/// to an *existing* shop's admin would be.
class AdminLoginScreen extends ConsumerStatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  ConsumerState<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends ConsumerState<AdminLoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  bool get _formFilled =>
      _emailCtrl.text.trim().isNotEmpty && _passCtrl.text.trim().isNotEmpty;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !_emailPattern.hasMatch(email)) {
      setState(() => _error = 'Adresse e-mail invalide.');
      return;
    }
    if (_passCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Le mot de passe est requis.');
      return;
    }
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    final normalized = email.toLowerCase();
    final admins = ref
        .read(activeEmployeesProvider)
        .where((e) => e.role == UserRole.admin);
    final matches = admins.where((e) => e.loginEmail.toLowerCase() == normalized);
    final match = matches.isEmpty ? null : matches.first;
    final passwordOk =
        match != null &&
        (match.password == null || match.password == _passCtrl.text);

    if (!passwordOk) {
      setState(() {
        _loading = false;
        _error = 'Adresse e-mail ou mot de passe incorrect.';
      });
      return;
    }
    ref.read(authProvider.notifier).loginAsEmployee(match);
    if (mounted) context.go('/app');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Connexion administrateur')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          children: [
            Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: AppColors.tealGradient,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: const Icon(
                    Icons.admin_panel_settings_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                )
                .animate()
                .fadeIn(duration: 400.ms)
                .scale(begin: const Offset(0.7, 0.7)),
            const SizedBox(height: 20),
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
              obscure: _obscure,
              onChanged: (_) => setState(() => _error = null),
              trailing: IconButton(
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(
                  _obscure
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: AppColors.textFaint,
                  size: 20,
                ),
              ),
            ),
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
            ),
            const SizedBox(height: 10),
            Center(
              child: TextButton(
                onPressed: () {},
                child: const Text('Mot de passe oublié ?'),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: TextButton(
                onPressed: () => context.pop(),
                child: const Text('← Connexion employé'),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'Nouveau sur Sou9ix ?',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                const Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => context.push('/login/admin/create'),
                child: const Text('Créer mon espace →'),
              ),
            ),
          ],
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
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20, color: AppColors.textFaint),
        suffixIcon: trailing,
      ),
    );
  }
}
