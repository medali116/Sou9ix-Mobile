import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sou9ix/features/auth/model/user.dart';
import 'package:sou9ix/features/auth/viewmodel/auth_provider.dart';
import 'package:sou9ix/core/theme/app_colors.dart';
import 'package:sou9ix/core/theme/app_theme.dart';
import 'package:sou9ix/core/widgets/press_scale.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _notifications = true;
  bool _arabicRtl = false;
  bool _offlineMode = true;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    final isAdmin = user?.role == UserRole.admin;

    return Scaffold(
      appBar: AppBar(title: const Text('Mon compte')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 110),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppColors.tealGradient,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              boxShadow: AppShadows.colored(AppColors.teal),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  child: Text(
                    user?.initiales ?? '',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user?.nom ?? '',
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
                      const SizedBox(height: 2),
                      Text(user?.email ?? '',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12.5)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          isAdmin ? 'Administrateur' : 'Caissier',
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 320.ms).slideY(begin: 0.05, end: 0),
          const SizedBox(height: 26),
          if (isAdmin) ...[
            Text('Gestion', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            _MenuTile(
              icon: Icons.inventory_2_outlined,
              label: 'Catalogue produits',
              onTap: () => context.push('/products'),
            ),
            _MenuTile(
              icon: Icons.people_outline_rounded,
              label: 'Clients & crédit (karné)',
              onTap: () => context.push('/clients'),
            ),
            _MenuTile(
              icon: Icons.receipt_long_outlined,
              label: 'Historique des ventes',
              onTap: () => context.push('/history'),
            ),
            _MenuTile(
              icon: Icons.local_shipping_outlined,
              label: 'Achats fournisseurs',
              onTap: () => context.push('/purchases'),
            ),
            _MenuTile(
              icon: Icons.badge_outlined,
              label: 'Employés',
              onTap: () => context.push('/employees'),
            ),
            _MenuTile(
              icon: Icons.remove_shopping_cart_outlined,
              label: 'Retours & pertes',
              onTap: () => context.push('/returns'),
            ),
            _MenuTile(
              icon: Icons.notifications_active_outlined,
              label: 'Alertes',
              onTap: () => context.push('/alerts'),
            ),
            _MenuTile(
              icon: Icons.wallet_outlined,
              label: 'Dépenses & charges',
              onTap: () {},
            ),
            const SizedBox(height: 24),
          ],
          Text('Préférences', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          _SwitchTile(
            icon: Icons.notifications_none_rounded,
            label: 'Notifications',
            subtitle: 'Alertes de stock faible et rappels',
            value: _notifications,
            onChanged: (v) => setState(() => _notifications = v),
          ),
          _SwitchTile(
            icon: Icons.language_rounded,
            label: 'Interface arabe (RTL)',
            subtitle: 'Basculer vers l\'arabe et le clavier RTL',
            value: _arabicRtl,
            onChanged: (v) => setState(() => _arabicRtl = v),
          ),
          _SwitchTile(
            icon: Icons.cloud_off_rounded,
            label: 'Mode hors-ligne',
            subtitle: 'Continuer les ventes sans connexion',
            value: _offlineMode,
            onChanged: (v) => setState(() => _offlineMode = v),
          ),
          const SizedBox(height: 24),
          Text('Assistance', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          _MenuTile(icon: Icons.help_outline_rounded, label: 'Centre d\'aide', onTap: () {}),
          _MenuTile(icon: Icons.info_outline_rounded, label: 'À propos de Sou9ix', onTap: () {}),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                ref.read(authProvider.notifier).logout();
                context.go('/login');
              },
              icon: const Icon(Icons.logout_rounded, color: AppColors.danger),
              label: const Text('Se déconnecter', style: TextStyle(color: AppColors.danger)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: const BorderSide(color: AppColors.danger),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MenuTile({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: PressScale(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            boxShadow: AppShadows.card,
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
                child: Icon(icon, size: 19, color: AppColors.textPrimary),
              ),
              const SizedBox(width: 14),
              Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyLarge)),
              const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textFaint),
            ],
          ),
        ),
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: AppShadows.card,
        ),
        child: SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(AppRadius.xs),
            ),
            child: Icon(icon, size: 19, color: AppColors.textPrimary),
          ),
          title: Text(label, style: Theme.of(context).textTheme.bodyLarge),
          subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
          value: value,
          activeThumbColor: AppColors.teal,
          onChanged: onChanged,
        ),
      ),
    );
  }
}
