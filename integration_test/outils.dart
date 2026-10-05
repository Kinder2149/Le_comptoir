// Outils communs aux tests d'intégration (émulateur Android + copie locale
// de Firebase ; 10.0.2.2 = le PC vu depuis l'émulateur).
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:le_comptoir/connexion.dart';
import 'package:le_comptoir/depot_associations.dart';
import 'package:le_comptoir/depot_evenements.dart';
import 'package:le_comptoir/ecran_menu.dart' show SelecteurPhoto, selecteurPhotoReel;
import 'package:le_comptoir/ecran_qr.dart' show LecteurQr, lecteurQrReel;
import 'package:le_comptoir/ecran_racine.dart';
import 'package:le_comptoir/firebase_options.dart';
import 'package:le_comptoir/main.dart';

Future<void> attendre(WidgetTester tester, Finder cible) async {
  for (var i = 0; i < 150; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (cible.evaluate().isNotEmpty) return;
  }
  throw TestFailure('Jamais apparu : $cible');
}

/// Identifiant du gymnase unique d'un événement (le gymnase « Principal »
/// créé avec lui).
Future<String> gymnaseUnique(DepotEvenements depot, String evenementId) async =>
    (await depot.suivreGymnases(evenementId).first).single.id;

/// Texte d'un élément : celui du Text, ou, pour un bloc (ligne du bilan), les
/// textes qu'il contient dans l'ordre, joints par « | ».
String contenuDe(WidgetTester tester, Finder f) {
  final w = tester.widget(f);
  if (w is Text) return w.data!;
  return tester
      .widgetList<Text>(find.descendant(of: f, matching: find.byType(Text)))
      .map((t) => t.data!)
      .join(' | ');
}

String texte(WidgetTester tester, String cle) =>
    contenuDe(tester, find.byKey(Key(cle)));

/// Compte Google simulé (l'émulateur Auth accepte ce faux jeton).
FournisseurGoogle fauxGoogle(String identite) => () async =>
    GoogleAuthProvider.credential(
      idToken: jsonEncode({
        'sub': identite,
        'email': '$identite@test.fr',
        'email_verified': true,
      }),
    );

/// L'utilisateur ferme la fenêtre Google sans choisir de compte.
Future<AuthCredential?> googleAnnule() async => null;

Future<void> initialiser() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.android);
  await FirebaseAuth.instance.useAuthEmulator('10.0.2.2', 9099);
  FirebaseFirestore.instance.useFirestoreEmulator('10.0.2.2', 8080);
}

/// Monte l'application, comme un téléphone neuf (cle différente = nouvel état).
Future<void> ouvrir(
  WidgetTester tester,
  String cle,
  FournisseurGoogle google, {
  SelecteurPhoto selecteurPhoto = selecteurPhotoReel,
  LecteurQr lecteurQr = lecteurQrReel,
}) =>
    tester.pumpWidget(
      KeyedSubtree(
        key: Key(cle),
        child: LeComptoir(
          accueil: EcranRacine(
            auth: FirebaseAuth.instance,
            depot: DepotAssociations(FirebaseFirestore.instance),
            fournisseurGoogle: google,
            selecteurPhoto: selecteurPhoto,
            lecteurQr: lecteurQr,
          ),
        ),
      ),
    );

Future<void> creerAssociationParLInterface(
  WidgetTester tester, {
  String nom = 'Club Test',
  String prenom = 'Chef',
}) async {
  await attendre(tester, find.byKey(const Key('creer')));
  await tester.enterText(find.byKey(const Key('nom_association')), nom);
  await tester.enterText(find.byKey(const Key('prenom_creation')), prenom);
  await tester.tap(find.byKey(const Key('creer')));
  await attendre(tester, find.byKey(const Key('code')));
}

// ---------------------------------------------------------------------------
// Écritures « d'un autre téléphone » : envoyées directement au serveur local
// avec le jeton de l'utilisateur concerné (requêtes HTTP), comme le ferait son
// application. Permet de poser des ventes datées précisément.
// ---------------------------------------------------------------------------
const restRacine =
    'http://10.0.2.2:8080/v1/projects/le-comptoir-60ba8/databases/(default)/documents';

Map<String, dynamic> restTs(DateTime d) =>
    {'timestampValue': d.toUtc().toIso8601String()};
