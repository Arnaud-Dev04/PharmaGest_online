import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'dart:async';
import 'package:frontend1/core/theme.dart';
import 'package:frontend1/models/medicine_pricing.dart';
import 'package:frontend1/models/medicine.dart';
import 'package:frontend1/services/medicine_pricing_service.dart';
import 'package:frontend1/core/error_helper.dart';

// ============================================================================
// WIZARD D'AJOUT DE MÉDICAMENT — v2.0
// 4 étapes : Identification → Conditionnement → Prix → Stock
// Nouveautés : sélection depuis liste, format date FR, prix par conditionnement
// ============================================================================

class AddMedicineWizard extends StatefulWidget {
  final MedicinePricing? existing;
  final Medicine? existingMedicine;
  final bool forceNewLot;
  const AddMedicineWizard({super.key, this.existing, this.existingMedicine, this.forceNewLot = false});

  @override
  State<AddMedicineWizard> createState() => _AddMedicineWizardState();
}

class _AddMedicineWizardState extends State<AddMedicineWizard>
    with TickerProviderStateMixin {
  final _pageController = PageController();
  final _service        = MedicinePricingService();
  int?  _existingPricingId;

  int  _currentStep  = 0;
  bool _isSubmitting = false;

  final _step1Key = GlobalKey<FormState>();
  final _step2Key = GlobalKey<FormState>();
  final _step3Key = GlobalKey<FormState>();
  final _step4Key = GlobalKey<FormState>();

  // ── Étape 1 ───────────────────────────────────────────────────────────────
  final _nomCtrl          = TextEditingController();
  final _dciCtrl          = TextEditingController();
  final _formeCtrl        = TextEditingController();
  final _dosageCtrl       = TextEditingController();
  final _lotCtrl          = TextEditingController(text: 'LOT-001');
  final _fournisseurCtrl  = TextEditingController();
  final _bonLivCtrl       = TextEditingController();
  DateTime? _dateReception;
  DateTime? _datePeremption;
  String _ordonnance = OrdonnanceType.non.value;

  // ── Étape 2 ───────────────────────────────────────────────────────────────
  final _nbCartonsCtrl = TextEditingController(text: '1');
  final _bpcCtrl       = TextEditingController(text: '1');
  final _ppbCtrl       = TextEditingController(text: '1');
  final _cppCtrl       = TextEditingController(text: '1');

  // ── Étape 3 — Prix par niveau ────────────────────────────────────────────
  /// Niveau de saisie du prix : 'carton' | 'boite' | 'plaquette' | 'comprime'
  String _achatNiveau = 'carton';
  String _venteNiveau = 'carton';
  final _achatSaisieCtrl  = TextEditingController();
  final _venteSaisieCtrl  = TextEditingController();
  final _margePctCtrl     = TextEditingController(text: '20');
  PricingMode _pricingMode = PricingMode.pctMarge;

  // ── Étape 4 ───────────────────────────────────────────────────────────────
  final _seuilAlerteCtrl = TextEditingController(text: '10');
  final _emplacementCtrl = TextEditingController();
  final _alerteJoursCtrl = TextEditingController(text: '30');
  bool _alertePeremption = true;

  // ── Suggestions locales ──────────────────────────────────────────────────
  static const _dciBase = [
    'Paracétamol','Amoxicilline','Amoxicilline + Acide clavulanique',
    'Ibuprofène','Diclofénac','Oméprazole','Métronidazole',
    'Ciprofloxacine','Azithromycine','Doxycycline','Céfixime','Céftriaxone',
    'Cotrimoxazole','Érythromycine','Gentamicine','Métformine','Glibenclamide',
    'Amlodipine','Captopril','Enalapril','Losartan','Atenolol','Furosémide',
    'Hydrochlorothiazide','Salbutamol','Prednisolone','Dexaméthasone',
    'Hydrocortisone','Fer + Acide folique','Acide folique','Vitamine C',
    'Vitamine B complexe','Albendazole','Mébendazole',
    'Artéméther + Luméfantrine','Quinine','Chloroquine','Artésunate',
    'Tramadol','Codéine','Morphine','Diazépam','Phénobarbital',
    'Carbamazépine','Insuline','Nifédipine','Ranitidine','Lopéramide',
    'ORS (SRO)','Rifampicine','Isoniazide','Pyrazinamide','Éthambutol',
    'Fluconazole',
  ];
  static const _formesBase = [
    'Comprimé','Comprimé pelliculé','Comprimé effervescent',
    'Comprimé orodispersible','Gélule','Capsule molle',
    'Sirop','Suspension buvable','Solution buvable',
    'Solution injectable','Poudre pour injection',
    'Pommade','Crème','Gel','Lotion','Collyre','Gouttes auriculaires',
    'Suppositoire','Ovule','Patch transdermique','Sachet','Spray nasal','Aérosol',
  ];
  static const _dosagesBase = [
    '100mg','125mg','200mg','250mg','400mg','500mg','1g','2g',
    '50mg','75mg','150mg','300mg','600mg','800mg',
    '5mg','10mg','20mg','25mg','40mg','80mg',
    '125mg/5ml','250mg/5ml','100mg/5ml','200mg/5ml',
    '1%','2%','5%','0.5%','0.1%',
  ];

  // ── Getters conditionnement ───────────────────────────────────────────────
  int get _nbCartons => int.tryParse(_nbCartonsCtrl.text) ?? 1;
  int get _bpc       => int.tryParse(_bpcCtrl.text) ?? 1;
  int get _ppb       => int.tryParse(_ppbCtrl.text) ?? 1;
  int get _cpp       => int.tryParse(_cppCtrl.text) ?? 1;

  int get _totalBoites     => _nbCartons * _bpc;
  int get _totalPlaquettes => _totalBoites * _ppb;
  int get _totalComprimes  => _totalPlaquettes * _cpp;

  // ── Facteurs de conversion → carton ─────────────────────────────────────
  double _facteurCarton(String niveau) {
    switch (niveau) {
      case 'boite':     return _bpc.toDouble();
      case 'plaquette': return (_bpc * _ppb).toDouble();
      case 'comprime':  return (_bpc * _ppb * _cpp).toDouble();
      default:          return 1.0; // carton
    }
  }

  double get _achatCarton {
    final v = double.tryParse(_achatSaisieCtrl.text) ?? 0;
    return v * _facteurCarton(_achatNiveau);
  }
  double get _marge => double.tryParse(_margePctCtrl.text) ?? 0;

  double get _venteCarton {
    if (_pricingMode == PricingMode.pctMarge) {
      return _achatCarton * (1 + _marge / 100);
    }
    final v = double.tryParse(_venteSaisieCtrl.text) ?? 0;
    return v * _facteurCarton(_venteNiveau);
  }

  double get _beneficeEstime => (_venteCarton - _achatCarton) * _nbCartons;

  // Label du niveau sélectionné
  String _niveauLabel(String n) {
    switch (n) {
      case 'boite':     return 'Boîte';
      case 'plaquette': return 'Plaquette';
      case 'comprime':  return 'Comprimé';
      default:          return 'Carton';
    }
  }

  // Prix par unité selon niveau (pour l'affichage)
  double _prixAuNiveau(double prixCarton, String niveau) {
    final f = _facteurCarton(niveau);
    return f > 0 ? prixCarton / f : 0;
  }

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _existingPricingId = widget.existing!.id;
      _prefill(widget.existing!);
    } else if (widget.existingMedicine != null) {
      _prefillFromMedicine(widget.existingMedicine!);
      _lookupExistingPricing(widget.existingMedicine!);
    }
    for (final c in [
      _achatSaisieCtrl, _venteSaisieCtrl, _margePctCtrl,
      _nbCartonsCtrl, _bpcCtrl, _ppbCtrl, _cppCtrl,
    ]) {
      c.addListener(() => setState(() {}));
    }
    // Auto-prefill: when the user types a name that matches exactly an existing
    // pricing entry, we prefill identification fields. Debounced to avoid API spam.
    _nomCtrl.addListener(_onNameChanged);
  }

  Timer? _nameDebounce;

  void _onNameChanged() {
    _nameDebounce?.cancel();
    _nameDebounce = Timer(const Duration(milliseconds: 700), () async {
      final name = _nomCtrl.text.trim();
      if (name.isEmpty) return;
      try {
        final r = await _service.getPricings(pageSize: 1, search: name);
        if (r.items.isNotEmpty) {
          final first = r.items.first;
          if (first.nom.trim().toLowerCase() == name.toLowerCase()) {
            _prefillFromExisting(first);
          }
        }
      } catch (_) {
        // ignore errors — non blocking
      }
    });
  }

  void _prefill(MedicinePricing e) {
    _nomCtrl.text          = e.nom;
    _dciCtrl.text          = e.dci ?? '';
    _formeCtrl.text        = e.forme ?? '';
    _dosageCtrl.text       = e.dosage ?? '';
    _lotCtrl.text          = e.lot;
    _fournisseurCtrl.text  = e.fournisseur ?? '';
    _bonLivCtrl.text       = e.bonLivraison ?? '';
    _dateReception         = e.dateReception;
    _datePeremption        = e.datePeremption;
    _ordonnance            = e.ordonnance;
    _nbCartonsCtrl.text    = e.nbCartons.toString();
    _bpcCtrl.text          = e.boitesParCarton.toString();
    _ppbCtrl.text          = e.plaquettesParBoite.toString();
    _cppCtrl.text          = e.comprimesParPlaquette.toString();
    _achatSaisieCtrl.text  = e.achatCarton.toStringAsFixed(0);
    _achatNiveau           = 'carton';
    _venteSaisieCtrl.text  = e.venteCarton.toStringAsFixed(0);
    _venteNiveau           = 'carton';
    _margePctCtrl.text     = (e.margePct ?? 20).toStringAsFixed(0);
    _pricingMode           = PricingMode.fromString(e.prixMode);
    _seuilAlerteCtrl.text  = e.seuilAlerte.toString();
    _emplacementCtrl.text  = e.emplacement ?? '';
    _alertePeremption      = e.alertePeremption;
    _alerteJoursCtrl.text  = (e.alerteJours ?? 30).toString();
    // If caller requested a forced new lot, clear the lot field so user must provide one
    if (widget.forceNewLot) _lotCtrl.text = '';
  }

  /// Préremplit les informations depuis un médicament existant :
  /// toutes les infos sont conservées SAUF Date d'expiration, Conditionnement, Date de réception et Lot
  void _prefillFromExisting(MedicinePricing e) {
    setState(() {
      // ── Identification (conservée) ──
      _nomCtrl.text         = e.nom;
      _dciCtrl.text         = e.dci ?? '';
      _formeCtrl.text       = e.forme ?? '';
      _dosageCtrl.text      = e.dosage ?? '';
      _fournisseurCtrl.text = e.fournisseur ?? '';
      _ordonnance           = e.ordonnance;
      _bonLivCtrl.text      = '';

      // ── SAUF : Lot, Date de réception, Date d'expiration ──
      _lotCtrl.text         = '';
      _dateReception        = null;
      _datePeremption       = null;

      // ── SAUF : Conditionnement (réinitialisé) ──
      _nbCartonsCtrl.text   = '1';
      _bpcCtrl.text         = '1';
      _ppbCtrl.text         = '1';
      _cppCtrl.text         = '1';

      // ── Tarification (conservée) ──
      if (e.achatCarton > 0) {
        _achatSaisieCtrl.text = e.achatCarton.toStringAsFixed(0);
        _achatNiveau          = 'carton';
      } else if (e.achatBoite > 0) {
        _achatSaisieCtrl.text = e.achatBoite.toStringAsFixed(0);
        _achatNiveau          = 'boite';
      } else if (e.achatComprime > 0) {
        _achatSaisieCtrl.text = e.achatComprime.toStringAsFixed(0);
        _achatNiveau          = 'comprime';
      } else {
        _achatSaisieCtrl.text = e.achatCarton.toStringAsFixed(0);
        _achatNiveau          = 'carton';
      }

      if (e.venteCarton > 0) {
        _venteSaisieCtrl.text = e.venteCarton.toStringAsFixed(0);
        _venteNiveau          = 'carton';
      } else if (e.venteBoite > 0) {
        _venteSaisieCtrl.text = e.venteBoite.toStringAsFixed(0);
        _venteNiveau          = 'boite';
      } else if (e.venteComprime > 0) {
        _venteSaisieCtrl.text = e.venteComprime.toStringAsFixed(0);
        _venteNiveau          = 'comprime';
      } else {
        _venteSaisieCtrl.text = e.venteCarton.toStringAsFixed(0);
        _venteNiveau          = 'carton';
      }

      _margePctCtrl.text    = (e.margePct ?? 20).toStringAsFixed(0);
      _pricingMode          = PricingMode.fromString(e.prixMode);

      // ── Stock & Alertes (conservée) ──
      _seuilAlerteCtrl.text = e.seuilAlerte.toString();
      _emplacementCtrl.text = e.emplacement ?? '';
      _alertePeremption     = e.alertePeremption;
      _alerteJoursCtrl.text = (e.alerteJours ?? 30).toString();
    });
  }

  Future<void> _lookupExistingPricing(Medicine m) async {
    try {
      final res = await _service.getPricings(search: m.name, pageSize: 20);
      final match = res.items.where((p) =>
          p.medicineId == m.id ||
          p.nom.trim().toLowerCase() == m.name.trim().toLowerCase()).toList();
      if (match.isNotEmpty && mounted) {
        setState(() {
          _existingPricingId = match.first.id;
          _prefill(match.first);
        });
      }
    } catch (_) {}
  }

  void _prefillFromMedicine(Medicine m) {
    setState(() {
      _nomCtrl.text          = m.name;
      _dciCtrl.text          = m.dci ?? '';
      _formeCtrl.text        = m.formeGalenique ?? m.dosageForm ?? '';
      _lotCtrl.text          = 'LOT-001';
      _fournisseurCtrl.text  = m.fournisseur ?? '';
      _bonLivCtrl.text       = '';
      _dateReception         = null;
      _datePeremption        = m.expiryDate;
      _ordonnance            = OrdonnanceType.non.value;
      
      final bpc = m.boxesPerCarton > 0 ? m.boxesPerCarton : 1;
      final ppb = m.blistersPerBox > 0 ? m.blistersPerBox : 1;
      final cpp = m.unitsPerBlister > 0 ? m.unitsPerBlister : 1;
      final unitsPerCarton = bpc * ppb * cpp;
      final cartons = unitsPerCarton > 0 ? (m.quantity / unitsPerCarton).ceil() : 1;

      _nbCartonsCtrl.text    = (cartons > 0 ? cartons : 1).toString();
      _bpcCtrl.text          = bpc.toString();
      _ppbCtrl.text          = ppb.toString();
      _cppCtrl.text          = cpp.toString();
      
      double achatC = m.prixAchatCarton > 0 ? m.prixAchatCarton : (m.priceBuy * bpc);
      double venteC = m.prixVenteCarton > 0 ? m.prixVenteCarton : (m.priceSell * bpc);
      
      _achatSaisieCtrl.text  = achatC.toStringAsFixed(0);
      _achatNiveau           = 'carton';
      _venteSaisieCtrl.text  = venteC.toStringAsFixed(0);
      _venteNiveau           = 'carton';
      
      _pricingMode           = PricingMode.cartonFixe;
      _margePctCtrl.text     = '20';
      _seuilAlerteCtrl.text  = m.minStockAlert.toString();
      _alertePeremption      = m.expiryAlertThreshold > 0;
      _alerteJoursCtrl.text  = (m.expiryAlertThreshold > 0 ? m.expiryAlertThreshold : 30).toString();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameDebounce?.cancel();
    for (final c in [
      _nomCtrl, _dciCtrl, _formeCtrl, _dosageCtrl, _lotCtrl,
      _fournisseurCtrl, _bonLivCtrl,
      _nbCartonsCtrl, _bpcCtrl, _ppbCtrl, _cppCtrl,
      _achatSaisieCtrl, _venteSaisieCtrl, _margePctCtrl,
      _seuilAlerteCtrl, _emplacementCtrl, _alerteJoursCtrl,
    ]) { c.dispose(); }
    super.dispose();
  }

  // ── Navigation ────────────────────────────────────────────────────────────
  Future<void> _next() async {
    final keys = [_step1Key, _step2Key, _step3Key, _step4Key];
    if (!(keys[_currentStep].currentState?.validate() ?? false)) return;
    if (_currentStep == 3) { await _submit(); return; }
    setState(() => _currentStep++);
    _pageController.animateToPage(_currentStep,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeInOutCubic);
  }

  void _prev() {
    if (_currentStep == 0) { Navigator.of(context).pop(false); return; }
    setState(() => _currentStep--);
    _pageController.animateToPage(_currentStep,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeInOutCubic);
  }


  // ── Soumission ────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (_achatCarton <= 0) {
      _gotoStep(2, '⚠️ Veuillez saisir un prix d\'achat > 0');
      return;
    }
    if (_pricingMode == PricingMode.pctMarge && _marge == 0) {
      _gotoStep(2, '⚠️ La marge est à 0% — le prix de vente sera égal au prix d\'achat');
      // Ne pas bloquer, juste avertir (retour retiré pour permettre la sauvegarde)
    }
    if (_pricingMode == PricingMode.pctMarge && _marge < 0) {
      // Marge négative = perte, on autorise mais on avertit
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('⚠️ Attention : Prix de vente inférieur au prix d\'achat (perte)'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 3),
      ));
    }
    if (_pricingMode == PricingMode.cartonFixe && _venteCarton <= 0) {
      _gotoStep(2, '⚠️ Veuillez saisir un prix de vente > 0');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final vc = _venteCarton;
      final vb = _bpc > 0 ? vc / _bpc : 0.0;
      final vp = _ppb > 0 ? vb / _ppb : 0.0;
      final vco = _cpp > 0 ? vp / _cpp : 0.0;
      final ac = _achatCarton;
      final ab = _bpc > 0 ? ac / _bpc : 0.0;
      final ap = _ppb > 0 ? ab / _ppb : 0.0;
      final aco = _cpp > 0 ? ap / _cpp : 0.0;

      final payload = <String, dynamic>{
        'nom': _nomCtrl.text.trim(),
        'dci': _dciCtrl.text.trim().isNotEmpty ? _dciCtrl.text.trim() : null,
        'forme': _formeCtrl.text.trim().isNotEmpty ? _formeCtrl.text.trim() : null,
        'dosage': _dosageCtrl.text.trim().isNotEmpty ? _dosageCtrl.text.trim() : null,
        'lot': _lotCtrl.text.trim().isNotEmpty ? _lotCtrl.text.trim() : 'LOT-001',
        'fournisseur': _fournisseurCtrl.text.trim().isNotEmpty ? _fournisseurCtrl.text.trim() : null,
        'bon_livraison': _bonLivCtrl.text.trim().isNotEmpty ? _bonLivCtrl.text.trim() : null,
        'date_reception': _dateReception?.toIso8601String().split('T').first,
        'date_peremption': _datePeremption?.toIso8601String().split('T').first,
        'ordonnance': _ordonnance,
        'nb_cartons': _nbCartons,
        'boites_par_carton': _bpc,
        'plaquettes_par_boite': _ppb,
        'comprimes_par_plaquette': _cpp,
        'prix_mode': _pricingMode.value,
        'achat_carton': ac,
        'achat_boite': ab,
        'achat_plaquette': ap,
        'achat_comprime': aco,
        'vente_carton': vc,
        'vente_boite': vb,
        'vente_plaquette': vp,
        'vente_comprime': vco,
        'marge_pct': _marge,
        'seuil_alerte': int.tryParse(_seuilAlerteCtrl.text) ?? 10,
        'emplacement': _emplacementCtrl.text.trim().isNotEmpty ? _emplacementCtrl.text.trim() : null,
        'alerte_peremption': _alertePeremption,
        'alerte_jours': int.tryParse(_alerteJoursCtrl.text) ?? 30,
      };

      final updateId = widget.existing?.id ?? _existingPricingId;
      if (updateId != null) {
        await _service.updatePricing(updateId, payload);
      } else {
        if (widget.existingMedicine != null) {
          payload['medicine_id'] = widget.existingMedicine!.id;
        }
        await _service.createPricing(payload);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(ErrorHelper.extractErrorMessage(e),
                maxLines: 3, overflow: TextOverflow.ellipsis)),
          ]),
          backgroundColor: AppTheme.dangerColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 6),
        ));
      }
    }
  }

  void _gotoStep(int step, String msg) {
    setState(() => _currentStep = step);
    _pageController.animateToPage(step,
        duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppTheme.warningColor,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // ── Dialogue de recherche de médicament existant ──────────────────────────
  Future<void> _openMedicinePicker() async {
    final result = await showDialog<dynamic>(
      context: context,
      builder: (ctx) => _MedicinePickerDialog(service: _service),
    );
    if (result == null) return;
    if (result is MedicinePricing) {
      _prefillFromExisting(result);
    } else if (result is Map && result['existing'] != null) {
      final MedicinePricing existing = result['existing'] as MedicinePricing;
      _prefillFromExisting(existing);
      if (result['forceNewLot'] == true) {
        // Clear lot so user must supply a new one
        setState(() => _lotCtrl.text = '');
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final card   = isDark ? AppTheme.darkCard : AppTheme.lightCard;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            width: 700,
            constraints: const BoxConstraints(maxHeight: 760),
            decoration: BoxDecoration(
              color: card.withValues(alpha: isDark ? 0.97 : 0.98),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2), width: 1.5),
              boxShadow: [BoxShadow(
                color: AppTheme.primaryColor.withValues(alpha: 0.15),
                blurRadius: 40, spreadRadius: -5,
              )],
            ),
            child: Column(children: [
              _buildHeader(isDark),
              _buildStepBar(isDark),
              Expanded(child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _StepIdent(
                    formKey: _step1Key,
                    nomCtrl: _nomCtrl, dciCtrl: _dciCtrl,
                    formeCtrl: _formeCtrl, dosageCtrl: _dosageCtrl,
                    lotCtrl: _lotCtrl, fournisseurCtrl: _fournisseurCtrl,
                    bonLivCtrl: _bonLivCtrl,
                    dateReception: _dateReception, datePeremption: _datePeremption,
                    onDateReception: (d) => setState(() => _dateReception = d),
                    onDatePeremption: (d) => setState(() => _datePeremption = d),
                    ordonnance: _ordonnance,
                    onOrdonnance: (v) => setState(() => _ordonnance = v),
                    dciList: _dciBase, formeList: _formesBase, dosageList: _dosagesBase,
                    onPickFromList: _openMedicinePicker,
                    isDark: isDark,
                  ),
                  _StepCond(
                    formKey: _step2Key,
                    nbCartonsCtrl: _nbCartonsCtrl, bpcCtrl: _bpcCtrl,
                    ppbCtrl: _ppbCtrl, cppCtrl: _cppCtrl,
                    totalBoites: _totalBoites, totalComprimes: _totalComprimes,
                    isDark: isDark,
                  ),
                  _StepPrix(
                    formKey: _step3Key,
                    achatCtrl: _achatSaisieCtrl,
                    venteCtrl: _venteSaisieCtrl,
                    margeCtrl: _margePctCtrl,
                    mode: _pricingMode,
                    onMode: (m) => setState(() => _pricingMode = m),
                    achatNiveau: _achatNiveau,
                    venteNiveau: _venteNiveau,
                    onAchatNiveau: (n) => setState(() => _achatNiveau = n),
                    onVenteNiveau: (n) => setState(() => _venteNiveau = n),
                    achatCarton: _achatCarton,
                    venteCarton: _venteCarton,
                    benefice: _beneficeEstime,
                    nbCartons: _nbCartons,
                    boitesParCarton: _bpc,
                    plaquettesParBoite: _ppb,
                    comprimesParPlaquette: _cpp,
                    totalBoites: _totalBoites,
                    totalPlaquettes: _totalPlaquettes,
                    totalComprimes: _totalComprimes,
                    niveauLabel: _niveauLabel,
                    prixAuNiveau: _prixAuNiveau,
                    isDark: isDark,
                  ),
                  _StepStock(
                    formKey: _step4Key,
                    seuilCtrl: _seuilAlerteCtrl,
                    emplacementCtrl: _emplacementCtrl,
                    joursCtrl: _alerteJoursCtrl,
                    alertePeremption: _alertePeremption,
                    onAlerte: (v) => setState(() => _alertePeremption = v),
                    totalComprimes: _totalComprimes,
                    benefice: _beneficeEstime,
                    nom: _nomCtrl.text,
                    isDark: isDark,
                  ),
                ],
              )),
              _buildFooter(isDark),
            ]),
          ),
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader(bool isDark) {
    const titles = ['🏷️  Identification','📦  Conditionnement','💰  Tarification','🏪  Stock & Alertes'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 22, 16, 0),
      child: Row(children: [
        Container(width: 44, height: 44,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              AppTheme.primaryColor, AppTheme.primaryColor.withValues(alpha: 0.7)],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.medication_rounded, color: Colors.white, size: 24)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.existing != null ? 'Modifier le médicament' : 'Nouveau médicament',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
              color: isDark ? AppTheme.darkForeground : AppTheme.lightForeground)),
          Text('Étape ${_currentStep + 1}/4 · ${titles[_currentStep]}',
            style: const TextStyle(fontSize: 13, color: AppTheme.primaryColor,
              fontWeight: FontWeight.w500)),
        ])),
        IconButton(
          icon: Icon(Icons.close_rounded,
            color: isDark ? AppTheme.darkForeground.withValues(alpha: 0.4) : Colors.grey[400]),
          onPressed: () => Navigator.of(context).pop(false)),
      ]),
    );
  }

  // ── Step bar ──────────────────────────────────────────────────────────────
  Widget _buildStepBar(bool isDark) {
    const labels = ['Infos', 'Cond.', 'Prix', 'Stock'];
    const icons  = [Icons.info_outline_rounded, Icons.inventory_2_outlined,
                    Icons.attach_money_rounded, Icons.store_outlined];
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 6),
      child: Column(children: [
        Row(children: List.generate(labels.length, (i) {
          final done = i < _currentStep; final active = i == _currentStep;
          return Expanded(child: Row(children: [
            Expanded(child: GestureDetector(
              onTap: done ? () {
                setState(() => _currentStep = i);
                _pageController.animateToPage(i,
                    duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
              } : null,
              child: Column(children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 280),
                  width: 42, height: 42,
                  decoration: BoxDecoration(shape: BoxShape.circle,
                    gradient: (active || done) ? LinearGradient(
                      colors: done
                        ? [AppTheme.successColor, AppTheme.successColor.withValues(alpha: 0.8)]
                        : [AppTheme.primaryColor, AppTheme.primaryColor.withValues(alpha: 0.7)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight) : null,
                    color: (active || done) ? null
                        : (isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
                    boxShadow: active ? [BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.4),
                      blurRadius: 12, spreadRadius: 2)] : null),
                  child: Icon(done ? Icons.check_rounded : icons[i],
                    color: (active || done) ? Colors.white
                        : (isDark ? AppTheme.darkForeground.withValues(alpha: 0.35) : Colors.grey[400]),
                    size: 20)),
                const SizedBox(height: 5),
                Text(labels[i], style: TextStyle(fontSize: 11,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                  color: active ? AppTheme.primaryColor
                      : done ? AppTheme.successColor
                      : (isDark ? AppTheme.darkForeground.withValues(alpha: 0.35) : Colors.grey[400]))),
              ]),
            )),
            if (i < labels.length - 1)
              Expanded(child: AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                height: 2, margin: const EdgeInsets.only(bottom: 22),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(1),
                  color: i < _currentStep ? AppTheme.successColor
                      : (isDark ? AppTheme.darkBorder : AppTheme.lightBorder)))),
          ]));
        })),
        const SizedBox(height: 6),
        ClipRRect(borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (_currentStep + 1) / 4,
            backgroundColor: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
            valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
            minHeight: 3)),
      ]),
    );
  }

  // ── Footer ────────────────────────────────────────────────────────────────
  Widget _buildFooter(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 22),
      decoration: BoxDecoration(border: Border(top: BorderSide(
        color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder, width: 1))),
      child: Row(children: [
        TextButton.icon(
          onPressed: _isSubmitting ? null : _prev,
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 15),
          label: Text(_currentStep == 0 ? 'Annuler' : 'Retour'),
          style: TextButton.styleFrom(
            foregroundColor: isDark
                ? AppTheme.darkForeground.withValues(alpha: 0.6) : Colors.grey[500],
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12))),
        const Spacer(),
        Text('${_currentStep + 1} / 4',
          style: TextStyle(fontSize: 12,
            color: isDark ? AppTheme.darkForeground.withValues(alpha: 0.35) : Colors.grey[400])),
        const SizedBox(width: 16),
        ElevatedButton.icon(
          onPressed: _isSubmitting ? null : _next,
          icon: _isSubmitting
              ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Icon(_currentStep == 3
                  ? Icons.check_circle_rounded : Icons.arrow_forward_ios_rounded, size: 16),
          label: Text(
            _isSubmitting ? 'Enregistrement…'
                : _currentStep == 3 ? 'Enregistrer' : 'Suivant',
            style: const TextStyle(fontWeight: FontWeight.w600)),
          style: ElevatedButton.styleFrom(
            backgroundColor: _currentStep == 3 ? AppTheme.successColor : AppTheme.primaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0)),
      ]),
    );
  }
}

