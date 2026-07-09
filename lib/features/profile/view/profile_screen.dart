import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:local_auth/local_auth.dart';

import 'package:sou9ix/features/auth/model/user.dart';
import 'package:sou9ix/features/auth/viewmodel/auth_provider.dart';
import 'package:sou9ix/core/theme/app_colors.dart';
import 'package:sou9ix/core/theme/app_theme.dart';
import 'package:sou9ix/core/widgets/photo_picker_field.dart';
import 'package:sou9ix/core/widgets/press_scale.dart';
import 'package:sou9ix/core/widgets/section_header.dart';
import 'package:sou9ix/core/widgets/sheet_handle.dart';
import 'package:sou9ix/features/settings/model/company_settings.dart';
import 'package:sou9ix/features/settings/viewmodel/company_settings_provider.dart';

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
  final _localAuth = LocalAuthentication();
  String? _cashierPin;
  final List<_MockSession> _sessions = [
    const _MockSession(
      id: 's1',
      device: 'Cet appareil',
      detail: 'Windows · Actif maintenant',
      isCurrent: true,
    ),
    const _MockSession(
      id: 's2',
      device: 'iPhone de Rania',
      detail: 'iOS · il y a 2 jours',
      isCurrent: false,
    ),
  ];

  Future<void> _openDeviseSheet(BuildContext context) async {
    final current = ref.read(companySettingsProvider).currency;
    final result = await showModalBottomSheet<Currency>(
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
                  'Devise',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
            for (final c in Currency.values)
              ListTile(
                title: Text(
                  c.label,
                  style: TextStyle(
                    fontWeight: current == c
                        ? FontWeight.w800
                        : FontWeight.w500,
                  ),
                ),
                trailing: current == c
                    ? const Icon(Icons.check_rounded, color: AppColors.teal)
                    : null,
                onTap: () => Navigator.pop(context, c),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (result != null) {
      ref.read(companySettingsProvider.notifier).setCurrency(result);
      if (context.mounted) _toast(context, 'Devise : ${result.symbol}');
    }
  }

  Future<void> _openLangueSheet(BuildContext context) async {
    final current = ref.read(companySettingsProvider).language;
    final result = await showModalBottomSheet<AppLanguage>(
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
                  'Langue',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
            for (final l in AppLanguage.values)
              ListTile(
                title: Text(
                  l.label,
                  style: TextStyle(
                    fontWeight: current == l
                        ? FontWeight.w800
                        : FontWeight.w500,
                  ),
                ),
                trailing: current == l
                    ? const Icon(Icons.check_rounded, color: AppColors.teal)
                    : null,
                onTap: () => Navigator.pop(context, l),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (result != null) {
      ref.read(companySettingsProvider.notifier).setLanguage(result);
      if (context.mounted) {
        _toast(
          context,
          result == AppLanguage.francais
              ? 'Langue : ${result.label}'
              : '${result.label} sélectionné — la traduction complète arrive bientôt',
        );
      }
    }
  }

  Future<void> _openNomTicketSheet(BuildContext context) async {
    final ctrl = TextEditingController(
      text: ref.read(companySettingsProvider).ticketName,
    );
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
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SheetHandle(),
                const SizedBox(height: 8),
                Text(
                  'Nom du ticket',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  'Affiché en en-tête de chaque ticket imprimé',
                  style: Theme.of(sheetContext).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nom du ticket',
                    prefixIcon: Icon(Icons.receipt_outlined),
                    hintText: 'Sou9ix',
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(sheetContext, true),
                    child: const Text('Enregistrer'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (saved == true) {
      ref.read(companySettingsProvider.notifier).setTicketName(ctrl.text);
      if (context.mounted) _toast(context, 'Nom du ticket mis à jour');
    }
  }

  Future<void> _openLogoSheet(BuildContext context) async {
    var logoBytes = ref.read(companySettingsProvider).logoBytes;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
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
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SheetHandle(),
                  const SizedBox(height: 8),
                  Text(
                    'Logo',
                    style: Theme.of(sheetContext).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Affiché à la place du nom sur les tickets imprimés',
                    style: Theme.of(sheetContext).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  PhotoPickerField(
                    photoBytes: logoBytes,
                    onChanged: (bytes) =>
                        setSheetState(() => logoBytes = bytes),
                    placeholderLabel: 'Ajouter un logo',
                    placeholderIcon: Icons.image_outlined,
                    height: 120,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(sheetContext, true),
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
      ref.read(companySettingsProvider.notifier).setLogo(logoBytes);
      if (context.mounted) _toast(context, 'Logo mis à jour');
    }
  }

  Future<void> _openMagasinEditSheet(BuildContext context) async {
    final settings = ref.read(companySettingsProvider);
    final nomCtrl = TextEditingController(
      text: ref.read(authProvider)?.magasin ?? 'Sou9ix',
    );
    final adresseCtrl = TextEditingController(text: settings.adresse);
    final telCtrl = TextEditingController(text: settings.telephone);
    final matriculeCtrl = TextEditingController(text: settings.matriculeFiscal);
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
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetContext).size.height * 0.9,
          ),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppRadius.xl),
            ),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SheetHandle(),
                  const SizedBox(height: 14),
                  Text(
                    'Informations du magasin',
                    style: Theme.of(sheetContext).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: nomCtrl,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Nom du magasin',
                      prefixIcon: Icon(Icons.store_outlined),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Requis' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: adresseCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Adresse',
                      prefixIcon: Icon(Icons.location_on_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: telCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Téléphone',
                      prefixIcon: Icon(Icons.call_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: matriculeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Matricule fiscal',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        if (!formKey.currentState!.validate()) return;
                        Navigator.pop(sheetContext, true);
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
      ref
          .read(authProvider.notifier)
          .updateProfile(magasin: nomCtrl.text.trim());
      ref
          .read(companySettingsProvider.notifier)
          .updateStoreInfo(
            adresse: adresseCtrl.text.trim(),
            telephone: telCtrl.text.trim(),
            matriculeFiscal: matriculeCtrl.text.trim(),
          );
      if (context.mounted) {
        _toast(context, 'Informations du magasin mises à jour');
      }
    }
  }

  void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(behavior: SnackBarBehavior.floating, content: Text(message)),
      );
  }

  /// Turning the switch on immediately triggers the system Face ID /
  /// fingerprint prompt — the switch only actually flips to on if that
  /// check succeeds, matching how banking/payment apps gate this setting.
  /// Turning it back off doesn't need re-authentication.
  Future<void> _toggleBiometric(bool wantsOn, BuildContext context) async {
    if (!wantsOn) {
      setState(() => _biometric = false);
      return;
    }

    try {
      final supported = await _localAuth.isDeviceSupported();
      if (!supported) {
        if (context.mounted) {
          _toast(
            context,
            'Authentification biométrique non disponible sur cet appareil',
          );
        }
        return;
      }
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Confirmez votre identité pour activer cette option',
        persistAcrossBackgrounding: true,
      );
      setState(() => _biometric = authenticated);
      if (!authenticated && context.mounted) {
        _toast(context, 'Authentification annulée');
      }
    } on LocalAuthException {
      setState(() => _biometric = false);
      if (context.mounted) {
        _toast(context, 'Authentification biométrique indisponible');
      }
    } catch (_) {
      // local_auth has no web implementation at all (unlike mobile/Windows,
      // where a missing sensor is a normal LocalAuthException), so on web
      // this throws a MissingPluginException instead — catch that too so
      // toggling the switch there fails loudly instead of doing nothing.
      setState(() => _biometric = false);
      if (context.mounted) {
        _toast(
          context,
          'Authentification biométrique non disponible sur cette plateforme',
        );
      }
    }
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
                      labelText: 'Mot de passe actuel',
                      prefixIcon: Icon(Icons.lock_outline_rounded),
                    ),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Requis' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: newCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Nouveau mot de passe',
                      prefixIcon: Icon(Icons.lock_outline_rounded),
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
                      labelText: 'Confirmer le nouveau mot de passe',
                      prefixIcon: Icon(Icons.lock_outline_rounded),
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

  Future<ImageSource?> _pickPhotoSource(BuildContext context) {
    return showModalBottomSheet<ImageSource>(
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
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(
                Icons.photo_camera_outlined,
                color: AppColors.teal,
              ),
              title: const Text('Prendre une photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library_outlined,
                color: AppColors.teal,
              ),
              title: const Text('Choisir depuis la galerie'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _openEditProfileSheet(BuildContext context, AppUser user) async {
    final nomCtrl = TextEditingController(text: user.nom);
    final telCtrl = TextEditingController(text: user.telephone);
    final formKey = GlobalKey<FormState>();
    Uint8List? photoBytes = user.photoBytes;
    var saving = false;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          Future<void> pickPhoto() async {
            final source = await _pickPhotoSource(sheetContext);
            if (source == null) return;
            final file = await ImagePicker().pickImage(
              source: source,
              imageQuality: 80,
            );
            if (file == null) return;
            final bytes = await file.readAsBytes();
            setSheetState(() => photoBytes = bytes);
          }

          Future<void> submit() async {
            if (!formKey.currentState!.validate()) return;
            setSheetState(() => saving = true);
            await Future.delayed(const Duration(milliseconds: 600));
            if (sheetContext.mounted) Navigator.pop(sheetContext, true);
          }

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
            ),
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(sheetContext).size.height * 0.9,
              ),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(AppRadius.xl),
                ),
              ),
              child: SingleChildScrollView(
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
                        'Modifier le profil',
                        style: Theme.of(sheetContext).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 22),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceMuted,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Column(
                          children: [
                            PressScale(
                              onTap: saving ? () {} : pickPhoto,
                              child: CircleAvatar(
                                radius: 34,
                                backgroundColor: AppColors.teal.withValues(
                                  alpha: 0.12,
                                ),
                                backgroundImage: photoBytes != null
                                    ? MemoryImage(photoBytes!)
                                    : null,
                                child: photoBytes == null
                                    ? const Icon(
                                        Icons.person_rounded,
                                        size: 32,
                                        color: AppColors.teal,
                                      )
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              nomCtrl.text.trim().isEmpty
                                  ? 'Nom complet'
                                  : nomCtrl.text,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              user.role == UserRole.admin
                                  ? 'Administrateur'
                                  : 'Caissier',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 10),
                            PressScale(
                              onTap: saving ? () {} : pickPhoto,
                              child: const Text(
                                'Changer la photo',
                                style: TextStyle(
                                  color: AppColors.teal,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Nom complet',
                        style: Theme.of(sheetContext).textTheme.bodyMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: nomCtrl,
                        autofocus: true,
                        textCapitalization: TextCapitalization.words,
                        maxLength: 50,
                        onChanged: (_) => setSheetState(() {}),
                        decoration: const InputDecoration(
                          hintText: 'Nom complet',
                          counterText: '',
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Le nom est obligatoire.';
                          }
                          if (v.trim().length > 50) {
                            return 'Maximum 50 caractères.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Téléphone',
                        style: Theme.of(sheetContext).textTheme.bodyMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: telCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          hintText: '+216 XX XXX XXX',
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Adresse e-mail',
                        style: Theme.of(sheetContext).textTheme.bodyMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        initialValue: user.email,
                        readOnly: true,
                        enabled: false,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(
                            Icons.lock_outline_rounded,
                            size: 18,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Réservée à la connexion — non modifiable.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textFaint,
                        ),
                      ),
                      const SizedBox(height: 10),
                      PressScale(
                        onTap: saving
                            ? () {}
                            : () {
                                Navigator.pop(sheetContext);
                                _openChangePasswordSheet(context);
                              },
                        child: const Text(
                          'Changer le mot de passe',
                          style: TextStyle(
                            color: AppColors.teal,
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: saving
                                  ? null
                                  : () => Navigator.pop(sheetContext, false),
                              child: const Text('Annuler'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: saving ? null : submit,
                              child: saving
                                  ? const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        ),
                                        SizedBox(width: 10),
                                        Text('Enregistrement...'),
                                      ],
                                    )
                                  : const Text('Enregistrer'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
    if (saved == true) {
      ref
          .read(authProvider.notifier)
          .updateProfile(
            nom: nomCtrl.text.trim(),
            telephone: telCtrl.text.trim(),
            photoBytes: photoBytes,
          );
      if (context.mounted) _toast(context, '✓ Profil mis à jour avec succès');
    }
  }

  Future<void> _openSessionsSheet(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
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
                  'Sessions actives',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
              ),
            ),
            for (final session in _sessions)
              ListTile(
                leading: Icon(
                  session.device.toLowerCase().contains('iphone')
                      ? Icons.phone_iphone_rounded
                      : Icons.computer_rounded,
                  color: session.isCurrent
                      ? AppColors.teal
                      : AppColors.textSecondary,
                ),
                title: Text(session.device),
                subtitle: Text(session.detail),
                trailing: session.isCurrent
                    ? const Text(
                        'Actuel',
                        style: TextStyle(
                          color: AppColors.teal,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      )
                    : TextButton(
                        onPressed: () {
                          setState(
                            () => _sessions.removeWhere(
                              (s) => s.id == session.id,
                            ),
                          );
                          Navigator.pop(sheetContext);
                          _toast(context, 'Session déconnectée');
                        },
                        child: const Text(
                          'Déconnecter',
                          style: TextStyle(color: AppColors.danger),
                        ),
                      ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _openReportProblemSheet(
    BuildContext context,
    AppUser? user,
    bool isAdmin,
  ) async {
    final descCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    Uint8List? screenshot;

    final logs =
        'Sou9ix POS v1.0.0\n'
        'Utilisateur : ${user?.email ?? 'inconnu'} (${isAdmin ? 'Admin' : 'Caissier'})\n'
        'Magasin : ${user?.magasin ?? '-'}\n'
        'Date : ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}';

    final sent = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetContext).size.height * 0.9,
            ),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppRadius.xl),
              ),
            ),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SheetHandle(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Signaler un problème',
                        style: Theme.of(sheetContext).textTheme.titleLarge,
                      ),
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Description',
                            style: Theme.of(sheetContext).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: descCtrl,
                            autofocus: true,
                            maxLines: 4,
                            decoration: const InputDecoration(
                              hintText: 'Décrivez le problème rencontré…',
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Requis'
                                : null,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Capture d\'écran (optionnel)',
                            style: Theme.of(sheetContext).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          PhotoPickerField(
                            photoBytes: screenshot,
                            onChanged: (bytes) =>
                                setSheetState(() => screenshot = bytes),
                            placeholderLabel: 'Ajouter une capture d\'écran',
                            placeholderIcon: Icons.screenshot_outlined,
                            height: 120,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Logs joints automatiquement',
                            style: Theme.of(sheetContext).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceMuted,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                            child: Text(
                              logs,
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: AppColors.textSecondary,
                                height: 1.4,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                if (formKey.currentState!.validate()) {
                                  Navigator.pop(sheetContext, true);
                                }
                              },
                              icon: const Icon(Icons.send_rounded, size: 18),
                              label: const Text('Envoyer'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (sent == true && context.mounted) {
      _toast(context, 'Signalement envoyé. Merci !');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    final companySettings = ref.watch(companySettingsProvider);
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
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      backgroundImage: user?.photoBytes != null
                          ? MemoryImage(user!.photoBytes!)
                          : null,
                      child: user?.photoBytes == null
                          ? Text(
                              user?.initiales ?? '',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 20,
                              ),
                            )
                          : null,
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
                if (user != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.16),
                  ),
                  const SizedBox(height: 10),
                  PressScale(
                    onTap: () => _openEditProfileSheet(context, user),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.edit_outlined,
                          size: 15,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Modifier le profil',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 12,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ).animate().fadeIn(duration: 320.ms).slideY(begin: 0.05, end: 0),
          const SizedBox(height: 26),
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
            icon: Icons.remove_shopping_cart_outlined,
            label: 'Retours & pertes',
            onTap: () => context.push('/returns'),
          ),
          _MenuTile(
            icon: Icons.notifications_active_outlined,
            label: 'Alertes',
            onTap: () => context.push('/alerts'),
          ),
          // Staff and expense data stay admin-only — everything else above
          // is routine day-to-day POS work a cashier also needs.
          if (isAdmin) ...[
            _MenuTile(
              icon: Icons.badge_outlined,
              label: 'Employés',
              onTap: () => context.push('/employees'),
            ),
            _MenuTile(
              icon: Icons.wallet_outlined,
              label: 'Dépenses & charges',
              onTap: () => context.push('/expenses'),
            ),
          ],
          const SizedBox(height: 24),
          if (isAdmin) ...[
            SectionHeader(
              title: 'Magasin',
              actionLabel: 'Modifier',
              onAction: () => _openMagasinEditSheet(context),
            ),
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
                  value: companySettings.adresse,
                ),
                _InfoRow(
                  icon: Icons.call_outlined,
                  label: 'Téléphone',
                  value: companySettings.telephone,
                ),
                _InfoRow(
                  icon: Icons.badge_outlined,
                  label: 'Matricule fiscal',
                  value: companySettings.matriculeFiscal,
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
              trailing: companySettings.currency.symbol,
              onTap: () => _openDeviseSheet(context),
            ),
            _MenuTile(
              icon: Icons.translate_rounded,
              label: 'Langue',
              trailing: companySettings.language.label,
              onTap: () => _openLangueSheet(context),
            ),
            _MenuTile(
              icon: Icons.receipt_outlined,
              label: 'Nom du ticket',
              trailing: companySettings.ticketName,
              onTap: () => _openNomTicketSheet(context),
            ),
            _MenuTile(
              icon: Icons.image_outlined,
              label: 'Logo',
              trailing: companySettings.logoBytes != null ? 'Défini' : null,
              onTap: () => _openLogoSheet(context),
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
            note:
                'Les ventes seront synchronisées automatiquement\n'
                'dès le retour de la connexion.',
          ),
          const SizedBox(height: 24),
          Text(
            'Synchronisation',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          _SyncStatusCard(lastSync: DateFormat('HH:mm').format(DateTime.now())),
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
            showBadge: false,
            onChanged: (v) => _toggleBiometric(v, context),
          ),
          _MenuTile(
            icon: Icons.devices_outlined,
            label: 'Sessions actives',
            trailing: '${_sessions.length}',
            onTap: () => _openSessionsSheet(context),
          ),
          const SizedBox(height: 24),
          Text('Assistance', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          _MenuTile(
            icon: Icons.help_outline_rounded,
            label: 'Centre d\'aide',
            onTap: () => context.push('/help'),
          ),
          _MenuTile(
            icon: Icons.info_outline_rounded,
            label: 'À propos de Sou9ix',
            onTap: () => context.push('/about'),
          ),
          _MenuTile(
            icon: Icons.chat_bubble_outline_rounded,
            label: 'Nous contacter',
            onTap: () => _openContactSheet(context),
          ),
          _MenuTile(
            icon: Icons.bug_report_outlined,
            label: 'Signaler un problème',
            onTap: () => _openReportProblemSheet(context, user, isAdmin),
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

  /// Extra explanatory line shown below the row — e.g. clarifying what
  /// happens once connectivity returns for "Mode hors-ligne".
  final String? note;

  /// The Activé/Désactivé pill is redundant on rows where the switch
  /// itself is the whole story (e.g. biometric auth, which already gives
  /// its own pass/fail feedback via the system prompt).
  final bool showBadge;

  const _SwitchTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.note,
    this.showBadge = true,
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      if (showBadge) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color:
                                (value
                                        ? AppColors.success
                                        : AppColors.textFaint)
                                    .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            value ? 'Activé' : 'Désactivé',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: value
                                  ? AppColors.success
                                  : AppColors.textFaint,
                            ),
                          ),
                        ),
                      ],
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
            if (note != null) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 50),
                child: Text(
                  note!,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textFaint,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Static placeholder sync status — this app has no real backend/Firebase
/// wired up yet, so it always reads as synced rather than reflecting actual
/// connectivity. Swap [lastSync]'s source once real sync exists.
class _SyncStatusCard extends StatelessWidget {
  final String lastSync;
  const _SyncStatusCard({required this.lastSync});

  @override
  Widget build(BuildContext context) {
    return Container(
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
              color: AppColors.success.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.cloud_done_rounded,
              color: AppColors.success,
              size: 19,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Synchronisé',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Dernière synchro : Aujourd\'hui $lastSync',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MockSession {
  final String id;
  final String device;
  final String detail;
  final bool isCurrent;
  const _MockSession({
    required this.id,
    required this.device,
    required this.detail,
    required this.isCurrent,
  });
}
