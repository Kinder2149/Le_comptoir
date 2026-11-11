import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'connexion.dart';
import 'depot_associations.dart';
import 'ecran_caisse.dart';
import 'ecran_racine.dart';
import 'firebase_options.dart';
import 'partage.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.android);
  runApp(LeComptoir(
    navigatorKey: navigatorCle,
    accueil: EcranRacine(
      auth: FirebaseAuth.instance,
      depot: DepotAssociations(FirebaseFirestore.instance),
      fournisseurGoogle: fournisseurGoogleReel,
    ),
  ));
}

class LeComptoir extends StatelessWidget {
  const LeComptoir(
      {super.key, this.accueil = const EcranCaisse(), this.navigatorKey});

  final Widget accueil;

  /// Clé du navigateur, fournie par l'application réelle seulement (la feuille « Enregistrer
  /// ou partager » en a besoin). Les parcours de test montent l'application sans elle : une
  /// clé globale garderait l'ancien écran d'un parcours au suivant.
  final GlobalKey<NavigatorState>? navigatorKey;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Le Comptoir',
      navigatorKey: navigatorKey,
      theme: themeComptoir(),
      home: accueil,
    );
  }
}
