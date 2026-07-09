import 'package:flutter/material.dart';

import 'package:sou9ix/core/theme/app_colors.dart';
import 'package:sou9ix/core/theme/app_theme.dart';

class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Centre d\'aide')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          _HelpSection(
            title: 'Vente & Caisse',
            items: [
              _HelpItem(
                'Comment scanner un produit ?',
                'Ouvrez l\'onglet Caisse et pointez la caméra vers le code-barres — le produit est ajouté automatiquement au panier dès qu\'il est reconnu.',
              ),
              _HelpItem(
                'Que faire si le code-barres ne scanne pas ?',
                'Utilisez "Saisir le code" pour taper l\'EAN manuellement, ou "Sans code-barres" pour chercher le produit par son nom.',
              ),
              _HelpItem(
                'Comment faire une vente à crédit (karné) ?',
                'Lors de l\'encaissement, choisissez le mode de paiement "Crédit" puis sélectionnez le client dans la liste (ou créez-le directement avec "+ Nouveau").',
              ),
              _HelpItem(
                'Comment vendre un produit au poids ?',
                'Touchez un produit vendu au kg : un clavier dédié s\'ouvre pour saisir le poids et calcule automatiquement le montant. Les boutons -/+ ajoutent ou retirent ensuite le même poids.',
              ),
            ],
          ),
          _HelpSection(
            title: 'Produits & Stock',
            items: [
              _HelpItem(
                'Comment ajouter un nouveau produit ?',
                'Depuis Catalogue produits, touchez le bouton "+" en haut de l\'écran et remplissez la fiche produit.',
              ),
              _HelpItem(
                'Comment savoir quels produits sont en stock faible ?',
                'L\'écran Stock affiche un badge orange "Stock faible" et un badge rouge "Rupture" sur chaque produit concerné, avec un résumé en haut de la page.',
              ),
            ],
          ),
          _HelpSection(
            title: 'Clients & Crédit',
            items: [
              _HelpItem(
                'Comment ajouter un client ?',
                'Depuis l\'écran d\'encaissement en mode Crédit, touchez "+ Nouveau" à côté de la recherche client.',
              ),
              _HelpItem(
                'Comment consulter la dette d\'un client ?',
                'Ouvrez Clients & crédit (karné) : chaque client affiche son solde dû, avec un bouton "Solder" pour l\'encaisser.',
              ),
            ],
          ),
          _HelpSection(
            title: 'Mon compte',
            items: [
              _HelpItem(
                'Comment changer mon mot de passe ?',
                'Allez dans Mon compte > Sécurité > Changer le mot de passe.',
              ),
              _HelpItem(
                'Comment définir un PIN caisse ?',
                'Allez dans Mon compte > Sécurité > PIN caisse.',
              ),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.support_agent_rounded,
                  color: AppColors.teal,
                  size: 26,
                ),
                const SizedBox(height: 8),
                Text(
                  'Vous ne trouvez pas de réponse ?',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'Utilisez "Nous contacter" depuis Mon compte > Assistance.',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HelpItem {
  final String question;
  final String answer;
  const _HelpItem(this.question, this.answer);
}

class _HelpSection extends StatelessWidget {
  final String title;
  final List<_HelpItem> items;
  const _HelpSection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              boxShadow: AppShadows.card,
            ),
            child: Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0)
                    const Divider(height: 1, indent: 16, endIndent: 16),
                  Theme(
                    data: Theme.of(
                      context,
                    ).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      title: Text(
                        items[i].question,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      expandedAlignment: Alignment.centerLeft,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            items[i].answer,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