// ============================================================================
// DIALOGUE DE RECHERCHE DE MÉDICAMENT EXISTANT
// ============================================================================
// DIALOGUE DE RECHERCHE DE MÉDICAMENT EN RUPTURE DE STOCK
// ============================================================================
// DIALOGUE DE SÉLECTION DE MÉDICAMENT EXISTANT (AVEC SIGNALEMENT RUPTURE)
// ============================================================================
class _MedicinePickerDialog extends StatefulWidget {
  final MedicinePricingService service;
  const _MedicinePickerDialog({required this.service});
  @override State<_MedicinePickerDialog> createState() => _MedicinePickerDialogState();
}
class _MedicinePickerDialogState extends State<_MedicinePickerDialog> {
  final _searchCtrl = TextEditingController();
  List<MedicinePricing> _results = [];
  bool _loading = false;
  String? _error;
  bool _showOnlyRupture = false;
  final Map<int, int> _medicineQuantities = {};

  @override
  void initState() {
    super.initState();
    _search('');
    _searchCtrl.addListener(() => _search(_searchCtrl.text));
  }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  Future<void> _search(String q) async {
    setState(() { _loading = true; _error = null; });
    try {
      final r = await widget.service.getPricings(
        pageSize: 100,
        search: q.trim().isNotEmpty ? q.trim() : null,
      );
      if (mounted) setState(() { _results = r.items; _loading = false; });
      // Prefetch quantities for items linked to medicines if needed
      for (final it in _results) {
        if (it.medicineId != null && !_medicineQuantities.containsKey(it.medicineId)) {
          _fetchMedicineQuantity(it.medicineId!);
        }
      }
    } catch (e) {
      if (mounted) setState(() { _error = ErrorHelper.extractErrorMessage(e); _loading = false; });
    }
  }

