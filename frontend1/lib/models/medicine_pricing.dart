/// Modes de fixation des prix
enum PricingMode {
  pctMarge('pct_marge', 'Pourcentage de marge'),
  manuel('manuel', 'Saisie manuelle'),
  cartonFixe('carton_fixe', 'Prix carton fixé');

  final String value;
  final String label;
  const PricingMode(this.value, this.label);

  static PricingMode fromString(String value) {
    return PricingMode.values.firstWhere(
      (e) => e.value == value,
      orElse: () => PricingMode.pctMarge,
    );
  }
}

/// Types d'ordonnance
enum OrdonnanceType {
  non('non', 'Sans ordonnance'),
  oui('oui', 'Avec ordonnance'),
  liste1('liste1', 'Liste I (toxiques)'),
  liste2('liste2', 'Liste II (dangereux)'),
  stup('stup', 'Stupéfiants');

  final String value;
  final String label;
  const OrdonnanceType(this.value, this.label);

  static OrdonnanceType fromString(String value) {
    return OrdonnanceType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => OrdonnanceType.non,
    );
  }
}

/// Modèle de données pour une entrée de prix médicament
class MedicinePricing {
  final int id;
  final int? medicineId;
  final String nom;
  final String? dci;
  final String? forme;
  final String? dosage;
  final String lot;
  final String? fournisseur;
  final String? bonLivraison;
  final DateTime? dateReception;
  final DateTime? datePeremption;

  // Conditionnement
  final int nbCartons;
  final int boitesParCarton;
  final int plaquettesParBoite;
  final int comprimesParPlaquette;
  final int totalBoites;
  final int totalPlaquettes;
  final int totalComprimes;

  // Prix
  final String prixMode;
  final double achatCarton;
  final double achatBoite;
  final double achatPlaquette;
  final double achatComprime;
  final double venteCarton;
  final double venteBoite;
  final double ventePlaquette;
  final double venteComprime;
  final double? margePct;
  final double beneficeEstime;

  // Stock & Alertes
  final int seuilAlerte;
  final String seuilNiveau;
  final String? emplacement;
  final bool alertePeremption;
  final int? alerteJours;
  final String ordonnance;

  final DateTime createdAt;
  final DateTime updatedAt;

  // Calculated alerts
  final bool expireBientot;
  final bool stockFaible;
  final bool enRupture;
  final double stockActuel;

  MedicinePricing({
    required this.id,
    this.medicineId,
    required this.nom,
    this.dci,
    this.forme,
    this.dosage,
    required this.lot,
    this.fournisseur,
    this.bonLivraison,
    this.dateReception,
    this.datePeremption,
    required this.nbCartons,
    required this.boitesParCarton,
    required this.plaquettesParBoite,
    required this.comprimesParPlaquette,
    required this.totalBoites,
    required this.totalPlaquettes,
    required this.totalComprimes,
    required this.prixMode,
    required this.achatCarton,
    this.achatBoite = 0.0,
    this.achatPlaquette = 0.0,
    this.achatComprime = 0.0,
    required this.venteCarton,
    required this.venteBoite,
    required this.ventePlaquette,
    required this.venteComprime,
    this.margePct,
    required this.beneficeEstime,
    required this.seuilAlerte,
    this.seuilNiveau = 'comprimes',
    this.emplacement,
    required this.alertePeremption,
    this.alerteJours,
    required this.ordonnance,
    required this.createdAt,
    required this.updatedAt,
    this.expireBientot = false,
    this.stockFaible = false,
    this.enRupture = false,
    this.stockActuel = 0.0,
  });

