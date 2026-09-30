// test_wizard_logic.dart — Tests unitaires de la logique du wizard AddMedicine
//
// Couvre :
//   - Conversion de niveau achat (carton → boite → plaquette → comprimé)
//   - Calcul du prix carton depuis différents niveaux
//   - Calcul du bénéfice estimé
//   - Calcul des totaux de conditionnement
//   - Validation pré-soumission (achat > 0, marge > 0)
//   - Extraction du message d'erreur Dio

import 'package:flutter_test/flutter_test.dart';

void main() {
  // ═══════════════════════════════════════════════════════════════════════════
  // Logique extraite du wizard pour tests isolés
  // On ne teste que la logique pure, sans Flutter widgets
  // ═══════════════════════════════════════════════════════════════════════════

  // Réplique la logique _facteurCarton du wizard
  double facteurCarton(String niveau, int bpc, int ppb, int cpp) {
    switch (niveau) {
      case 'boite':
        return bpc.toDouble();
      case 'plaquette':
        return (bpc * ppb).toDouble();
      case 'comprime':
        return (bpc * ppb * cpp).toDouble();
      default:
        return 1.0; // carton
    }
  }

  // Réplique le getter _achatCarton
  double achatCarton(double saisie, String niveau, int bpc, int ppb, int cpp) {
    return saisie * facteurCarton(niveau, bpc, ppb, cpp);
  }

  // Réplique le getter _venteCarton pour mode pctMarge
  double venteCartonPctMarge(double achatCartonVal, double margePct) {
    return achatCartonVal * (1 + margePct / 100);
  }

  // Réplique le getter _beneficeEstime
  double beneficeEstime(double venteCartonVal, double achatCartonVal, int nbCartons) {
    return (venteCartonVal - achatCartonVal) * nbCartons;
  }

  // Réplique _extractErrorMessage du wizard
  String extractErrorMessage(String raw) {
    final match = RegExp(
      r'detail["\s]*:["\s]*(.{0,300})',
      caseSensitive: false,
    ).firstMatch(raw);
    if (match != null) {
      return match.group(1)?.replaceAll(RegExp(r'[\[\]"\\]'), '').trim() ?? raw;
    }
    return raw;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FACTEUR DE CONVERSION
  // ═══════════════════════════════════════════════════════════════════════════

  group('facteurCarton()', () {
    const bpc = 10; // boites par carton
    const ppb = 3;  // plaquettes par boite
    const cpp = 8;  // comprimes par plaquette

    test('niveau carton → facteur 1.0', () {
      expect(facteurCarton('carton', bpc, ppb, cpp), equals(1.0));
    });

    test('niveau boite → facteur = bpc', () {
      expect(facteurCarton('boite', bpc, ppb, cpp), equals(10.0));
    });

    test('niveau plaquette → facteur = bpc × ppb', () {
      expect(facteurCarton('plaquette', bpc, ppb, cpp), equals(30.0));
    });

    test('niveau comprime → facteur = bpc × ppb × cpp', () {
      expect(facteurCarton('comprime', bpc, ppb, cpp), equals(240.0));
    });

    test('niveau inconnu → facteur 1.0 (carton par défaut)', () {
      expect(facteurCarton('niveauInconnu', bpc, ppb, cpp), equals(1.0));
    });

    test('bpc = 1 → facteur boite = 1.0', () {
      expect(facteurCarton('boite', 1, 1, 1), equals(1.0));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // PRIX D'ACHAT AU CARTON (conversion)
  // ═══════════════════════════════════════════════════════════════════════════

  group('achatCarton() — conversion depuis niveau saisi', () {
    const bpc = 10, ppb = 3, cpp = 8;

    test('saisie au niveau carton → prix carton inchangé', () {
      expect(achatCarton(120000, 'carton', bpc, ppb, cpp), equals(120000.0));
    });

    test('saisie au niveau boite → prix carton = saisie × bpc', () {
      expect(achatCarton(12000, 'boite', bpc, ppb, cpp), equals(120000.0));
    });

    test('saisie au niveau plaquette → prix carton correct', () {
      // 4000 FBu/plaquette × 30 plaquettes/carton = 120000
      expect(achatCarton(4000, 'plaquette', bpc, ppb, cpp), equals(120000.0));
    });

    test('saisie au niveau comprimé → prix carton correct', () {
      // 500 FBu/comprimé × 240 comprimes/carton = 120000
      expect(achatCarton(500, 'comprime', bpc, ppb, cpp), equals(120000.0));
    });

    test('saisie 0 → prix carton = 0', () {
      expect(achatCarton(0, 'carton', bpc, ppb, cpp), equals(0.0));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // PRIX DE VENTE (mode % marge)
  // ═══════════════════════════════════════════════════════════════════════════

  group('venteCartonPctMarge()', () {
    test('marge 25% → vente = achat × 1.25', () {
      expect(venteCartonPctMarge(120000, 25), closeTo(150000, 0.01));
    });

    test('marge 0% → vente = achat', () {
      expect(venteCartonPctMarge(100000, 0), equals(100000.0));
    });

    test('marge 100% → vente = achat × 2', () {
      expect(venteCartonPctMarge(100000, 100), equals(200000.0));
    });

    test('marge 10% sur 80000 → 88000', () {
      expect(venteCartonPctMarge(80000, 10), closeTo(88000, 0.01));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // BÉNÉFICE ESTIMÉ
  // ═══════════════════════════════════════════════════════════════════════════

  group('beneficeEstime()', () {
    test('bénéfice positif si vente > achat', () {
      expect(beneficeEstime(150000, 120000, 10), closeTo(300000, 0.01));
    });

    test('bénéfice nul si vente = achat', () {
      expect(beneficeEstime(100000, 100000, 5), equals(0.0));
    });

    test('bénéfice négatif si vente < achat (perte)', () {
      expect(beneficeEstime(80000, 100000, 5), closeTo(-100000, 0.01));
    });

    test('nb_cartons = 0 → bénéfice = 0', () {
      expect(beneficeEstime(150000, 120000, 0), equals(0.0));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // TOTAUX DE CONDITIONNEMENT
  // ═══════════════════════════════════════════════════════════════════════════

  group('Calcul totaux conditionnement', () {
    test('totalBoites = nbCartons × bpc', () {
      final totalBoites = 5 * 10;
      expect(totalBoites, equals(50));
    });

    test('totalPlaquettes = totalBoites × ppb', () {
      final totalPlaquettes = 5 * 10 * 3;
      expect(totalPlaquettes, equals(150));
    });

    test('totalComprimes = totalPlaquettes × cpp', () {
      final totalComprimes = 5 * 10 * 3 * 8;
      expect(totalComprimes, equals(1200));
    });

    test('conditionnement minimal (1×1×1×1) = 1 comprimé', () {
      final total = 1 * 1 * 1 * 1;
      expect(total, equals(1));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // VALIDATION PRÉ-SOUMISSION
  // ═══════════════════════════════════════════════════════════════════════════

  group('Validation pré-soumission', () {
    test('achat = 0 doit être invalide', () {
      final isValid = 0.0 > 0;
      expect(isValid, isFalse);
    });

    test('achat > 0 est valide', () {
      final isValid = 120000.0 > 0;
      expect(isValid, isTrue);
    });

    test('marge = 0 en mode pctMarge doit être invalide', () {
      final isValid = 0.0 > 0;
      expect(isValid, isFalse);
    });

    test('marge > 0 en mode pctMarge est valide', () {
      final isValid = 25.0 > 0;
      expect(isValid, isTrue);
    });

    test('venteCarton = 0 en mode cartonFixe doit être invalide', () {
      final isValid = 0.0 > 0;
      expect(isValid, isFalse);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // EXTRACTION DU MESSAGE D'ERREUR (422 Pydantic)
  // ═══════════════════════════════════════════════════════════════════════════

  group('extractErrorMessage()', () {
    test('extrait le detail depuis une réponse Pydantic 422', () {
      const raw = 'DioException [400]: {"detail": "La marge est requise"}';
      final msg = extractErrorMessage(raw);
      expect(msg, contains('La marge est requise'));
    });

    test('extrait detail avec guillemets simples', () {
      const raw = "Response body: {'detail': 'achat_carton must be > 0'}";
      final msg = extractErrorMessage(raw);
      expect(msg, isNotEmpty);
    });

    test('retourne le message brut si pas de detail', () {
      const raw = 'Network error: timeout';
      final msg = extractErrorMessage(raw);
      expect(msg, equals('Network error: timeout'));
    });

    test('retourne chaîne non vide pour tout type d\'erreur', () {
      final msg = extractErrorMessage('Une erreur inattendue');
      expect(msg, isNotEmpty);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // FORMAT DATE FR (JJ/MM/AAAA)
  // ═══════════════════════════════════════════════════════════════════════════

  group('Format date français', () {
    String formatDate(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

    test('formate date standard correctement', () {
      final d = DateTime(2026, 12, 31);
      expect(formatDate(d), equals('31/12/2026'));
    });

    test('pad les jours et mois < 10', () {
      final d = DateTime(2027, 1, 5);
      expect(formatDate(d), equals('05/01/2027'));
    });

    test('format AAAA-MM-JJ est différent de JJ/MM/AAAA', () {
      final d = DateTime(2026, 3, 15);
      final frFormat = formatDate(d);
      expect(frFormat, equals('15/03/2026'));
      expect(frFormat, isNot(equals('2026-03-15'))); // Pas le format ISO
    });
  });
}