  Future<void> _fetchMedicineQuantity(int medicineId) async {
    try {
      final data = await widget.service.getMedicineById(medicineId);
      if (data != null && mounted) {
        setState(() { _medicineQuantities[medicineId] = (data['quantity'] ?? 0) as int; });
      }
    } catch (_) {
      // ignore
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final card   = isDark ? AppTheme.darkCard : AppTheme.lightCard;
    // Déduplique par nom
    final seen = <String>{};
    final unique = _results.where((e) => seen.add(e.nom.toLowerCase())).toList();

    // Calcul des médicaments en rupture
    final ruptureCount = unique.where((e) {
      final qty = (e.medicineId != null && _medicineQuantities.containsKey(e.medicineId))
          ? _medicineQuantities[e.medicineId]!
          : (e.stockActuel.toInt());
      return e.enRupture || qty <= 0 || e.totalComprimes <= 0;
    }).length;

    // Filtrage instantané en mémoire (zéro appel réseau = zéro latence et zéro erreur 422)
    final displayed = _showOnlyRupture
        ? unique.where((e) {
            final qty = (e.medicineId != null && _medicineQuantities.containsKey(e.medicineId))
                ? _medicineQuantities[e.medicineId]!
                : (e.stockActuel.toInt());
            return e.enRupture || qty <= 0 || e.totalComprimes <= 0;
          }).toList()
        : unique;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 600, height: 620,
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.25), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 25,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(children: [
          // En-tête
          Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 14, 14),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(
                color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                width: 1,
              )),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.inventory_2_outlined, color: AppTheme.primaryColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Sélectionner un médicament existant',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${displayed.length}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Réutilisez les informations pour une nouvelle commande ou livraison',
                    style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                  ),
                ],
              )),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ]),
          ),

          // Barre de recherche et filtres
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                TextField(
                  controller: _searchCtrl,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Rechercher par nom, DCI, forme…',
                    prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppTheme.primaryColor),
                    filled: true,
                    fillColor: isDark
                        ? AppTheme.darkBorder.withValues(alpha: 0.2)
                        : AppTheme.lightBorder.withValues(alpha: 0.3),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 8),
                // Filtre rapide instantané "Tous" vs "En rupture"
                Row(
                  children: [
                    FilterChip(
                      selected: !_showOnlyRupture,
                      label: Text('Tous (${unique.length})'),
                      selectedColor: AppTheme.primaryColor.withValues(alpha: 0.15),
                      checkmarkColor: AppTheme.primaryColor,
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: !_showOnlyRupture ? FontWeight.w700 : FontWeight.w500,
                        color: !_showOnlyRupture ? AppTheme.primaryColor : Colors.grey[600],
                      ),
                      onSelected: (_) {
                        setState(() => _showOnlyRupture = false);
                      },
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      selected: _showOnlyRupture,
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('En rupture uniquement'),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppTheme.dangerColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$ruptureCount',
                              style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      selectedColor: AppTheme.dangerColor.withValues(alpha: 0.15),
                      checkmarkColor: AppTheme.dangerColor,
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: _showOnlyRupture ? FontWeight.w700 : FontWeight.w500,
                        color: _showOnlyRupture ? AppTheme.dangerColor : Colors.grey[600],
                      ),
                      onSelected: (_) {
                        setState(() => _showOnlyRupture = true);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Liste des résultats
          Expanded(child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
              ? Center(child: Text('Erreur: $_error',
                  style: const TextStyle(color: AppTheme.dangerColor)))
              : displayed.isEmpty
                ? Center(child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.search_off_rounded, size: 40, color: Colors.grey[400]),
                      const SizedBox(height: 8),
                      Text(
                        _showOnlyRupture
                            ? 'Aucun médicament en rupture de stock !'
                            : 'Aucun médicament trouvé.',
                        style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                      ),
                    ]),
                  ))
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    itemCount: displayed.length,
                    separatorBuilder: (_, __) => Divider(height: 1,
                      color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
                    itemBuilder: (_, i) {
                      final e = displayed[i];
                      final qty = (e.medicineId != null && _medicineQuantities.containsKey(e.medicineId))
                          ? _medicineQuantities[e.medicineId]!
                          : (e.stockActuel.toInt());
                      final isRupture = e.enRupture || qty <= 0 || e.totalComprimes <= 0;


                      return InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          // Réapprovisionner ce médicament
                          Navigator.of(context).pop({'existing': e, 'forceNewLot': true});
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: isRupture
                                ? AppTheme.dangerColor.withValues(alpha: 0.04)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(children: [
                            Container(
                              width: 40, height: 40,
                              decoration: BoxDecoration(
                                color: isRupture
                                    ? AppTheme.dangerColor.withValues(alpha: 0.12)
                                    : AppTheme.primaryColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                isRupture ? Icons.warning_amber_rounded : Icons.medication_rounded,
                                size: 20,
                                color: isRupture ? AppTheme.dangerColor : AppTheme.primaryColor,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        e.nom,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: isDark ? AppTheme.darkForeground : AppTheme.lightForeground,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // BADGE ROUGE RUPTURE OU BADGE VERT EN STOCK
                                    if (isRupture)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppTheme.dangerColor,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.error_outline, size: 12, color: Colors.white),
                                            SizedBox(width: 4),
                                            Text(
                                              'RUPTURE',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w900,
                                                color: Colors.white,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    else
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppTheme.successColor.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: AppTheme.successColor.withValues(alpha: 0.3)),
                                        ),
                                        child: Text(
                                          'Stock: $qty',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.successColor,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                if (e.dci != null || e.forme != null || e.dosage != null)
                                  Text(
                                    [e.dci, e.forme, e.dosage]
                                        .whereType<String>().where((s) => s.isNotEmpty).join(' · '),
                                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                                  ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    if (isRupture)
                                      Text(
                                        'Stock disponible: 0 u.',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.dangerColor,
                                        ),
                                      )
                                    else
                                      Text(
                                        'En stock: $qty unités',
                                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                      ),
                                    if (e.venteComprime > 0) ...[
                                      const SizedBox(width: 12),
                                      Text(
                                        '${e.venteComprime.toStringAsFixed(0)} FBu/u',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? Colors.grey[400] : Colors.grey[700],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            )),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.of(context).pop({'existing': e, 'forceNewLot': true});
                              },
                              icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                              label: Text(
                                isRupture ? 'Réapprovisionner' : 'Sélectionner',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isRupture ? AppTheme.dangerColor : AppTheme.primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                elevation: 0,
                              ),
                            ),
                          ]),
                        ),
                      );
                    },
                ),
          ),
        ]),
      ),
    );
  }
}


