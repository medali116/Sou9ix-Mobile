import 'package:flutter/material.dart';

import 'package:sou9ix/core/theme/app_colors.dart';
import 'package:sou9ix/core/theme/app_theme.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const _features = [
    (Icons.qr_code_scanner_rounded, 'Caisse & scan de codes-barres'),
    (Icons.inventory_2_outlined, 'Gestion de stock et alertes'),
    (Icons.menu_book_rounded, 'Clients & crédit (karné)'),
    (Icons.receipt_long_outlined, 'Historique des ventes & tickets'),
    (Icons.people_outline_rounded, 'Comptes multi-utilisateurs'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('À propos de Sou9ix')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Center(
            child: Column(
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    gradient: AppColors.tealGradient,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: AppShadows.colored(AppColors.teal),
                  ),
                  child: const Icon(
                    Icons.storefront_rounded,
                    color: Colors.white,
                    size: 42,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Sou9ix POS',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 4),
                const Text(
                  'Version 1.0.0',
                  style: TextStyle(color: AppColors.textFaint, fontSize: 12.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'Sou9ix est une solution de caisse (POS) pensée pour les épiceries '
            'et petits commerces tunisiens : vente au comptoir, gestion de '
            'stock, crédit client (karné) et suivi des ventes, le tout dans '
            'une seule application.',
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Text(
            'Fonctionnalités',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              boxShadow: AppShadows.card,
            ),
            child: Column(
              children: [
                for (var i = 0; i < _features.length; i++) ...[
                  if (i > 0) const Divider(height: 1, indent: 56),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Icon(_features[i].$1, size: 20, color: AppColors.teal),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            _features[i].$2,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 28),
          const Center(
            child: Text(
              '© 2026 Sou9ix',
              style: TextStyle(fontSize: 12, color: AppColors.textFaint),
            ),
          ),
        ],
      ),
    );
  }
}
