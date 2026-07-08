import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sou9ix/features/auth/model/user.dart';
import 'package:sou9ix/features/auth/viewmodel/auth_provider.dart';
import 'package:sou9ix/core/theme/app_colors.dart';
import 'package:sou9ix/core/theme/app_theme.dart';
import 'package:sou9ix/core/widgets/press_scale.dart';
import 'package:sou9ix/core/widgets/sheet_handle.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _notifications = true;
  bool _arabicRtl = false;
  bool _offlineMode = true;
  bool _biometric = false;
  String? _cashierPin;

  void _comingSoon(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Bientôt disponible'),
        ),
      );
  }

  void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(behavior: SnackBarBehavior.floating, content: Text(message)),
      );
  }

  Future<void> _openChangePasswordSheet(BuildContext context) async {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final saved = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppRadius.xl),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SheetHandle(),
                  const SizedBox(height: 14),
                  Text(
                    'Changer le mot de passe',
                    style: Theme.of(sheetContext).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: currentCtrl,
                    obscureText: true,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Mot de passe actuel',
                    ),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Requis' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: newCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      hintText: 'Nouveau mot de passe',
                    ),
                    validator: (v) => (v == null || v.length < 4)
                        ? 'Au moins 4 caractères'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: confirmCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      hintText: 'Confirmer le nouveau mot de passe',
                    ),
                    validator: (v) => v != newCtrl.text
                        ? 'Les mots de passe ne correspondent pas'
                        : null,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        if (formKey.currentState!.validate()) {
                          Navigator.pop(sheetContext, true);
                        }
                      },
                      child: const Text('Enregistrer'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (saved == true && context.mounted) {
      _toast(context, 'Mot de passe modifié avec succès');
    }
  }

  Future<void> _openPinSheet(BuildContext context) async {
    final pinCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final saved = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppRadius.xl),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SheetHandle(),
                  const SizedBox(height: 14),
                  Text(
                    _cashierPin == null
                        ? 'Définir un PIN caisse'
                        : 'Modifier le PIN caisse',
                    style: Theme.of(sheetContext).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Utilisé pour ouvrir la caisse rapidement.',
                    style: Theme.of(sheetContext).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: pinCtrl,
                    autofocus: true,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 6,
                    ),
                    decoration: const InputDecoration(
                      counterText: '',
                      hintText: '••••',
                    ),
                    validator: (v) => (v == null || v.length < 4)
                        ? 'Le PIN doit contenir au moins 4 chiffres'
                        : null,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        if (formKey.currentState!.validate()) {
                          Navigator.pop(sheetContext, true);
                        }
                      },
                      child: const Text('Enregistrer'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (saved == true) {
      setState(() => _cashierPin = pinCtrl.text);
      if (context.mounted) _toast(context, 'PIN caisse mis à jour');
    }
  }

  Future<void> _openContactSheet(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SheetHandle(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Nous contacter',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.chat_rounded, color: AppColors.success),
              title: const Text('WhatsApp'),
              subtitle: const Text('+216 20 000 000'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.email_outlined, color: AppColors.info),
              title: const Text('Email'),
              subtitle: const Text('support@sou9ix.tn'),
              onTap: () => Navigator.pop(context),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Se déconnecter ?'),
        content: const Text('Êtes-vous sûr de vouloir vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Déconnexion',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      ref.read(authProvider.notifier).logout();
      context.go('/login');
    }
  }

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
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.nom ?? '',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user?.email ?? '',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 12.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          isAdmin ? 'Administrateur' : 'Caissier',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
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
              onTap: () => _comingSoon(context),
            ),
            const SizedBox(height: 24),
            Text('Magasin', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            _InfoCard(
              rows: [
                _InfoRow(
                  icon: Icons.store_outlined,
                  label: 'Nom',
                  value: user?.magasin ?? 'Sou9ix',
                ),
                _InfoRow(
                  icon: Icons.location_on_outlined,
                  label: 'Adresse',
                  value: 'La Marsa, Tunis',
                ),
                _InfoRow(
                  icon: Icons.call_outlined,
                  label: 'Téléphone',
                  value: '+216 71 123 456',
                ),
                _InfoRow(
                  icon: Icons.badge_outlined,
                  label: 'Matricule fiscal',
                  value: '1234567A/A/M/000',
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Gestion de l\'entreprise',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            _MenuTile(
              icon: Icons.payments_outlined,
              label: 'Devise',
              trailing: 'DT',
              onTap: () => _comingSoon(context),
            ),
            _MenuTile(
              icon: Icons.translate_rounded,
              label: 'Langue',
              trailing: 'Français',
              onTap: () => _comingSoon(context),
            ),
            _MenuTile(
              icon: Icons.receipt_outlined,
              label: 'Nom du ticket',
              onTap: () => _comingSoon(context),
            ),
            _MenuTile(
              icon: Icons.image_outlined,
              label: 'Logo',
              onTap: () => _comingSoon(context),
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
          Text('Sécurité', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          _MenuTile(
            icon: Icons.lock_outline_rounded,
            label: 'Changer le mot de passe',
            onTap: () => _openChangePasswordSheet(context),
          ),
          _MenuTile(
            icon: Icons.pin_outlined,
            label: 'PIN caisse',
            trailing: _cashierPin != null ? 'Défini' : null,
            onTap: () => _openPinSheet(context),
          ),
          _SwitchTile(
            icon: Icons.fingerprint_rounded,
            label: 'Authentification biométrique',
            subtitle: 'Déverrouiller l\'application avec empreinte / Face ID',
            value: _biometric,
            onChanged: (v) => setState(() => _biometric = v),
          ),
          const SizedBox(height: 24),
          Text('Assistance', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          _MenuTile(
            icon: Icons.help_outline_rounded,
            label: 'Centre d\'aide',
            onTap: () => _comingSoon(context),
          ),
          _MenuTile(
            icon: Icons.info_outline_rounded,
            label: 'À propos de Sou9ix',
            onTap: () => _comingSoon(context),
          ),
          _MenuTile(
            icon: Icons.chat_bubble_outline_rounded,
            label: 'Nous contacter',
            onTap: () => _openContactSheet(context),
          ),
          _MenuTile(
            icon: Icons.bug_report_outlined,
            label: 'Signaler un problème',
            onTap: () => _comingSoon(context),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _confirmLogout(context),
              icon: const Icon(
                Icons.logout_rounded,
                color: AppColors.danger,
                size: 19,
              ),
              label: const Text(
                'Se déconnecter',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: const BorderSide(color: AppColors.danger),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          Center(
            child: Column(
              children: [
                Text(
                  'Sou9ix POS',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'Version 1.0.0',
                  style: TextStyle(fontSize: 12, color: AppColors.textFaint),
                ),
                const SizedBox(height: 3),
                const Text(
                  '© 2026 Sou9ix',
                  style: TextStyle(fontSize: 11, color: AppColors.textFaint),
                ),
              ],
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
  final String? trailing;
  final VoidCallback onTap;

  const _MenuTile({
    required this.icon,
    required this.label,
    this.trailing,
    required this.onTap,
  });

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
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
              if (trailing != null) ...[
                Text(
                  trailing!,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: AppColors.textFaint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Read-only rows of key/value store info (name, address, phone, tax ID) —
/// grouped in one card since none of it is independently actionable here.
class _InfoCard extends StatelessWidget {
  final List<_InfoRow> rows;
  const _InfoCard({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Icon(rows[i].icon, size: 18, color: AppColors.textSecondary),
                  const SizedBox(width: 12),
                  Text(
                    rows[i].label,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const Spacer(),
                  Flexible(
                    child: Text(
                      rows[i].value,
                      textAlign: TextAlign.right,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: 2),
                  Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: (value ? AppColors.success : AppColors.textFaint)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      value ? 'Activé' : 'Désactivé',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: value ? AppColors.success : AppColors.textFaint,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Switch(
              value: value,
              activeThumbColor: AppColors.teal,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}