// ============================================================================
// ÉTAPE 1 — IDENTIFICATION
// ============================================================================
class _StepIdent extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController nomCtrl, dciCtrl, formeCtrl, dosageCtrl;
  final TextEditingController lotCtrl, fournisseurCtrl, bonLivCtrl;
  final DateTime? dateReception, datePeremption;
  final ValueChanged<DateTime?> onDateReception, onDatePeremption;
  final String ordonnance;
  final ValueChanged<String> onOrdonnance;
  final List<String> dciList, formeList, dosageList;
  final VoidCallback onPickFromList;
  final bool isDark;

  const _StepIdent({
    required this.formKey,
    required this.nomCtrl, required this.dciCtrl,
    required this.formeCtrl, required this.dosageCtrl,
    required this.lotCtrl, required this.fournisseurCtrl,
    required this.bonLivCtrl,
    required this.dateReception, required this.datePeremption,
    required this.onDateReception, required this.onDatePeremption,
    required this.ordonnance, required this.onOrdonnance,
    required this.dciList, required this.formeList, required this.dosageList,
    required this.onPickFromList,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Form(key: formKey, child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Bouton de sélection depuis la liste ────────────────────────────
        GestureDetector(
          onTap: onPickFromList,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                AppTheme.primaryColor.withValues(alpha: 0.1),
                AppTheme.primaryColor.withValues(alpha: 0.04),
              ]),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.primaryColor.withValues(alpha: 0.35),
                width: 1.5,
              ),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.list_alt_rounded,
                  color: AppTheme.primaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text(
                    'Sélectionner depuis la liste',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Réutiliser les infos d\'un médicament existant (les ruptures sont signalées)',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ]),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: AppTheme.primaryColor,
              ),
            ]),
          ),
        ),

        const SizedBox(height: 14),
        // ── Séparateur ────────────────────────────────────────────────────
        Row(children: [
          Expanded(child: Divider(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder)),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text('ou saisir manuellement',
              style: TextStyle(fontSize: 11,
                color: isDark ? AppTheme.darkForeground.withValues(alpha: 0.35) : Colors.grey[400]))),
          Expanded(child: Divider(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder)),
        ]),
        const SizedBox(height: 14),
        // ── Champs ────────────────────────────────────────────────────────
        _Field(label: 'Nom commercial *', ctrl: nomCtrl,
          hint: 'Ex: Doliprane 500mg', icon: Icons.medication_rounded, isDark: isDark,
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Champ obligatoire' : null),
        const SizedBox(height: 12),
        _AutoField(label: 'DCI (Principe actif)', ctrl: dciCtrl,
          hint: 'Ex: Paracétamol', icon: Icons.science_outlined,
          suggestions: dciList, isDark: isDark),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(flex: 2, child: _AutoField(label: 'Forme galénique', ctrl: formeCtrl,
            hint: 'Ex: Comprimé', icon: Icons.category_outlined,
            suggestions: formeList, isDark: isDark)),
          const SizedBox(width: 10),
          Expanded(child: _AutoField(label: 'Dosage', ctrl: dosageCtrl,
            hint: 'Ex: 500mg', icon: Icons.tune_rounded,
            suggestions: dosageList, isDark: isDark)),
        ]),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark
                ? AppTheme.darkBorder.withValues(alpha: 0.16)
                : AppTheme.primaryColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? AppTheme.primaryColor.withValues(alpha: 0.25)
                  : AppTheme.primaryColor.withValues(alpha: 0.3),
              width: 1.3,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.calendar_month_outlined,
                      size: 18, color: AppTheme.primaryColor),
                ),
                const SizedBox(width: 10),
                Text('Dates', style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppTheme.primaryColor,
                )),
              ]),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: _Field(label: 'N° de lot', ctrl: lotCtrl,
                  hint: 'LOT-001', icon: Icons.qr_code_rounded, isDark: isDark)),
                const SizedBox(width: 10),
                Expanded(child: _Field(label: 'Fournisseur', ctrl: fournisseurCtrl,
                  hint: 'Nom du fournisseur', icon: Icons.local_shipping_outlined, isDark: isDark)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _Field(label: 'Bon de livraison', ctrl: bonLivCtrl,
                  hint: 'N° BL', icon: Icons.receipt_long_outlined, isDark: isDark)),
                const SizedBox(width: 10),
                Expanded(child: _DateField(
                  label: 'Date de réception', date: dateReception,
                  onPicked: onDateReception, isDark: isDark,
                  firstDate: DateTime(2020), lastDate: DateTime.now())),
              ]),
              const SizedBox(height: 12),
              _DateField(
                label: 'Date de péremption *', date: datePeremption,
                onPicked: onDatePeremption, isDark: isDark,
                firstDate: DateTime.now().add(const Duration(days: 1)),
                lastDate: DateTime(2040),
                isRequired: true),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _SecTitle('Type d\'ordonnance', isDark),
        const SizedBox(height: 8),
        _OrdonnanceSelector(current: ordonnance, onChanged: onOrdonnance, isDark: isDark),
      ]),
    ));
  }
}

