import 'evenement.dart';
import 'gymnase.dart';
import 'ticket.dart';

/// Les trois temps de la gestion d'un événement (décision 62) : Avant (préparer),
/// Pendant (suivre le tournoi), Après (clôturer, bilan, export).
enum OngletEvenement { avant, pendant, apres }

/// L'onglet ouvert d'emblée : en préparation -> Avant ; en cours -> Pendant ;
/// clôturé -> Après.
OngletEvenement ongletInitial(Evenement ev) => ev.enPreparation
    ? OngletEvenement.avant
    : ev.enCours
        ? OngletEvenement.pendant
        : OngletEvenement.apres;

/// Une des quatre tâches d'Avant : faite ou non, et ce qu'on lit sous son titre.
class TacheAvant {
  const TacheAvant({
    required this.cle,
    required this.titre,
    required this.faite,
    required this.detail,
  });

  /// Identifiant stable (sert aux Key des tests).
  final String cle;
  final String titre;
  final bool faite;
  final String detail;
}

/// Durée affichée : « 2 », « 2,5 » (sans zéro inutile).
String formaterJours(double jours) => jours == jours.roundToDouble()
    ? jours.toInt().toString()
    : jours.toString().replaceAll('.', ',');

/// Les quatre tâches d'Avant, dans l'ordre, avec leur règle « faite » :
/// - stock de départ : au moins un produit compté, dans au moins un gymnase ;
/// - personnes et durée : chaque gymnase a ses personnes ;
/// - prévision : « C'est vérifié » a été appuyé ;
/// - courses : au moins une série validée. [seriesValidees] = null quand la vue
///   complète n'est pas offerte (gestionnaire d'un seul gymnase) : tâche réservée.
List<TacheAvant> tachesAvant({
  required Evenement ev,
  required List<Gymnase> gymnases,
  required Map<String, Map<String, StockDepart>> stocksDepart,
  required int? seriesValidees,
}) {
  final comptes = {for (final g in stocksDepart.values) ...g.keys};
  final stockFait = comptes.isNotEmpty;

  final sansPersonnes = [
    for (final g in gymnases)
      if (g.personnes <= 0) g.nom,
  ];
  final personnesFaites = gymnases.isNotEmpty && sansPersonnes.isEmpty;
  final total = gymnases.fold<int>(0, (s, g) => s + g.personnes);

  final coursesFaites = seriesValidees != null && seriesValidees >= 1;

  return [
    TacheAvant(
      cle: 'stock',
      titre: 'Stock de départ',
      faite: stockFait,
      detail: stockFait
          ? '${comptes.length} produit${comptes.length > 1 ? 's' : ''} compté'
              '${comptes.length > 1 ? 's' : ''}'
          : 'Aucun produit compté',
    ),
    TacheAvant(
      cle: 'personnes',
      titre: 'Personnes et durée',
      faite: personnesFaites,
      detail: gymnases.isEmpty
          ? 'Aucun gymnase'
          : personnesFaites
              ? '$total personnes · ${formaterJours(ev.nbJours)} '
                  'jour${ev.nbJours == 1 ? '' : 's'}'
              : 'À compléter : ${sansPersonnes.join(', ')}',
    ),
    TacheAvant(
      cle: 'prevision',
      titre: 'Prévision',
      faite: ev.previsionVerifiee,
      detail: ev.previsionVerifiee ? 'Vérifiée' : 'À vérifier',
    ),
    TacheAvant(
      cle: 'courses',
      titre: 'Courses',
      faite: coursesFaites,
      detail: seriesValidees == null
          ? 'Réservé au responsable'
          : seriesValidees == 0
              ? 'Pas encore de série validée'
              : seriesValidees == 1
                  ? '1 série validée'
                  : '$seriesValidees séries validées',
    ),
  ];
}

/// Un produit à surveiller dans un gymnase : épuisé, vide ou stock bas.
class ASurveiller {
  const ASurveiller({
    required this.produitId,
    required this.nomProduit,
    required this.gymnaseId,
    required this.nomGymnase,
    required this.etat,
  });

  final String produitId;
  final String nomProduit;
  final String gymnaseId;
  final String nomGymnase;
  final EtatStock etat;
}

/// Ce qui demande une action au tournoi : épuisé d'abord, puis vide, puis stock bas,
/// puis le nom du produit et du gymnase. [etats] : gymnase -> produit -> état.
List<ASurveiller> aSurveiller({
  required List<ProduitEvenement> produits,
  required List<Gymnase> gymnases,
  required Map<String, Map<String, EtatStock>> etats,
}) {
  const rang = {EtatStock.epuise: 0, EtatStock.vide: 1, EtatStock.bas: 2};
  final liste = <ASurveiller>[];
  for (final g in gymnases) {
    for (final p in produits) {
      final etat = etats[g.id]?[p.id];
      if (etat == null || !rang.containsKey(etat)) continue;
      liste.add(ASurveiller(
        produitId: p.id,
        nomProduit: p.nom,
        gymnaseId: g.id,
        nomGymnase: g.nom,
        etat: etat,
      ));
    }
  }
  liste.sort((a, b) {
    final c = rang[a.etat]!.compareTo(rang[b.etat]!);
    return c != 0 ? c : a.nomProduit.toLowerCase().compareTo(b.nomProduit.toLowerCase());
  });
  return liste;
}