  factory MedicinePricing.fromJson(Map<String, dynamic> json) {
    return MedicinePricing(
      id: json['id'] as int,
      medicineId: json['medicine_id'] as int?,
      nom: json['nom'] as String,
      dci: json['dci'] as String?,
      forme: json['forme'] as String?,
      dosage: json['dosage'] as String?,
      lot: json['lot'] as String,
      fournisseur: json['fournisseur'] as String?,
      bonLivraison: json['bon_livraison'] as String?,
      dateReception: json['date_reception'] != null
          ? DateTime.parse(json['date_reception'] as String)
          : null,
      datePeremption: json['date_peremption'] != null
          ? DateTime.parse(json['date_peremption'] as String)
          : null,
      nbCartons: json['nb_cartons'] as int,
      boitesParCarton: json['boites_par_carton'] as int,
      plaquettesParBoite: json['plaquettes_par_boite'] as int,
      comprimesParPlaquette: json['comprimes_par_plaquette'] as int,
      totalBoites: json['total_boites'] as int,
      totalPlaquettes: json['total_plaquettes'] as int,
      totalComprimes: json['total_comprimes'] as int,
      prixMode: json['prix_mode'] as String,
      achatCarton: (json['achat_carton'] as num).toDouble(),
      achatBoite: (json['achat_boite'] as num?)?.toDouble() ?? 0.0,
      achatPlaquette: (json['achat_plaquette'] as num?)?.toDouble() ?? 0.0,
      achatComprime: (json['achat_comprime'] as num?)?.toDouble() ?? 0.0,
      venteCarton: (json['vente_carton'] as num).toDouble(),
      venteBoite: (json['vente_boite'] as num).toDouble(),
      ventePlaquette: (json['vente_plaquette'] as num).toDouble(),
      venteComprime: (json['vente_comprime'] as num).toDouble(),
      margePct: json['marge_pct'] != null
          ? (json['marge_pct'] as num).toDouble()
          : null,
      beneficeEstime: (json['benefice_estime'] as num).toDouble(),
      seuilAlerte: json['seuil_alerte'] as int,
      seuilNiveau: json['seuil_niveau'] as String? ?? 'comprimes',
      emplacement: json['emplacement'] as String?,
      alertePeremption: json['alerte_peremption'] as bool,
      alerteJours: json['alerte_jours'] as int?,
      ordonnance: json['ordonnance'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      expireBientot: json['expire_bientot'] as bool? ?? false,
      stockFaible: json['stock_faible'] as bool? ?? false,
      enRupture: json['en_rupture'] as bool? ?? (json['stock_actuel'] != null ? ((json['stock_actuel'] as num) <= 0) : ((json['total_comprimes'] as int? ?? 0) <= 0)),
      stockActuel: (json['stock_actuel'] as num?)?.toDouble() ?? ((json['total_comprimes'] as int? ?? 0).toDouble()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nom': nom,
      'dci': dci,
      'forme': forme,
      'dosage': dosage,
      'lot': lot,
      'fournisseur': fournisseur,
      'bon_livraison': bonLivraison,
      'date_reception': dateReception?.toIso8601String().split('T').first,
      'date_peremption': datePeremption?.toIso8601String().split('T').first,
      'nb_cartons': nbCartons,
      'boites_par_carton': boitesParCarton,
      'plaquettes_par_boite': plaquettesParBoite,
      'comprimes_par_plaquette': comprimesParPlaquette,
      'prix_mode': prixMode,
      'achat_carton': achatCarton,
      'achat_boite': achatBoite,
      'achat_plaquette': achatPlaquette,
      'achat_comprime': achatComprime,
      'vente_carton': venteCarton,
      'vente_boite': venteBoite,
      'vente_plaquette': ventePlaquette,
      'vente_comprime': venteComprime,
      'marge_pct': margePct,
      'seuil_alerte': seuilAlerte,
      'seuil_niveau': seuilNiveau,
      'emplacement': emplacement,
      'alerte_peremption': alertePeremption,
      'alerte_jours': alerteJours,
      'ordonnance': ordonnance,
    };
  }
}

/// Réponse paginée des entrées de prix
class PricingResponse {
  final List<MedicinePricing> items;
  final int total;
  final int totalPages;

  PricingResponse({
    required this.items,
    required this.total,
    required this.totalPages,
  });

  factory PricingResponse.fromJson(Map<String, dynamic> json) {
    return PricingResponse(
      items: (json['items'] as List)
          .map((item) => MedicinePricing.fromJson(item as Map<String, dynamic>))
          .toList(),
      total: json['total'] as int,
      totalPages: json['total_pages'] as int,
    );
  }
}