// ============================================================================
// ÉTAPE 2 — CONDITIONNEMENT
// ============================================================================
class _StepCond extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController nbCartonsCtrl, bpcCtrl, ppbCtrl, cppCtrl;
  final int totalBoites, totalComprimes;
  final bool isDark;

  const _StepCond({
    required this.formKey,
    required this.nbCartonsCtrl, required this.bpcCtrl,
    required this.ppbCtrl, required this.cppCtrl,
    required this.totalBoites, required this.totalComprimes,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Form(key: formKey, child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 14),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.15))),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            for (final item in [
              ('📦','Carton',const Color(0xFF6366F1)),
              ('🗂️','Boîtes',AppTheme.primaryColor),
              ('💊','Plaquettes',AppTheme.warningColor),
              ('⚪','Unités',AppTheme.successColor),
            ]) ...[
              Column(children: [
                Text(item.$1, style: const TextStyle(fontSize: 22)),
                const SizedBox(height: 3),
                Text(item.$2, style: TextStyle(fontSize: 11,
                  fontWeight: FontWeight.w600, color: item.$3)),
              ]),
              if (item.$1 != '⚪')
                Icon(Icons.chevron_right_rounded, color: Colors.grey[400], size: 20),
            ],
          ]),
        ),
        const SizedBox(height: 18),
        _SecTitle('Quantités reçues', isDark),
        const SizedBox(height: 10),
        _CondRow(emoji:'📦', label:'Nombre de cartons', sub:'Cartons reçus',
          color:const Color(0xFF6366F1), ctrl:nbCartonsCtrl),
        const SizedBox(height: 10),
        _CondRow(emoji:'🗂️', label:'Boîtes par carton', sub:'Boîtes dans 1 carton',
          color:AppTheme.primaryColor, ctrl:bpcCtrl),
        const SizedBox(height: 10),
        _CondRow(emoji:'💊', label:'Plaquettes par boîte', sub:'Plaquettes dans 1 boîte',
          color:AppTheme.warningColor, ctrl:ppbCtrl),
        const SizedBox(height: 10),
        _CondRow(emoji:'⚪', label:'Unités par plaquette', sub:'Comprimés / gélules…',
          color:AppTheme.successColor, ctrl:cppCtrl),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              AppTheme.successColor.withValues(alpha: 0.1),
              AppTheme.primaryColor.withValues(alpha: 0.05)]),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.successColor.withValues(alpha: 0.3))),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _Metric('🗂️', totalBoites.toString(), 'Total boîtes', AppTheme.primaryColor),
            Container(width: 1, height: 36, color: AppTheme.successColor.withValues(alpha: 0.2)),
            _Metric('⚪', totalComprimes.toString(), 'Total unités', AppTheme.successColor),
          ]),
        ),
      ]),
    ));
  }
}

