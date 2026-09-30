/// Service centralisé de calcul de prix multi-niveaux.
/// Utilisé par la Liste, le POS et le Dashboard.
import 'package:frontend1/models/medicine_pricing.dart';
import 'package:intl/intl.dart';

enum NiveauPrix { comprime, plaquette, boite, carton }

class PrixCalculator {
  /// Formatte un montant en FBu lisible
  static String fmtFBu(double v) {
    final f = NumberFormat('#,###', 'fr_FR');
    return '${f.format(v.round())} FBu';
  }

  /// Prix de vente au niveau demandé
  static double prixVenteAuNiveau(MedicinePricing med, NiveauPrix niveau) {
    switch (niveau) {
      case NiveauPrix.comprime:
        return med.venteComprime;
      case NiveauPrix.plaquette:
        return med.ventePlaquette;
      case NiveauPrix.boite:
        return med.venteBoite;
      case NiveauPrix.carton:
        return med.venteCarton;
    }
  }

  /// Prix d'achat au niveau demandé
  static double prixAchatAuNiveau(MedicinePricing med, NiveauPrix niveau) {
    switch (niveau) {
      case NiveauPrix.comprime:
        return med.achatComprime;
      case NiveauPrix.plaquette:
        return med.achatPlaquette;
      case NiveauPrix.boite:
        return med.achatBoite;
      case NiveauPrix.carton:
        return med.achatCarton;
    }
  }

  /// Quantité stock (comprimés) convertie vers un niveau
  static double qteAuNiveau(MedicinePricing med, NiveauPrix niveau) {
    switch (niveau) {
      case NiveauPrix.comprime:
        return med.totalComprimes.toDouble();
      case NiveauPrix.plaquette:
        final parPlaq = med.comprimesParPlaquette;
        return parPlaq > 0 ? med.totalComprimes / parPlaq : 0;
      case NiveauPrix.boite:
        final parBoite = med.plaquettesParBoite * med.comprimesParPlaquette;
        return parBoite > 0 ? med.totalComprimes / parBoite : 0;
      case NiveauPrix.carton:
        final parCarton = med.boitesParCarton *
            med.plaquettesParBoite *
            med.comprimesParPlaquette;
        return parCarton > 0 ? med.totalComprimes / parCarton : 0;
    }
  }

  /// Bénéfice par unité au niveau donné
  static double beneficeUnitaire(MedicinePricing med, NiveauPrix niveau) {
    return prixVenteAuNiveau(med, niveau) - prixAchatAuNiveau(med, niveau);
  }

  /// Bénéfice total estimé
  static double beneficeTotal(MedicinePricing med) {
    return med.beneficeEstime;
  }

  /// Label du niveau
  static String niveauLabel(NiveauPrix niveau) {
    switch (niveau) {
      case NiveauPrix.comprime:
        return 'Unité';
      case NiveauPrix.plaquette:
        return 'Plaquette';
      case NiveauPrix.boite:
        return 'Boîte';
      case NiveauPrix.carton:
        return 'Carton';
    }
  }

  /// Icône du niveau
  static String niveauEmoji(NiveauPrix niveau) {
    switch (niveau) {
      case NiveauPrix.comprime:
        return '💎';
      case NiveauPrix.plaquette:
        return '💊';
      case NiveauPrix.boite:
        return '📦';
      case NiveauPrix.carton:
        return '🏢';
    }
  }

  /// Vérifie si l'entrée expire bientôt (dans N jours)
  static bool expireDans(MedicinePricing med, int jours) {
    if (med.datePeremption == null) return false;
    final diff = med.datePeremption!.difference(DateTime.now()).inDays;
    return diff > 0 && diff <= jours;
  }

  /// Vérifie si l'entrée est périmée
  static bool estPerime(MedicinePricing med) {
    if (med.datePeremption == null) return false;
    return med.datePeremption!.isBefore(DateTime.now());
  }

  /// Vérifie si stock est en rupture
  static bool enRupture(MedicinePricing med) {
    return med.totalComprimes <= 0;
  }
}
