import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sou9ix/features/auth/viewmodel/auth_provider.dart';
import 'package:sou9ix/core/theme/app_colors.dart';
import 'package:sou9ix/core/theme/app_theme.dart';
import 'package:sou9ix/core/widgets/press_scale.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailCtrl = TextEditingController(text: 'yassine@sou9ix.tn');
  final _passCtrl = TextEditingController(text: '••••••••');
  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login(void Function() applyRole) async {
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    applyRole();
    context.go('/app');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
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
                      boxShadow: AppShadows.colored(AppColors.teal),
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
                'Hello 👋',
                style: Theme.of(context).textTheme.displaySmall,
              ).animate().fadeIn(delay: 100.ms).slideX(begin: -0.05, end: 0),
              const SizedBox(height: 6),
              Text(
                'Connectez-vous pour gérer votre caisse Sou9ix.',
                style: Theme.of(context).textTheme.bodyMedium,
              ).animate().fadeIn(delay: 180.ms),
              const SizedBox(height: 32),
              _buildField(
                label: 'Adresse email',
                controller: _emailCtrl,
                icon: Icons.mail_outline_rounded,
              ).animate().fadeIn(delay: 220.ms).slideY(begin: 0.15, end: 0),
              const SizedBox(height: 16),
              _buildField(
                label: 'Mot de passe',
                controller: _passCtrl,
                icon: Icons.lock_outline_rounded,
                obscure: _obscure,
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
              ).animate().fadeIn(delay: 280.ms).slideY(begin: 0.15, end: 0),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {},
                  child: const Text('Mot de passe oublié ?'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading
                      ? null
                      : () => _login(
                          ref.read(authProvider.notifier).loginAsAdmin,
                        ),
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
                      'accès rapide démo',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _RoleQuickButton(
                      label: 'Administrateur',
                      icon: Icons.admin_panel_settings_rounded,
                      color: AppColors.teal,
                      onTap: _loading
                          ? null
                          : () => _login(
                              ref.read(authProvider.notifier).loginAsAdmin,
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _RoleQuickButton(
                      label: 'Caissier',
                      icon: Icons.point_of_sale_rounded,
                      color: AppColors.goldDark,
                      onTap: _loading
                          ? null
                          : () => _login(
                              ref.read(authProvider.notifier).loginAsCaissier,
                            ),
                    ),
                  ),
                ],
              ).animate().fadeIn(delay: 420.ms),
            ],
          ),
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
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20, color: AppColors.textFaint),
        suffixIcon: trailing,
      ),
    );
  }
}

class _RoleQuickButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _RoleQuickButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
