import 'package:flutter_test/flutter_test.dart';
import 'package:le_comptoir/depot_associations.dart';

void main() {
  test('libellés de rôle', () {
    expect(libelleRole('responsable'), 'Responsable');
    expect(libelleRole('gestionnaire'), 'Gestionnaire');
    expect(libelleRole('benevole'), 'Bénévole');
    expect(libelleRole('inconnu'), 'Bénévole');
  });

  test('statut affiché : bénévole, en attente, gestionnaire, responsable', () {
    expect(libelleStatut(const Membre('u', 'Lea', 'benevole')), 'Bénévole');
    expect(
        libelleStatut(const Membre('u', 'Lea', 'benevole', enAttente: true)),
        'Gestionnaire en attente');
    expect(libelleStatut(const Membre('u', 'Lea', 'gestionnaire')),
        'Gestionnaire');
    expect(libelleStatut(const Membre('u', 'Chef', 'responsable')),
        'Responsable');
  });

  test('un membre n\'est en attente que s\'il l\'est explicitement', () {
    expect(const Membre('u', 'Lea', 'benevole').enAttente, isFalse);
    expect(const Membre('u', 'Chef', 'responsable').estResponsable, isTrue);
    expect(const Membre('u', 'Lea', 'gestionnaire').estResponsable, isFalse);
  });
}
