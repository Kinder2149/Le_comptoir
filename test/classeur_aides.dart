import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:le_comptoir/classeur.dart';

/// En-têtes de l'ancien Menu (avant la décision 66) : les classeurs anciens doivent
/// rester lisibles, les tests d'import s'en servent pour le prouver.
const entetesMenuAncien = [
  enteteProduit,
  'Prix',
  'Type',
  'Provenance',
  'Verres par litre',
  'Parts par gâteau',
  'Recette',
  enteteConsommation,
];

/// Un classeur de test avec les feuilles « Menu » (ancien format), « Stock de départ » et
/// « Historique » : ligne d'aide, ligne d'en-têtes, puis les données.
Uint8List classeurDeTest({
  List<List<Object?>> menu = const [],
  List<List<Object?>> stock = const [],
  List<List<Object?>> historique = const [],
}) {
  final x = Excel.createExcel();
  final defaut = x.getDefaultSheet() ?? 'Sheet1';
  x.rename(defaut, feuilleMenu);
  CellValue? v(Object? o) => switch (o) {
        null => null,
        int n => IntCellValue(n),
        double n => DoubleCellValue(n),
        _ => TextCellValue(o.toString()),
      };
  void feuille(String nom, List<String> entetes, List<List<Object?>> lignes) {
    final f = x[nom];
    f.appendRow([TextCellValue('aide')]);
    f.appendRow([for (final e in entetes) TextCellValue(e)]);
    for (final l in lignes) {
      f.appendRow([for (final c in l) v(c)]);
    }
  }

  feuille(feuilleMenu, entetesMenuAncien, menu);
  feuille(feuilleStock, entetesStock, stock);
  feuille(feuilleHistorique, entetesHistorique, historique);
  feuille(feuilleCourses, entetesCourses, const []);
  return Uint8List.fromList(x.encode()!);
}

/// Un vrai classeur Excel qui n'est pas celui du Comptoir : une seule feuille quelconque.
Uint8List classeurAutreFormat() {
  final x = Excel.createExcel();
  final f = x[x.getDefaultSheet() ?? 'Sheet1'];
  f.appendRow([TextCellValue('Nom'), TextCellValue('Age')]);
  f.appendRow([TextCellValue('Léa'), IntCellValue(12)]);
  return Uint8List.fromList(x.encode()!);
}
