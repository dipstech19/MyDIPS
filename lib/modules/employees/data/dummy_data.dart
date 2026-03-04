import '../models/employe_model.dart';
import '../models/equipe_model.dart';
import '../models/document_model.dart';

final List<Equipe> dummyEquipes = [
  Equipe(
    id: 'eq1',
    nom: 'Équipe Ventes',
    magasin: 'El Jadida #1',
    chefId: '001',
    membreIds: ['002'],
  ),
  Equipe(
    id: 'eq2',
    nom: 'Équipe Livraison',
    magasin: 'Entrepôt',
    chefId: '001',
    membreIds: ['004'],
  ),
];

final List<Employe> dummyEmployes = [
  Employe(
    id: '001', nom: 'Fatima Zahra', cin: 'BK987654',
    telephone: '0662345678', dateNaissance: '10/05/1988',
    adresse: 'Rue Hassan II, El Jadida', email: 'fatima@dips.ma',
    poste: 'Manager', magasin: 'El Jadida #1', departement: 'Administration',
    salaireBase: 8000, typeContrat: 'CDI', dateDebut: '01/01/2018',
    chefDirectId: '', cnss: '11111111', dateCnss: '01/01/2018',
    statut: EmployeStatut.enService,
    documents: [
      Document(id: 'd1', nom: 'Contrat_CDI.pdf', path: '',
          categorie: DocCategorie.contrat, dateAjout: '01/01/2018', extension: 'pdf'),
      Document(id: 'd2', nom: 'CIN_Recto.jpg', path: '',
          categorie: DocCategorie.identite, dateAjout: '01/01/2018', extension: 'jpg'),
    ],
  ),
  Employe(
    id: '002', nom: 'Ahmed Benali', cin: 'BE123456',
    telephone: '0661234567', telephone2: '0661234568',
    dateNaissance: '15/03/1995', adresse: 'Rue Ibn Khaldoun, El Jadida',
    email: 'ahmed@dips.ma', poste: 'Vendeur', magasin: 'El Jadida #1',
    departement: 'Ventes', salaireBase: 3500, typeContrat: 'CDI',
    dateDebut: '18/02/2026', chefDirectId: '001',
    cnss: '22222222', dateCnss: '18/02/2026',
    statut: EmployeStatut.enService,
  ),
  Employe(
    id: '003', nom: 'Youssef Alami', cin: 'CD456789',
    telephone: '0663456789', dateNaissance: '22/07/1990',
    adresse: 'Bd Mohammed V, El Jadida', email: 'youssef@dips.ma',
    poste: 'Caissier', magasin: 'El Jadida #2', departement: 'Ventes',
    salaireBase: 3200, typeContrat: 'CDD', dateDebut: '01/06/2025',
    finContrat: '31/05/2026', chefDirectId: '001',
    cnss: '33333333', dateCnss: '01/06/2025',
    statut: EmployeStatut.enConge,
  ),
  Employe(
    id: '004', nom: 'Salma Idrissi', cin: 'GH321654',
    telephone: '0664567890', dateNaissance: '08/11/1992',
    adresse: 'Rue Zerktouni, El Jadida', email: 'salma@dips.ma',
    poste: 'Chauffeur', magasin: 'Entrepôt', departement: 'Logistique',
    salaireBase: 3800, typeContrat: 'CDI', dateDebut: '20/09/2020',
    chefDirectId: '001', cnss: '44444444', dateCnss: '20/09/2020',
    statut: EmployeStatut.enMaladie,
  ),
  Employe(
    id: '005', nom: 'Karim Tazi', cin: 'HB741852',
    telephone: '0665678901', dateNaissance: '30/01/1987',
    adresse: 'Hay Essalam, El Jadida', email: 'karim@dips.ma',
    poste: 'Vendeur', magasin: 'El Jadida #2', departement: 'Ventes',
    salaireBase: 3500, typeContrat: 'CDI', dateDebut: '05/04/2023',
    chefDirectId: '001', cnss: '55555555', dateCnss: '05/04/2023',
    statut: EmployeStatut.quitte,
  ),
];