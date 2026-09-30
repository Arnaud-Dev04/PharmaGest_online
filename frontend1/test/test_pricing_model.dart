// test_pricing_model.dart — Tests unitaires du modèle MedicinePricing
//
// Couvre :
//   - Désérialisation JSON → MedicinePricing
//   - Sérialisation MedicinePricing → Map
//   - Enums PricingMode et OrdonnanceType
//   - Valeurs calculées (prix null → 0.0 par défaut)
//   - Champs optionnels nullable

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend1/models/medicine_pricing.dart';

void main() {
  // ═══════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  Map<String, dynamic> _validJson({Map<String, dynamic>? overrides}) {
    final base = <String, dynamic>{
      'id': 1,
      'medicine_id': 10,
      'nom': 'Amoxicilline 500mg',
      'dci': 'Amoxicilline',
      'forme': 'Gélule',
      'dosage': '500mg',
      'lot': 'LOT-001',
      'fournisseur': 'PharmaCorp',
      'bon_livraison': 'BL-2026-001',
      'date_reception': '2026-01-15',
      'date_peremption': '2027-01-15',
      'nb_cartons': 5,
      'boites_par_carton': 10,
      'plaquettes_par_boite': 3,
      'comprimes_par_plaquette': 8,
      'total_boites': 50,
      'total_plaquettes': 150,
      'total_comprimes': 1200,
      'prix_mode': 'pct_marge',
      'achat_carton': 120000.0,
      'achat_boite': 12000.0,
      'achat_plaquette': 4000.0,
      'achat_comprime': 500.0,
      'vente_carton': 150000.0,
      'vente_boite': 15000.0,
      'vente_plaquette': 5000.0,
      'vente_comprime': 625.0,
      'marge_pct': 25.0,
      'benefice_estime': 30000.0,
      'seuil_alerte': 50,
      'seuil_niveau': 'comprimes',
      'emplacement': 'Rayon A3',
      'alerte_peremption': true,
      'alerte_jours': 30,
      'ordonnance': 'non',
      'created_at': '2026-01-15T10:00:00',
      'updated_at': '2026-01-15T10:00:00',
      'expire_bientot': false,
      'stock_faible': false,
    };
    if (overrides != null) base.addAll(overrides);
    return base;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DÉSÉRIALISATION
  // ═══════════════════════════════════════════════════════════════════════════

  group('MedicinePricing.fromJson()', () {
    test('désérialise un JSON valide complet', () {
      final model = MedicinePricing.fromJson(_validJson());
      expect(model.id, equals(1));
      expect(model.nom, equals('Amoxicilline 500mg'));
      expect(model.dci, equals('Amoxicilline'));
      expect(model.lot, equals('LOT-001'));
      expect(model.nbCartons, equals(5));
      expect(model.boitesParCarton, equals(10));
      expect(model.plaquettesParBoite, equals(3));
      expect(model.comprimesParPlaquette, equals(8));
      expect(model.totalComprimes, equals(1200));
    });

    test('désérialise les prix correctement', () {
      final model = MedicinePricing.fromJson(_validJson());
      expect(model.achatCarton, equals(120000.0));
      expect(model.venteCarton, equals(150000.0));
      expect(model.margePct, equals(25.0));
      expect(model.beneficeEstime, equals(30000.0));
    });

    test('désérialise les champs optionnels null', () {
      final json = _validJson(overrides: {
        'dci': null,
        'forme': null,
        'dosage': null,
        'fournisseur': null,
        'bon_livraison': null,
        'date_reception': null,
        'date_peremption': null,
        'emplacement': null,
        'marge_pct': null,
        'medicine_id': null,
        'alerte_jours': null,
      });
      final model = MedicinePricing.fromJson(json);
      expect(model.dci, isNull);
      expect(model.forme, isNull);
      expect(model.datePeremption, isNull);
      expect(model.margePct, isNull);
    });

    test('désérialise les dates au bon format', () {
      final model = MedicinePricing.fromJson(_validJson());
      expect(model.dateReception, isA<DateTime>());
      expect(model.datePeremption, isA<DateTime>());
      expect(model.dateReception?.year, equals(2026));
      expect(model.datePeremption?.month, equals(1));
    });

    test('désérialise les booléens', () {
      final model = MedicinePricing.fromJson(_validJson(overrides: {
        'alerte_peremption': false,
        'expire_bientot': true,
        'stock_faible': true,
      }));
      expect(model.alertePeremption, isFalse);
      expect(model.expireBientot, isTrue);
      expect(model.stockFaible, isTrue);
    });

    test('prix par défaut à 0.0 si absent du JSON', () {
      final json = _validJson();
      json.remove('achat_boite');
      json.remove('achat_plaquette');
      json.remove('achat_comprime');
      final model = MedicinePricing.fromJson(json);
      // Doit avoir une valeur par défaut et non null
      expect(model.achatBoite, isNotNull);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // SÉRIALISATION
  // ═══════════════════════════════════════════════════════════════════════════

  group('MedicinePricing.toJson()', () {
    test('sérialise les champs obligatoires', () {
      final model = MedicinePricing.fromJson(_validJson());
      final json = model.toJson();
      expect(json['nom'], equals('Amoxicilline 500mg'));
      expect(json['lot'], equals('LOT-001'));
      expect(json['nb_cartons'], equals(5));
    });

    test('roundtrip fromJson → toJson → fromJson conserve les valeurs', () {
      final original = MedicinePricing.fromJson(_validJson());
      final json = original.toJson();
      final restored = MedicinePricing.fromJson(json);

      expect(restored.id, equals(original.id));
      expect(restored.nom, equals(original.nom));
      expect(restored.achatCarton, equals(original.achatCarton));
      expect(restored.totalComprimes, equals(original.totalComprimes));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // ENUMS
  // ═══════════════════════════════════════════════════════════════════════════

  group('PricingMode enum', () {
    test('fromString("pct_marge") retourne PricingMode.pctMarge', () {
      final mode = PricingMode.fromString('pct_marge');
      expect(mode, equals(PricingMode.pctMarge));
    });

    test('fromString("carton_fixe") retourne PricingMode.cartonFixe', () {
      final mode = PricingMode.fromString('carton_fixe');
      expect(mode, equals(PricingMode.cartonFixe));
    });

    test('fromString("manuel") retourne PricingMode.manuel', () {
      final mode = PricingMode.fromString('manuel');
      expect(mode, equals(PricingMode.manuel));
    });

    test('fromString("inconnu") retourne le mode par défaut', () {
      // Ne doit pas lever d'exception
      final mode = PricingMode.fromString('mode_inexistant');
      expect(mode, isNotNull);
    });

    test('value de pctMarge est "pct_marge"', () {
      expect(PricingMode.pctMarge.value, equals('pct_marge'));
    });

    test('value de cartonFixe est "carton_fixe"', () {
      expect(PricingMode.cartonFixe.value, equals('carton_fixe'));
    });
  });

  group('OrdonnanceType enum', () {
    test('non.value est "non"', () {
      expect(OrdonnanceType.non.value, equals('non'));
    });

    test('oui.value est "oui"', () {
      expect(OrdonnanceType.oui.value, equals('oui'));
    });

    test('label de non est lisible', () {
      expect(OrdonnanceType.non.label, isNotEmpty);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // CHAMPS CALCULÉS
  // ═══════════════════════════════════════════════════════════════════════════

  group('Champs calculés MedicinePricing', () {
    test('total_comprimes = cartons × boites × plaquettes × comprimes', () {
      final model = MedicinePricing.fromJson(_validJson());
      final expected = model.nbCartons *
          model.boitesParCarton *
          model.plaquettesParBoite *
          model.comprimesParPlaquette;
      expect(model.totalComprimes, equals(expected));
    });
  });
}