class _CondRow extends StatelessWidget {
  final String emoji, label, sub;
  final Color color;
  final TextEditingController ctrl;
  const _CondRow({required this.emoji, required this.label, required this.sub,
    required this.color, required this.ctrl});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: 0.2))),
    child: Row(children: [
      Text(emoji, style: const TextStyle(fontSize: 20)),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        Text(sub, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
      ])),
      _Stepper(ctrl: ctrl, color: color),
    ]),
  );
}

// ============================================================================
// ÉTAPE 3 — PRIX PAR NIVEAU
// ============================================================================
class _StepPrix extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController achatCtrl, venteCtrl, margeCtrl;
  final PricingMode mode;
  final ValueChanged<PricingMode> onMode;
  final String achatNiveau, venteNiveau;
  final ValueChanged<String> onAchatNiveau, onVenteNiveau;
  final double achatCarton, venteCarton, benefice;
  final int nbCartons;
  final int boitesParCarton, plaquettesParBoite, comprimesParPlaquette;
  final int totalBoites, totalPlaquettes, totalComprimes;
  final String Function(String) niveauLabel;
  final double Function(double, String) prixAuNiveau;
  final bool isDark;

  const _StepPrix({
    required this.formKey, required this.achatCtrl,
    required this.venteCtrl, required this.margeCtrl,
    required this.mode, required this.onMode,
    required this.achatNiveau, required this.venteNiveau,
    required this.onAchatNiveau, required this.onVenteNiveau,
    required this.achatCarton, required this.venteCarton,
    required this.benefice, required this.nbCartons,
    required this.boitesParCarton, required this.plaquettesParBoite,
    required this.comprimesParPlaquette,
    required this.totalBoites, required this.totalPlaquettes,
    required this.totalComprimes,
    required this.niveauLabel, required this.prixAuNiveau,
    required this.isDark,
  });

  static const _niveaux = ['carton', 'boite', 'plaquette', 'comprime'];
  static const _niveauEmojis = {'carton':'📦','boite':'🗂️','plaquette':'💊','comprime':'⚪'};

  Widget _niveauBtn(String n, String current, ValueChanged<String> onChanged) {
    final sel = n == current;
    return GestureDetector(
      onTap: () => onChanged(n),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: sel ? AppTheme.primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: sel ? AppTheme.primaryColor : Colors.grey.withValues(alpha: 0.3))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_niveauEmojis[n]!, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 2),
          Text(_cap(n), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
            color: sel ? Colors.white : Colors.grey[500])),
        ]),
      ),
    );
  }

  static String _cap(String s) => s[0].toUpperCase() + s.substring(1);



  @override
  Widget build(BuildContext context) {
    final achatAuNiveau = prixAuNiveau(achatCarton, achatNiveau);
    final venteAuNiveau = prixAuNiveau(venteCarton, venteNiveau);
    final margeReelle   = achatCarton > 0
        ? ((venteCarton - achatCarton) / achatCarton * 100) : 0.0;
    final profitColor   = benefice >= 0 ? AppTheme.successColor : AppTheme.dangerColor;

    return Form(key: formKey, child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Mode de tarification ─────────────────────────────────────────
        _SecTitle('Mode de tarification', isDark),
        const SizedBox(height: 10),
        Row(children: [
          for (final m in [PricingMode.pctMarge, PricingMode.cartonFixe]) ...[
            Expanded(child: GestureDetector(
              onTap: () => onMode(m),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: mode == m
                      ? AppTheme.primaryColor.withValues(alpha: 0.12) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: mode == m ? AppTheme.primaryColor : Colors.grey.withValues(alpha: 0.3),
                    width: 1.5)),
                child: Row(children: [
                  Icon(m == PricingMode.pctMarge
                      ? Icons.percent_rounded : Icons.price_change_outlined,
                    size: 18, color: mode == m ? AppTheme.primaryColor : Colors.grey[400]),
                  const SizedBox(width: 8),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(m == PricingMode.pctMarge ? '% Marge' : 'Prix fixe',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                        color: mode == m ? AppTheme.primaryColor : Colors.grey[500])),
                    Text(m == PricingMode.pctMarge ? 'Calculé par marge' : 'Vente manuelle',
                      style: TextStyle(fontSize: 10,
                        color: mode == m
                            ? AppTheme.primaryColor.withValues(alpha: 0.65) : Colors.grey[400])),
                  ])),
                ]),
              ),
            )),
          ],
        ]),
        const SizedBox(height: 18),

        // ── Prix d'achat ─────────────────────────────────────────────────
        _SecTitle('Prix d\'achat', isDark),
        const SizedBox(height: 8),
        // Sélecteur de niveau achat
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isDark
                ? AppTheme.darkBorder.withValues(alpha: 0.15)
                : AppTheme.lightBorder.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(12)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.layers_outlined, size: 14, color: Colors.grey[500]),
              const SizedBox(width: 6),
              Text('Saisir le prix au niveau :',
                style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              const Spacer(),
              ...(_niveaux.map((n) => Padding(
                padding: const EdgeInsets.only(left: 6),
                child: _niveauBtn(n, achatNiveau, onAchatNiveau)))),
            ]),
            const SizedBox(height: 10),
            _Field(
              label: 'Prix d\'achat / ${niveauLabel(achatNiveau)} (FBu)',
              ctrl: achatCtrl,
              hint: achatAuNiveau > 0 ? achatAuNiveau.toStringAsFixed(0) : 'Ex: 15000',
              icon: Icons.shopping_cart_outlined, isDark: isDark,
              inputType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Obligatoire';
                if ((double.tryParse(v) ?? 0) <= 0) return 'Doit être > 0';
                return null;
              }),
            if (achatCarton > 0) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(8)),
                child: Row(children: [
                  const Icon(Icons.swap_horiz_rounded,
                    size: 14, color: AppTheme.primaryColor),
                  const SizedBox(width: 6),
                  Text('= ${achatCarton.toStringAsFixed(0)} FBu / carton',
                    style: const TextStyle(fontSize: 12, color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w600)),
                ])),
            ],
          ]),
        ),
        const SizedBox(height: 14),

        // ── Prix de vente ────────────────────────────────────────────────
        _SecTitle('Prix de vente', isDark),
        const SizedBox(height: 8),
        if (mode == PricingMode.pctMarge)
          _Field(label: 'Marge (%)', ctrl: margeCtrl,
            hint: 'Ex: 20', icon: Icons.percent_rounded, isDark: isDark,
            suffix: '%', inputType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Obligatoire';
              if ((double.tryParse(v) ?? 0) <= 0) return 'Doit être > 0%';
              return null;
            })
        else
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark
                  ? AppTheme.darkBorder.withValues(alpha: 0.15)
                  : AppTheme.lightBorder.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.layers_outlined, size: 14, color: Colors.grey[500]),
                const SizedBox(width: 6),
                Text('Saisir le prix de vente au niveau :',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                const Spacer(),
                ...(_niveaux.map((n) => Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: _niveauBtn(n, venteNiveau, onVenteNiveau)))),
              ]),
              const SizedBox(height: 10),
              _Field(
                label: 'Prix de vente / ${niveauLabel(venteNiveau)} (FBu)',
                ctrl: venteCtrl,
                hint: venteAuNiveau > 0 ? venteAuNiveau.toStringAsFixed(0) : 'Ex: 18000',
                icon: Icons.sell_outlined, isDark: isDark,
                inputType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Obligatoire';
                  if ((double.tryParse(v) ?? 0) <= 0) return 'Doit être > 0';
                  return null;
                }),
              if (venteCarton > 0) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.successColor.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(8)),
                  child: Row(children: [
                    const Icon(Icons.swap_horiz_rounded,
                      size: 14, color: AppTheme.successColor),
                    const SizedBox(width: 6),
                    Text('= ${venteCarton.toStringAsFixed(0)} FBu / carton',
                      style: const TextStyle(fontSize: 12, color: AppTheme.successColor,
                        fontWeight: FontWeight.w600)),
                  ])),
              ],
            ]),
          ),
        const SizedBox(height: 16),

        // ── Aperçu financier ─────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              AppTheme.primaryColor.withValues(alpha: 0.07),
              AppTheme.successColor.withValues(alpha: 0.04)],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.18))),
          child: Column(children: [
            const Row(children: [
              Icon(Icons.insights_rounded, color: AppTheme.primaryColor, size: 15),
              SizedBox(width: 6),
              Text('Aperçu financier en temps réel',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                  color: AppTheme.primaryColor)),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _MiniCard('Achat/carton',
                achatCarton > 0 ? '${achatCarton.toStringAsFixed(0)} FBu' : '—',
                AppTheme.dangerColor, isDark)),
              Expanded(child: _MiniCard('Vente/carton',
                venteCarton > 0 ? '${venteCarton.toStringAsFixed(0)} FBu' : '—',
                AppTheme.primaryColor, isDark)),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _MiniCard('Marge réelle',
                achatCarton > 0 ? '${margeReelle.toStringAsFixed(1)}%' : '—',
                AppTheme.warningColor, isDark)),
              Expanded(child: _MiniCard('Bénéfice estimé',
                nbCartons > 0 && achatCarton > 0
                    ? '${benefice.toStringAsFixed(0)} FBu' : '—',
                profitColor, isDark, highlight: true)),
            ]),
          ]),
        ),
      ]),
    ));
  }
}