Map<String, dynamic> restEntier(int n) => {'integerValue': '$n'};
Map<String, dynamic> restTexte(String s) => {'stringValue': s};
Map<String, dynamic> restLigne(String id, String nom, int prix, int q) => {
      'mapValue': {
        'fields': {
          'produitId': restTexte(id),
          'nom': restTexte(nom),
          'prixCentimes': restEntier(prix),
          'quantite': restEntier(q),
        }
      }
    };

/// Champs d'une vente (lignes, total en centimes, mode, date de la vente).
Map<String, dynamic> restVente(List<Map<String, dynamic>> lignes, int total,
        String mode, DateTime quand, String gymnaseId) =>
    {
      'gymnaseId': restTexte(gymnaseId),
      'lignes': {'arrayValue': {'values': lignes}},
      'totalCentimes': restEntier(total),
      'mode': restTexte(mode),
      'creeLe': restTs(quand),
    };

/// [chemin] peut contenir une chaîne de requête (ex. `?updateMask.fieldPaths=stock`).
/// Renvoie le code HTTP (200 = accepté par les règles).
Future<int> restEcrire(
    String methode, String chemin, String jeton, Map<String, dynamic> champs) async {
  final client = HttpClient();
  final req = await client.openUrl(methode, Uri.parse('$restRacine/$chemin'));
  req.headers.set('Authorization', 'Bearer $jeton');
  req.headers.set('Content-Type', 'application/json');
  req.write(jsonEncode({'fields': champs}));
  final rep = await req.close();
  await rep.drain<void>();
  client.close();
  return rep.statusCode;
}

/// Nombre de documents d'une collection, lu avec les droits d'administrateur de
/// la copie locale (les règles ne s'appliquent pas) : sert à vérifier qu'il ne
/// reste rien après une suppression.
Future<int> restNbDocuments(String chemin) async {
  final client = HttpClient();
  final req = await client.getUrl(Uri.parse('$restRacine/$chemin'));
  req.headers.set('Authorization', 'Bearer owner');
  final rep = await req.close();
  final corps = await rep.transform(utf8.decoder).join();
  client.close();
  if (rep.statusCode != 200) return -rep.statusCode;
  final json = jsonDecode(corps) as Map<String, dynamic>;
  return (json['documents'] as List?)?.length ?? 0;
}

/// Code HTTP de la lecture d'un document (administrateur) : 200 = existe, 404 = absent.
Future<int> restStatutDocument(String chemin) async {
  final client = HttpClient();
  final req = await client.getUrl(Uri.parse('$restRacine/$chemin'));
  req.headers.set('Authorization', 'Bearer owner');
  final rep = await req.close();
  await rep.drain<void>();
  client.close();
  return rep.statusCode;
}

/// Ouvre la caisse d'un membre dans un gymnase « depuis son téléphone » : la
/// caisse et son pointeur partent dans le même lot, comme dans l'application.
/// [base] = `associations/{a}/evenements/{e}`. Renvoie le code HTTP.
Future<int> restOuvrirCaisse(String base, String uid, String gymnaseId,
    String jeton, String prenom, DateTime ouverteLe) async {
  const racine = 'projects/le-comptoir-60ba8/databases/(default)/documents';
  final caisseId = '${uid}__$gymnaseId';
  final client = HttpClient();
  final req = await client.postUrl(Uri.parse('$restRacine:commit'));
  req.headers.set('Authorization', 'Bearer $jeton');
  req.headers.set('Content-Type', 'application/json');
  req.write(jsonEncode({
    'writes': [
      {
        'update': {
          'name': '$racine/$base/caisses/$caisseId',
          'fields': {
            'prenom': restTexte(prenom),
            'statut': restTexte('ouverte'),
            'ouverteLe': restTs(ouverteLe),
            'membreUid': restTexte(uid),
            'gymnaseId': restTexte(gymnaseId),
          },
        },
      },
      {
        'update': {
          'name': '$racine/$base/ouvertes/$uid',
          'fields': {
            'gymnaseId': restTexte(gymnaseId),
            'caisseId': restTexte(caisseId),
          },
        },
      },
    ],
  }));
  final rep = await req.close();
  await rep.drain<void>();
  client.close();
  return rep.statusCode;
}
