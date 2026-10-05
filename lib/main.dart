import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'connexion.dart';
import 'depot_associations.dart';
import 'ecran_caisse.dart';
import 'ecran_racine.dart';
import 'firebase_options.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.android);
  runApp(LeComptoir(
    accueil: EcranRacine(
      auth: FirebaseAuth.instance,
      depot: DepotAssociations(FirebaseFirestore.instance),
      fournisseurGoogle: fournisseurGoogleReel,
    ),
  ));
}

class LeComptoir extends StatelessWidget {
  const LeComptoir({super.key, this.accueil = const EcranCaisse()});

  final Widget accueil;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Le Comptoir',
      theme: themeComptoir(),
      home: accueil,
    );
  }
}