// ============================================================================
// ÉTAPE 4 — STOCK & ALERTES
// ============================================================================
class _StepStock extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController seuilCtrl, emplacementCtrl, joursCtrl;
  final bool alertePeremption;
  final ValueChanged<bool> onAlerte;
  final int totalComprimes;
  final double benefice;
  final String nom;
  final bool isDark;

  const _StepStock({
    required this.formKey, required this.seuilCtrl,
    required this.emplacementCtrl, required this.joursCtrl,
    required this.alertePeremption, required this.onAlerte,
    required this.totalComprimes, required this.benefice,
    required this.nom, required this.isDark,
  });

  @override
  Widget build(BuildContext context) => Form(key: formKey, child: SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(24, 14, 24, 14),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            AppTheme.successColor.withValues(alpha: 0.1),
            AppTheme.primaryColor.withValues(alpha: 0.04)]),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.successColor.withValues(alpha: 0.3), width: 1.5)),
        child: Row(children: [
          Container(padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.successColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.check_circle_outline_rounded,
              color: AppTheme.successColor, size: 22)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Prêt à enregistrer',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                color: AppTheme.successColor)),
            Text(nom.isNotEmpty ? nom : '—',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('$totalComprimes unités',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                color: AppTheme.primaryColor)),
            if (benefice > 0)
              Text('${benefice.toStringAsFixed(0)} FBu',
                style: TextStyle(fontSize: 12,
                  color: AppTheme.successColor.withValues(alpha: 0.8))),
          ]),
        ]),
      ),
      const SizedBox(height: 18),
      _SecTitle('Emplacement', isDark),
      const SizedBox(height: 8),
      _Field(label: 'Emplacement dans la pharmacie', ctrl: emplacementCtrl,
        hint: 'Ex: Rayon A3 / Réfrigérateur', icon: Icons.location_on_outlined, isDark: isDark),
      const SizedBox(height: 14),
      _SecTitle('Seuil d\'alerte stock', isDark),
      const SizedBox(height: 8),
      _Field(label: 'Alerter si stock < X comprimés', ctrl: seuilCtrl,
        hint: 'Ex: 50', icon: Icons.notifications_outlined, isDark: isDark,
        inputType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly]),
      const SizedBox(height: 14),
      _SecTitle('Alertes péremption', isDark),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark
              ? AppTheme.darkBorder.withValues(alpha: 0.2)
              : AppTheme.lightBorder.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(12)),
        child: Column(children: [
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Activer les alertes de péremption',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                  color: isDark ? AppTheme.darkForeground : AppTheme.lightForeground)),
              Text('Recevez une alerte avant expiration',
                style: TextStyle(fontSize: 11, color: Colors.grey[500])),
            ])),
            Switch(value: alertePeremption, onChanged: onAlerte,
              activeThumbColor: AppTheme.primaryColor),
          ]),
          if (alertePeremption) ...[
            const SizedBox(height: 10),
            _Field(label: 'Alerter X jours avant expiration', ctrl: joursCtrl,
              hint: 'Ex: 30', icon: Icons.access_time_rounded, isDark: isDark,
              suffix: 'jours', inputType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly]),
          ],
        ]),
      ),
    ]),
  ));
}

// ============================================================================
// WIDGETS COMMUNS
// ============================================================================

class _SecTitle extends StatelessWidget {
  final String title;
  final bool isDark;
  const _SecTitle(this.title, this.isDark);

  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 3, height: 15,
      decoration: BoxDecoration(color: AppTheme.primaryColor,
        borderRadius: BorderRadius.circular(2))),
    const SizedBox(width: 8),
    Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
      color: isDark ? AppTheme.darkForeground : AppTheme.lightForeground)),
  ]);
}

// Champ texte simple
class _Field extends StatelessWidget {
  final String label, hint;
  final TextEditingController ctrl;
  final IconData icon;
  final bool isDark;
  final String? Function(String?)? validator;
  final TextInputType? inputType;
  final String? suffix;
  final List<TextInputFormatter>? inputFormatters;

  const _Field({
    required this.label, required this.ctrl, required this.hint,
    required this.icon, required this.isDark,
    this.validator, this.inputType, this.suffix, this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
      color: isDark ? AppTheme.darkForeground.withValues(alpha: 0.65) : Colors.grey[700])),
    const SizedBox(height: 5),
    TextFormField(controller: ctrl, validator: validator,
      keyboardType: inputType, inputFormatters: inputFormatters,
      style: TextStyle(fontSize: 14,
        color: isDark ? AppTheme.darkForeground : AppTheme.lightForeground),
      decoration: _dec(hint, icon, isDark, suffix: suffix)),
  ]);
}

// Champ autocomplete
class _AutoField extends StatefulWidget {
  final String label, hint;
  final TextEditingController ctrl;
  final IconData icon;
  final List<String> suggestions;
  final bool isDark;
  const _AutoField({required this.label, required this.ctrl, required this.hint,
    required this.icon, required this.suggestions, required this.isDark});
  @override State<_AutoField> createState() => _AutoFieldState();
}
class _AutoFieldState extends State<_AutoField> {
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(widget.label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
      color: widget.isDark ? AppTheme.darkForeground.withValues(alpha: 0.65) : Colors.grey[700])),
    const SizedBox(height: 5),
    Autocomplete<String>(
      optionsBuilder: (tv) {
        if (tv.text.isEmpty) return const [];
        return widget.suggestions
            .where((s) => s.toLowerCase().contains(tv.text.toLowerCase()));
      },
      onSelected: (v) => widget.ctrl.text = v,
      fieldViewBuilder: (_, inCtrl, fn, onSub) {
        if (inCtrl.text != widget.ctrl.text) inCtrl.text = widget.ctrl.text;
        inCtrl.addListener(() {
          if (widget.ctrl.text != inCtrl.text) widget.ctrl.text = inCtrl.text;
        });
        return TextFormField(controller: inCtrl, focusNode: fn,
          onFieldSubmitted: (_) => onSub(),
          style: TextStyle(fontSize: 14,
            color: widget.isDark ? AppTheme.darkForeground : AppTheme.lightForeground),
          decoration: _dec(widget.hint, widget.icon, widget.isDark,
            suffix2: const Icon(Icons.expand_more_rounded, size: 16)));
      },
      optionsViewBuilder: (_, onSel, opts) => Align(
        alignment: Alignment.topLeft,
        child: Material(color: Colors.transparent, child: Container(
          constraints: const BoxConstraints(maxHeight: 180, maxWidth: 280),
          decoration: BoxDecoration(
            color: widget.isDark ? AppTheme.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 14, offset: const Offset(0, 5))]),
          child: ListView(padding: const EdgeInsets.symmetric(vertical: 4),
            shrinkWrap: true,
            children: opts.map((o) => InkWell(
              onTap: () => onSel(o),
              child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                child: Row(children: [
                  Icon(Icons.arrow_forward_ios_rounded, size: 11,
                    color: AppTheme.primaryColor.withValues(alpha: 0.5)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(o, style: TextStyle(fontSize: 13,
                    color: widget.isDark
                        ? AppTheme.darkForeground : AppTheme.lightForeground))),
                ])),
            )).toList()),
        ))),
    ),
  ]);
}

// Champ date — format DD/MM/YYYY
class _DateField extends StatelessWidget {
  final String label;
  final DateTime? date;
  final ValueChanged<DateTime?> onPicked;
  final bool isDark, isRequired;
  final DateTime firstDate, lastDate;
  const _DateField({required this.label, required this.date, required this.onPicked,
    required this.isDark, required this.firstDate, required this.lastDate,
    this.isRequired = false});

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
      color: isDark ? AppTheme.darkForeground.withValues(alpha: 0.65) : Colors.grey[700])),
    const SizedBox(height: 5),
    GestureDetector(
      onTap: () async {
        final init = date ?? (firstDate.isAfter(DateTime.now())
            ? firstDate : DateTime.now().add(const Duration(days: 1)));
        final picked = await showDatePicker(
          context: context,
          initialDate: init.isAfter(firstDate) ? init : firstDate,
          firstDate: firstDate, lastDate: lastDate,
          builder: (ctx, child) {
            final theme = Theme.of(ctx);
            return Theme(
              data: theme.copyWith(
                colorScheme: isDark
                    ? ColorScheme.dark(
                        primary: AppTheme.primaryColor,
                        onPrimary: Colors.white,
                        surface: AppTheme.darkCard,
                        onSurface: AppTheme.darkForeground,
                      )
                    : ColorScheme.light(
                        primary: AppTheme.primaryColor,
                        onPrimary: Colors.white,
                        surface: Colors.white,
                        onSurface: Colors.black87,
                      ),
                dialogBackgroundColor: isDark ? AppTheme.darkCard : Colors.white,
                textButtonTheme: TextButtonThemeData(
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                  ),
                ),
              ),
              child: child!,
            );
          });
        if (picked != null) onPicked(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isDark
              ? AppTheme.darkBorder.withValues(alpha: 0.2)
              : AppTheme.lightBorder.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: (isRequired && date == null)
                ? AppTheme.dangerColor
                : (isDark ? AppTheme.darkBorder.withValues(alpha: 0.4) : AppTheme.lightBorder))),
        child: Row(children: [
          Icon(Icons.calendar_today_outlined, size: 16,
            color: date != null ? AppTheme.primaryColor
                : AppTheme.primaryColor.withValues(alpha: 0.4)),
          const SizedBox(width: 10),
          Expanded(child: Text(
            date != null ? _fmt(date!) : 'JJ/MM/AAAA',
            style: TextStyle(fontSize: 14,
              color: date != null
                  ? (isDark ? AppTheme.darkForeground : AppTheme.lightForeground)
                  : (isDark
                      ? AppTheme.darkForeground.withValues(alpha: 0.3)
                      : Colors.grey[400])))),
          if (date != null)
            Icon(Icons.check_circle_outline_rounded, size: 16, color: AppTheme.successColor),
        ]),
      ),
    ),
  ]);
}

// Sélecteur d'ordonnance
class _OrdonnanceSelector extends StatelessWidget {
  final String current;
  final ValueChanged<String> onChanged;
  final bool isDark;
  const _OrdonnanceSelector({required this.current, required this.onChanged, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final items = [
      (OrdonnanceType.non,    Icons.no_encryption_outlined,  AppTheme.successColor),
      (OrdonnanceType.oui,    Icons.assignment_outlined,      AppTheme.warningColor),
      (OrdonnanceType.liste1, Icons.warning_amber_rounded,    AppTheme.dangerColor),
      (OrdonnanceType.stup,   Icons.lock_outlined,            const Color(0xFF8B5CF6)),
    ];
    return Wrap(spacing: 8, runSpacing: 8, children: items.map((item) {
      final sel = current == item.$1.value;
      return GestureDetector(
        onTap: () => onChanged(item.$1.value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: sel ? item.$3.withValues(alpha: 0.14) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: sel ? item.$3 : (isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
              width: sel ? 1.5 : 1)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(item.$2, size: 15, color: sel ? item.$3 : Colors.grey[400]),
            const SizedBox(width: 6),
            Text(item.$1.label, style: TextStyle(fontSize: 12,
              fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
              color: sel ? item.$3 : Colors.grey[500])),
          ])),
      );
    }).toList());
  }
}

// Stepper +/-
class _Stepper extends StatelessWidget {
  final TextEditingController ctrl;
  final Color color;
  const _Stepper({required this.ctrl, required this.color});

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    GestureDetector(
      onTap: () { final v = int.tryParse(ctrl.text) ?? 1; if (v > 1) ctrl.text = (v-1).toString(); },
      child: Container(width: 30, height: 30,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8)),
        child: Icon(Icons.remove_rounded, size: 16, color: color))),
    SizedBox(width: 50, child: TextFormField(controller: ctrl,
      textAlign: TextAlign.center,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: color),
      decoration: InputDecoration(border: InputBorder.none, filled: true,
        fillColor: color.withValues(alpha: 0.07),
        contentPadding: const EdgeInsets.symmetric(vertical: 7),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: color.withValues(alpha: 0.2))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: color))))),
    GestureDetector(
      onTap: () { final v = int.tryParse(ctrl.text) ?? 0; ctrl.text = (v+1).toString(); },
      child: Container(width: 30, height: 30,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8)),
        child: Icon(Icons.add_rounded, size: 16, color: color))),
  ]);
}

// Métrique résumé
class _Metric extends StatelessWidget {
  final String emoji, value, label;
  final Color color;
  const _Metric(this.emoji, this.value, this.label, this.color);
  @override
  Widget build(BuildContext context) => Column(children: [
    Text(emoji, style: const TextStyle(fontSize: 20)),
    const SizedBox(height: 2),
    Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
    Text(label, style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.7))),
  ]);
}

// Mini carte financière
class _MiniCard extends StatelessWidget {
  final String label, value;
  final Color color;
  final bool isDark, highlight;
  const _MiniCard(this.label, this.value, this.color, this.isDark, {this.highlight = false});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(right: 8),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: highlight ? color.withValues(alpha: 0.1)
          : (isDark ? AppTheme.darkBorder.withValues(alpha: 0.2)
              : AppTheme.lightBorder.withValues(alpha: 0.3)),
      borderRadius: BorderRadius.circular(10),
      border: highlight ? Border.all(color: color.withValues(alpha: 0.3)) : null),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 10,
        color: isDark ? AppTheme.darkForeground.withValues(alpha: 0.5) : Colors.grey[500])),
      const SizedBox(height: 2),
      Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
    ]));
}

// Décoration commune TextFormField
InputDecoration _dec(String hint, IconData icon, bool isDark,
    {String? suffix, Widget? suffix2}) => InputDecoration(
  hintText: hint,
  hintStyle: TextStyle(fontSize: 13,
    color: isDark ? AppTheme.darkForeground.withValues(alpha: 0.28) : Colors.grey[400]),
  prefixIcon: Icon(icon, size: 17, color: AppTheme.primaryColor.withValues(alpha: 0.65)),
  suffixText: suffix, suffixIcon: suffix2,
  suffixStyle: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w600),
  filled: true,
  fillColor: isDark
      ? AppTheme.darkBorder.withValues(alpha: 0.18)
      : AppTheme.lightBorder.withValues(alpha: 0.28),
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
    borderSide: BorderSide(
      color: isDark ? AppTheme.darkBorder.withValues(alpha: 0.38) : AppTheme.lightBorder, width: 1)),
  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
    borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5)),
  errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
    borderSide: const BorderSide(color: AppTheme.dangerColor)),
  focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
    borderSide: const BorderSide(color: AppTheme.dangerColor, width: 1.5)),
  contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
);
