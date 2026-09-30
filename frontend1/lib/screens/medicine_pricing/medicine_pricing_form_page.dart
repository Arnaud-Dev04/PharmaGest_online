import 'package:flutter/material.dart';
import 'package:frontend1/core/theme.dart';
import 'package:frontend1/models/medicine_pricing.dart';
import 'package:frontend1/services/medicine_pricing_service.dart';
import 'package:frontend1/widgets/medicine_pricing/conditioning_section.dart';
import 'package:frontend1/widgets/medicine_pricing/pricing_mode_widget.dart';
import 'package:frontend1/widgets/medicine_pricing/financial_summary.dart';
import 'package:intl/intl.dart';

/// Formulaire complet de gestion des prix avec 3 modes
class MedicinePricingFormPage extends StatefulWidget {
  final MedicinePricing? existing; // null = création, non-null = édition

  const MedicinePricingFormPage({super.key, this.existing});

  @override
  State<MedicinePricingFormPage> createState() =>
      _MedicinePricingFormPageState();
}

class _MedicinePricingFormPageState extends State<MedicinePricingFormPage> {
  final _formKey = GlobalKey<FormState>();
  final MedicinePricingService _service = MedicinePricingService();
  bool _isSubmitting = false;

  // --- Listes de suggestions prédéfinies ---
  static const List<String> _formeSuggestions = [
    'Comprimé', 'Comprimé pelliculé', 'Comprimé effervescent', 'Comprimé orodispersible',
    'Gélule', 'Capsule molle', 'Sirop', 'Suspension buvable', 'Solution buvable',
    'Solution injectable', 'Poudre pour injection', 'Pommade', 'Crème', 'Gel',
    'Collyre', 'Gouttes auriculaires', 'Suppositoire', 'Ovule', 'Patch transdermique',
    'Sachet', 'Poudre pour suspension', 'Spray nasal', 'Aérosol', 'Inhalateur',
    'Lotion', 'Shampooing', 'Solution pour perfusion', 'Émulsion',
  ];

  static const List<String> _dciSuggestions = [
    'Paracétamol', 'Amoxicilline', 'Amoxicilline + Acide clavulanique',
    'Ibuprofène', 'Diclofénac', 'Oméprazole', 'Métronidazole',
    'Ciprofloxacine', 'Azithromycine', 'Doxycycline', 'Céfixime',
    'Céftriaxone', 'Cotrimoxazole', 'Érythromycine', 'Gentamicine',
    'Métformine', 'Glibenclamide', 'Amlodipine', 'Captopril', 'Enalapril',
    'Losartan', 'Atenolol', 'Furosémide', 'Hydrochlorothiazide',
    'Salbutamol', 'Prednisolone', 'Dexaméthasone', 'Hydrocortisone',
    'Fer + Acide folique', 'Acide folique', 'Vitamine C', 'Vitamine B complexe',
    'Albendazole', 'Mébendazole', 'Artéméther + Luméfantrine', 'Quinine',
    'Chloroquine', 'Artésunate', 'Tramadol', 'Codéine', 'Morphine',
    'Diazépam', 'Phénobarbital', 'Carbamazépine', 'Insuline',
    'Nifédipine', 'Ranitidine', 'Lopéramide', 'ORS (SRO)',
  ];

  static const List<String> _dosageSuggestions = [
    '100mg', '125mg', '200mg', '250mg', '400mg', '500mg', '1g',
    '50mg', '75mg', '150mg', '300mg', '600mg', '800mg',
    '5mg', '10mg', '20mg', '25mg', '40mg', '80mg',
    '2.5mg', '1mg', '0.5mg', '0.25mg',
    '125mg/5ml', '250mg/5ml', '100mg/5ml', '200mg/5ml',
    '50mg/ml', '100mg/ml', '250mg/ml', '500mg/ml',
    '1%', '2%', '5%', '0.5%', '0.1%', '0.05%',
    '20mg/ml', '40mg/ml', '80mg/2ml', '100UI/ml',
  ];

  // --- Autocomplete ---
  List<String> _autocompleteSuggestions = [];

  // --- Info médicament ---
  late final TextEditingController _nomCtrl;
  late final TextEditingController _dciCtrl;
  late final TextEditingController _formeCtrl;
  late final TextEditingController _dosageCtrl;
  late final TextEditingController _lotCtrl;
  late final TextEditingController _fournisseurCtrl;
  late final TextEditingController _bonLivraisonCtrl;
  late final TextEditingController _dateReceptionCtrl;
  late final TextEditingController _datePeremptionCtrl;

  // --- Conditionnement ---
  late final TextEditingController _nbCartonsCtrl;
  late final TextEditingController _boitesParCartonCtrl;
  late final TextEditingController _plaquettesParBoiteCtrl;
  late final TextEditingController _comprimesParPlaquetteCtrl;

  // --- Prix ---
  PricingMode _selectedMode = PricingMode.manuel;
  late final TextEditingController _achatCartonCtrl;
  late final TextEditingController _margePctCtrl;
  late final TextEditingController _venteCartonCtrl;
  late final TextEditingController _venteBoiteCtrl;
  late final TextEditingController _ventePlaquetteCtrl;
  late final TextEditingController _venteComprimeCtrl;
  // PA par niveau (mode manuel)
  late final TextEditingController _achatBoiteCtrl;
  late final TextEditingController _achatPlaquetteCtrl;
  late final TextEditingController _achatComprimeCtrl;

  // --- Stock ---
  late final TextEditingController _seuilAlerteCtrl;
  late final TextEditingController _emplacementCtrl;
  String _seuilNiveau = 'comprimes'; // comprimes, plaquettes, boites, cartons
  bool _alertePeremption = true;
  late final TextEditingController _alerteJoursCtrl;
  OrdonnanceType _ordonnance = OrdonnanceType.non;
  String _referenceLevel = 'carton'; // carton, boite, plaquette, unite

  // --- Calculated values ---
  int _totalBoites = 0;
  int _totalPlaquettes = 0;
  int _totalComprimes = 0;
  double _valeurAchatTotale = 0;
  double _valeurVenteTotale = 0;
  double _beneficeEstime = 0;
  double _gainNetComprime = 0;
  double _margeCalculee = 0;
  double _margeAbsolue = 0;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;

    _nomCtrl = TextEditingController(text: e?.nom ?? '');
    _dciCtrl = TextEditingController(text: e?.dci ?? '');
    _formeCtrl = TextEditingController(text: e?.forme ?? '');
    _dosageCtrl = TextEditingController(text: e?.dosage ?? '');
    _lotCtrl = TextEditingController(text: e?.lot ?? '');
    _fournisseurCtrl = TextEditingController(text: e?.fournisseur ?? '');
    _bonLivraisonCtrl = TextEditingController(text: e?.bonLivraison ?? '');
    _dateReceptionCtrl = TextEditingController(
      text: e?.dateReception != null
          ? DateFormat('yyyy-MM-dd').format(e!.dateReception!)
          : DateFormat('yyyy-MM-dd').format(DateTime.now()),
    );
    _datePeremptionCtrl = TextEditingController(
      text: e?.datePeremption != null
          ? DateFormat('yyyy-MM-dd').format(e!.datePeremption!)
          : '',
    );

    _nbCartonsCtrl =
        TextEditingController(text: e?.nbCartons.toString() ?? '');
    _boitesParCartonCtrl =
        TextEditingController(text: e?.boitesParCarton.toString() ?? '');
    _plaquettesParBoiteCtrl =
        TextEditingController(text: e?.plaquettesParBoite.toString() ?? '');
    _comprimesParPlaquetteCtrl =
        TextEditingController(text: e?.comprimesParPlaquette.toString() ?? '');

    if (e != null) {
      _selectedMode = PricingMode.fromString(e.prixMode);
    }
    _achatCartonCtrl = TextEditingController(
      text: e != null ? e.achatCarton.toStringAsFixed(0) : '',
    );
    _margePctCtrl = TextEditingController(
      text: e?.margePct?.toStringAsFixed(1) ?? '',
    );
    _venteCartonCtrl = TextEditingController(
      text: e != null ? e.venteCarton.toStringAsFixed(0) : '',
    );
    _venteBoiteCtrl = TextEditingController(
      text: e != null ? e.venteBoite.toStringAsFixed(0) : '',
    );
    _ventePlaquetteCtrl = TextEditingController(
      text: e != null ? e.ventePlaquette.toStringAsFixed(0) : '',
    );
    _venteComprimeCtrl = TextEditingController(
      text: e != null ? e.venteComprime.toStringAsFixed(2) : '',
    );
    // PA par niveau
    _achatBoiteCtrl = TextEditingController();
    _achatPlaquetteCtrl = TextEditingController();
    _achatComprimeCtrl = TextEditingController();

    _seuilAlerteCtrl =
        TextEditingController(text: e?.seuilAlerte.toString() ?? '10');
    _emplacementCtrl = TextEditingController(text: e?.emplacement ?? '');
    _alertePeremption = e?.alertePeremption ?? true;
    _alerteJoursCtrl = TextEditingController(text: '30');
    _ordonnance = e != null
        ? OrdonnanceType.fromString(e.ordonnance)
        : OrdonnanceType.non;

    // Add listeners for real-time calculation
    for (final ctrl in [
      _nbCartonsCtrl, _boitesParCartonCtrl,
      _plaquettesParBoiteCtrl, _comprimesParPlaquetteCtrl,
      _achatCartonCtrl, _margePctCtrl,
      _venteCartonCtrl, _venteBoiteCtrl,
      _ventePlaquetteCtrl, _venteComprimeCtrl,
      _achatBoiteCtrl, _achatPlaquetteCtrl, _achatComprimeCtrl,
    ]) {
      ctrl.addListener(_recalculate);
    }

    // Initial calculation
    _recalculate();
  }

  @override
  void dispose() {
    for (final ctrl in [
      _nomCtrl, _dciCtrl, _formeCtrl, _dosageCtrl, _lotCtrl,
      _fournisseurCtrl, _bonLivraisonCtrl, _dateReceptionCtrl,
      _datePeremptionCtrl, _nbCartonsCtrl, _boitesParCartonCtrl,
      _plaquettesParBoiteCtrl, _comprimesParPlaquetteCtrl,
      _achatCartonCtrl, _margePctCtrl, _venteCartonCtrl,
      _venteBoiteCtrl, _ventePlaquetteCtrl, _venteComprimeCtrl,
      _achatBoiteCtrl, _achatPlaquetteCtrl, _achatComprimeCtrl,
      _seuilAlerteCtrl, _emplacementCtrl, _alerteJoursCtrl,
    ]) {
      ctrl.dispose();
    }
    super.dispose();
  }

  void _recalculate() {
    final nbCartons = int.tryParse(_nbCartonsCtrl.text) ?? 0;
    final boitesParCarton = int.tryParse(_boitesParCartonCtrl.text) ?? 0;
    final plaquettesParBoite = int.tryParse(_plaquettesParBoiteCtrl.text) ?? 0;
    final comprimesParPlaquette =
        int.tryParse(_comprimesParPlaquetteCtrl.text) ?? 0;
    final achatCarton = double.tryParse(_achatCartonCtrl.text) ?? 0;
    final margePct = double.tryParse(_margePctCtrl.text) ?? 0;

    final totalBoites = nbCartons * boitesParCarton;
    final totalPlaquettes = totalBoites * plaquettesParBoite;
    final totalComprimes = totalPlaquettes * comprimesParPlaquette;

    double venteCarton = double.tryParse(_venteCartonCtrl.text) ?? 0;
    double venteBoite = double.tryParse(_venteBoiteCtrl.text) ?? 0;
    double ventePlaquette = double.tryParse(_ventePlaquetteCtrl.text) ?? 0;
    double venteComprime = double.tryParse(_venteComprimeCtrl.text) ?? 0;
    double margeCalc = margePct;
    double margeAbs = 0;

    if (_selectedMode == PricingMode.pctMarge && achatCarton > 0) {
      venteCarton = achatCarton * (1 + margePct / 100);
      venteBoite = boitesParCarton > 0 ? venteCarton / boitesParCarton : 0;
      ventePlaquette =
          plaquettesParBoite > 0 ? venteBoite / plaquettesParBoite : 0;
      venteComprime =
          comprimesParPlaquette > 0 ? ventePlaquette / comprimesParPlaquette : 0;

      // Update display controllers without triggering listeners
      _updateControllerSilently(_venteCartonCtrl, venteCarton.toStringAsFixed(0));
      _updateControllerSilently(_venteBoiteCtrl, venteBoite.toStringAsFixed(0));
      _updateControllerSilently(
          _ventePlaquetteCtrl, ventePlaquette.toStringAsFixed(0));
      _updateControllerSilently(
          _venteComprimeCtrl, venteComprime.toStringAsFixed(2));
    } else if (_selectedMode == PricingMode.cartonFixe && venteCarton > 0) {
      venteBoite = boitesParCarton > 0 ? venteCarton / boitesParCarton : 0;
      ventePlaquette =
          plaquettesParBoite > 0 ? venteBoite / plaquettesParBoite : 0;
      venteComprime =
          comprimesParPlaquette > 0 ? ventePlaquette / comprimesParPlaquette : 0;

      if (achatCarton > 0) {
        margeCalc = ((venteCarton - achatCarton) / achatCarton) * 100;
        margeAbs = venteCarton - achatCarton;
      }

      _updateControllerSilently(_venteBoiteCtrl, venteBoite.toStringAsFixed(0));
      _updateControllerSilently(
          _ventePlaquetteCtrl, ventePlaquette.toStringAsFixed(0));
      _updateControllerSilently(
          _venteComprimeCtrl, venteComprime.toStringAsFixed(2));
    } else if (_selectedMode == PricingMode.manuel) {
      // ── Mode Manuel : calcul auto à partir du niveau de référence ──
      final comprimesParBoite = plaquettesParBoite * comprimesParPlaquette;
      final comprimesParCarton = boitesParCarton * comprimesParBoite;

      double paRef = 0;
      double pvRef = 0;

      switch (_referenceLevel) {
        case 'carton':
          paRef = achatCarton;
          pvRef = double.tryParse(_venteCartonCtrl.text) ?? 0;
          if (paRef > 0 && boitesParCarton > 0) {
            _updateControllerSilently(_achatBoiteCtrl, (paRef / boitesParCarton).toStringAsFixed(0));
            if (plaquettesParBoite > 0) {
              _updateControllerSilently(_achatPlaquetteCtrl, (paRef / boitesParCarton / plaquettesParBoite).toStringAsFixed(0));
              if (comprimesParPlaquette > 0) {
                _updateControllerSilently(_achatComprimeCtrl, (paRef / comprimesParCarton).toStringAsFixed(2));
              }
            }
          }
          if (pvRef > 0 && boitesParCarton > 0) {
            venteCarton = pvRef;
            venteBoite = pvRef / boitesParCarton;
            ventePlaquette = plaquettesParBoite > 0 ? venteBoite / plaquettesParBoite : 0;
            venteComprime = comprimesParPlaquette > 0 ? ventePlaquette / comprimesParPlaquette : 0;
            _updateControllerSilently(_venteBoiteCtrl, venteBoite.toStringAsFixed(0));
            _updateControllerSilently(_ventePlaquetteCtrl, ventePlaquette.toStringAsFixed(0));
            _updateControllerSilently(_venteComprimeCtrl, venteComprime.toStringAsFixed(2));
          }
          break;
        case 'boite':
          paRef = double.tryParse(_achatBoiteCtrl.text) ?? 0;
          pvRef = double.tryParse(_venteBoiteCtrl.text) ?? 0;
          if (paRef > 0) {
            if (boitesParCarton > 0) {
              _updateControllerSilently(_achatCartonCtrl, (paRef * boitesParCarton).toStringAsFixed(0));
            }
            if (plaquettesParBoite > 0) {
              _updateControllerSilently(_achatPlaquetteCtrl, (paRef / plaquettesParBoite).toStringAsFixed(0));
              if (comprimesParPlaquette > 0) {
                _updateControllerSilently(_achatComprimeCtrl, (paRef / comprimesParBoite).toStringAsFixed(2));
              }
            }
          }
          if (pvRef > 0) {
            venteBoite = pvRef;
            venteCarton = boitesParCarton > 0 ? pvRef * boitesParCarton : 0;
            ventePlaquette = plaquettesParBoite > 0 ? pvRef / plaquettesParBoite : 0;
            venteComprime = comprimesParPlaquette > 0 ? ventePlaquette / comprimesParPlaquette : 0;
            _updateControllerSilently(_venteCartonCtrl, venteCarton.toStringAsFixed(0));
            _updateControllerSilently(_ventePlaquetteCtrl, ventePlaquette.toStringAsFixed(0));
            _updateControllerSilently(_venteComprimeCtrl, venteComprime.toStringAsFixed(2));
          }
          break;
        case 'plaquette':
          paRef = double.tryParse(_achatPlaquetteCtrl.text) ?? 0;
          pvRef = double.tryParse(_ventePlaquetteCtrl.text) ?? 0;
          if (paRef > 0) {
            if (comprimesParPlaquette > 0) {
              _updateControllerSilently(_achatComprimeCtrl, (paRef / comprimesParPlaquette).toStringAsFixed(2));
            }
            if (plaquettesParBoite > 0) {
              final paBoite = paRef * plaquettesParBoite;
              _updateControllerSilently(_achatBoiteCtrl, paBoite.toStringAsFixed(0));
              if (boitesParCarton > 0) {
                _updateControllerSilently(_achatCartonCtrl, (paBoite * boitesParCarton).toStringAsFixed(0));
              }
            }
          }
          if (pvRef > 0) {
            ventePlaquette = pvRef;
            venteBoite = plaquettesParBoite > 0 ? pvRef * plaquettesParBoite : 0;
            venteCarton = boitesParCarton > 0 ? venteBoite * boitesParCarton : 0;
            venteComprime = comprimesParPlaquette > 0 ? pvRef / comprimesParPlaquette : 0;
            _updateControllerSilently(_venteCartonCtrl, venteCarton.toStringAsFixed(0));
            _updateControllerSilently(_venteBoiteCtrl, venteBoite.toStringAsFixed(0));
            _updateControllerSilently(_venteComprimeCtrl, venteComprime.toStringAsFixed(2));
          }
          break;
        case 'unite':
          paRef = double.tryParse(_achatComprimeCtrl.text) ?? 0;
          pvRef = double.tryParse(_venteComprimeCtrl.text) ?? 0;
          if (paRef > 0) {
            if (comprimesParPlaquette > 0) {
              final paPlaq = paRef * comprimesParPlaquette;
              _updateControllerSilently(_achatPlaquetteCtrl, paPlaq.toStringAsFixed(0));
              if (plaquettesParBoite > 0) {
                final paBoite = paPlaq * plaquettesParBoite;
                _updateControllerSilently(_achatBoiteCtrl, paBoite.toStringAsFixed(0));
                if (boitesParCarton > 0) {
                  _updateControllerSilently(_achatCartonCtrl, (paBoite * boitesParCarton).toStringAsFixed(0));
                }
              }
            }
          }
          if (pvRef > 0) {
            venteComprime = pvRef;
            ventePlaquette = comprimesParPlaquette > 0 ? pvRef * comprimesParPlaquette : 0;
            venteBoite = plaquettesParBoite > 0 ? ventePlaquette * plaquettesParBoite : 0;
            venteCarton = boitesParCarton > 0 ? venteBoite * boitesParCarton : 0;
            _updateControllerSilently(_venteCartonCtrl, venteCarton.toStringAsFixed(0));
            _updateControllerSilently(_venteBoiteCtrl, venteBoite.toStringAsFixed(0));
            _updateControllerSilently(_ventePlaquetteCtrl, ventePlaquette.toStringAsFixed(0));
          }
          break;
      }
    }

    final valeurAchat = nbCartons * achatCarton;
    final valeurVente = totalComprimes * venteComprime;
    final benefice = valeurVente - valeurAchat;

    double gainNet = 0;
    if (achatCarton > 0 && boitesParCarton > 0 && plaquettesParBoite > 0 && comprimesParPlaquette > 0) {
      final coutComprime = achatCarton / (boitesParCarton * plaquettesParBoite * comprimesParPlaquette);
      gainNet = venteComprime - coutComprime;
    }

    if (mounted) {
      setState(() {
        _totalBoites = totalBoites;
        _totalPlaquettes = totalPlaquettes;
        _totalComprimes = totalComprimes;
        _valeurAchatTotale = valeurAchat;
        _valeurVenteTotale = valeurVente;
        _beneficeEstime = benefice;
        _gainNetComprime = gainNet;
        _margeCalculee = margeCalc;
        _margeAbsolue = margeAbs;
      });
    }
  }

  void _updateControllerSilently(TextEditingController ctrl, String value) {
    if (ctrl.text != value) {
      ctrl.removeListener(_recalculate);
      ctrl.text = value;
      ctrl.addListener(_recalculate);
    }
  }

  Future<void> _pickDate(TextEditingController ctrl) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (date != null) {
      ctrl.text = DateFormat('yyyy-MM-dd').format(date);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final data = _buildFormData();

      if (widget.existing != null) {
        await _service.updatePricing(widget.existing!.id, data);
      } else {
        await _service.createPricing(data);
      }

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: AppTheme.dangerColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 780, maxHeight: 850),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(isDark),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoSection(context, isDark),
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 16),
                      ConditioningSection(
                        nbCartonsController: _nbCartonsCtrl,
                        boitesParCartonController: _boitesParCartonCtrl,
                        plaquettesParBoiteController: _plaquettesParBoiteCtrl,
                        comprimesParPlaquetteController:
                            _comprimesParPlaquetteCtrl,
                        totalBoites: _totalBoites,
                        totalPlaquettes: _totalPlaquettes,
                        totalComprimes: _totalComprimes,
                      ),
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 16),
                      PricingModeWidget(
                        selectedMode: _selectedMode,
                        onModeChanged: (mode) {
                          setState(() => _selectedMode = mode);
                          _recalculate();
                        },
                        referenceLevel: _referenceLevel,
                        onReferenceLevelChanged: (level) {
                          setState(() => _referenceLevel = level);
                          _recalculate();
                        },
                        achatCartonController: _achatCartonCtrl,
                        margePctController: _margePctCtrl,
                        venteCartonController: _venteCartonCtrl,
                        venteBoiteController: _venteBoiteCtrl,
                        ventePlaquetteController: _ventePlaquetteCtrl,
                        venteComprimeController: _venteComprimeCtrl,
                        achatBoiteController: _achatBoiteCtrl,
                        achatPlaquetteController: _achatPlaquetteCtrl,
                        achatComprimeController: _achatComprimeCtrl,
                        gainNetComprime: _gainNetComprime,
                        margeCalculee: _margeCalculee,
                        margeAbsolue: _margeAbsolue,
                        venteFieldsReadOnly:
                            _selectedMode != PricingMode.manuel,
                      ),
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 16),
                      FinancialSummary(
                        valeurAchatTotale: _valeurAchatTotale,
                        valeurVenteTotale: _valeurVenteTotale,
                        beneficeEstime: _beneficeEstime,
                      ),
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 16),
                      _buildStockSection(context, isDark),
                    ],
                  ),
                ),
              ),
            ),
            _buildFooter(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.price_change, color: AppTheme.primaryColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.existing != null
                  ? 'Modifier l\'entrée de prix'
                  : 'Nouvelle entrée de prix',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.medication, color: AppTheme.primaryColor, size: 20),
            const SizedBox(width: 8),
            Text(
              'Informations médicament',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Autocomplete<String>(
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text.isEmpty) return const Iterable.empty();
                  _loadAutocompleteSuggestions(textEditingValue.text);
                  return _autocompleteSuggestions.where((name) =>
                    name.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                },
                onSelected: (String selection) {
                  _nomCtrl.text = selection;
                },
                fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                  // Sync with our controller
                  if (controller.text.isEmpty && _nomCtrl.text.isNotEmpty) {
                    controller.text = _nomCtrl.text;
                  }
                  controller.addListener(() => _nomCtrl.text = controller.text);
                  return TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: const InputDecoration(
                      labelText: 'Nom du médicament *',
                      hintText: 'Ex: Amoxicilline',
                      prefixIcon: Icon(Icons.search, size: 18),
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Nom requis' : null,
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildAutocompleteField(
                controller: _dciCtrl,
                labelText: 'DCI',
                hintText: 'Ex: Amoxicilline trihydrate',
                suggestions: _dciSuggestions,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildAutocompleteField(
                controller: _formeCtrl,
                labelText: 'Forme',
                hintText: 'Ex: Gélule',
                suggestions: _formeSuggestions,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildAutocompleteField(
                controller: _dosageCtrl,
                labelText: 'Dosage',
                hintText: 'Ex: 500mg',
                suggestions: _dosageSuggestions,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _lotCtrl,
                decoration: const InputDecoration(
                  labelText: 'Numéro de lot *',
                  hintText: 'Ex: LOT-2026-001',
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Lot requis' : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _fournisseurCtrl,
                decoration: const InputDecoration(
                  labelText: 'Fournisseur',
                  hintText: 'Ex: Pharma Distrib',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _bonLivraisonCtrl,
                decoration: const InputDecoration(
                  labelText: 'Bon de livraison',
                  hintText: 'Ex: BL-2026-042',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _dateReceptionCtrl,
                decoration: const InputDecoration(
                  labelText: 'Date de réception',
                  suffixIcon: Icon(Icons.calendar_today, size: 18),
                ),
                readOnly: true,
                onTap: () => _pickDate(_dateReceptionCtrl),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _datePeremptionCtrl,
                decoration: const InputDecoration(
                  labelText: 'Date de péremption',
                  suffixIcon: Icon(Icons.calendar_today, size: 18),
                ),
                readOnly: true,
                onTap: () => _pickDate(_datePeremptionCtrl),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStockSection(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.settings, color: AppTheme.primaryColor, size: 20),
            const SizedBox(width: 8),
            Text(
              'Stock & Alertes',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Seuil d'alerte avec sélecteur de niveau
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: _seuilAlerteCtrl,
                decoration: const InputDecoration(
                  labelText: 'Seuil d\'alerte *',
                  hintText: '10',
                  prefixIcon: Icon(Icons.warning_amber, size: 18),
                ),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<String>(
                value: _seuilNiveau,
                decoration: const InputDecoration(
                  labelText: 'Niveau du seuil',
                  prefixIcon: Icon(Icons.layers, size: 18),
                ),
                items: const [
                  DropdownMenuItem(value: 'comprimes', child: Text('Comprimés')),
                  DropdownMenuItem(value: 'plaquettes', child: Text('Plaquettes')),
                  DropdownMenuItem(value: 'boites', child: Text('Boîtes')),
                  DropdownMenuItem(value: 'cartons', child: Text('Cartons')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _seuilNiveau = v);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Alerte péremption — manuelle (nombre de jours)
        Row(
          children: [
            Expanded(
              child: SwitchListTile(
                title: const Text('Alerte péremption'),
                subtitle: const Text('Notification avant expiration'),
                value: _alertePeremption,
                onChanged: (v) => setState(() => _alertePeremption = v),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const SizedBox(width: 12),
            if (_alertePeremption)
              Expanded(
                child: TextFormField(
                  controller: _alerteJoursCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Jours avant expiration',
                    hintText: '30',
                    prefixIcon: Icon(Icons.calendar_today, size: 18),
                    suffixText: 'jours',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (_alertePeremption) {
                      if (v == null || v.isEmpty) return 'Requis';
                      final n = int.tryParse(v);
                      if (n == null || n <= 0) return '> 0';
                    }
                    return null;
                  },
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),

        // Emplacement + Ordonnance
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _emplacementCtrl,
                decoration: const InputDecoration(
                  labelText: 'Emplacement',
                  hintText: 'Ex: Rayon A, Étagère 3',
                  prefixIcon: Icon(Icons.place, size: 18),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<OrdonnanceType>(
                value: _ordonnance,
                decoration: const InputDecoration(
                  labelText: 'Type d\'ordonnance',
                  prefixIcon: Icon(Icons.description, size: 18),
                ),
                items: OrdonnanceType.values.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type.label),
                  );
                }).toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _ordonnance = v);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  // --- Autocomplete loader ---
  Future<void> _loadAutocompleteSuggestions(String query) async {
    if (query.length < 1) return;
    try {
      final results = await _service.autocompleteNames(query);
      if (mounted) {
        setState(() => _autocompleteSuggestions = results);
      }
    } catch (_) {}
  }

  // --- Reset form for 'Save and continue' ---
  void _resetForm() {
    _nomCtrl.clear();
    _dciCtrl.clear();
    _formeCtrl.clear();
    _dosageCtrl.clear();
    _lotCtrl.clear();
    _fournisseurCtrl.clear();
    _bonLivraisonCtrl.clear();
    _datePeremptionCtrl.clear();
    _dateReceptionCtrl.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _nbCartonsCtrl.clear();
    _boitesParCartonCtrl.clear();
    _plaquettesParBoiteCtrl.clear();
    _comprimesParPlaquetteCtrl.clear();
    _achatCartonCtrl.clear();
    _margePctCtrl.clear();
    _venteCartonCtrl.clear();
    _venteBoiteCtrl.clear();
    _ventePlaquetteCtrl.clear();
    _venteComprimeCtrl.clear();
    _achatBoiteCtrl.clear();
    _achatPlaquetteCtrl.clear();
    _achatComprimeCtrl.clear();
    _seuilAlerteCtrl.text = '10';
    _emplacementCtrl.clear();
    _alerteJoursCtrl.text = '30';
    setState(() {
      _selectedMode = PricingMode.manuel;
      _seuilNiveau = 'comprimes';
      _alertePeremption = true;
      _ordonnance = OrdonnanceType.non;
    });
    _recalculate();
  }

  // --- Save and continue ---
  Future<void> _submitAndContinue() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    try {
      final data = _buildFormData();
      await _service.createPricing(data);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('Médicament enregistré ! Formulaire prêt.'),
              ],
            ),
            backgroundColor: Colors.teal,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        _resetForm();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppTheme.dangerColor),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // --- Build form data map ---
  Map<String, dynamic> _buildFormData() {
    return {
      'nom': _nomCtrl.text.trim(),
      'dci': _dciCtrl.text.trim().isNotEmpty ? _dciCtrl.text.trim() : null,
      'forme': _formeCtrl.text.trim().isNotEmpty ? _formeCtrl.text.trim() : null,
      'dosage': _dosageCtrl.text.trim().isNotEmpty ? _dosageCtrl.text.trim() : null,
      'lot': _lotCtrl.text.trim(),
      'fournisseur': _fournisseurCtrl.text.trim().isNotEmpty ? _fournisseurCtrl.text.trim() : null,
      'bon_livraison': _bonLivraisonCtrl.text.trim().isNotEmpty ? _bonLivraisonCtrl.text.trim() : null,
      'date_reception': _dateReceptionCtrl.text.trim().isNotEmpty ? _dateReceptionCtrl.text.trim() : null,
      'date_peremption': _datePeremptionCtrl.text.trim().isNotEmpty ? _datePeremptionCtrl.text.trim() : null,
      'nb_cartons': int.parse(_nbCartonsCtrl.text),
      'boites_par_carton': int.parse(_boitesParCartonCtrl.text),
      'plaquettes_par_boite': int.parse(_plaquettesParBoiteCtrl.text),
      'comprimes_par_plaquette': int.parse(_comprimesParPlaquetteCtrl.text),
      'prix_mode': _selectedMode.value,
      'achat_carton': double.parse(_achatCartonCtrl.text),
      'achat_boite': double.tryParse(_achatBoiteCtrl.text) ?? 0,
      'achat_plaquette': double.tryParse(_achatPlaquetteCtrl.text) ?? 0,
      'achat_comprime': double.tryParse(_achatComprimeCtrl.text) ?? 0,
      'vente_carton': double.tryParse(_venteCartonCtrl.text) ?? 0,
      'vente_boite': double.tryParse(_venteBoiteCtrl.text) ?? 0,
      'vente_plaquette': double.tryParse(_ventePlaquetteCtrl.text) ?? 0,
      'vente_comprime': double.tryParse(_venteComprimeCtrl.text) ?? 0,
      'marge_pct': double.tryParse(_margePctCtrl.text),
      'seuil_alerte': int.tryParse(_seuilAlerteCtrl.text) ?? 10,
      'seuil_niveau': _seuilNiveau,
      'alerte_peremption': _alertePeremption,
      'alerte_jours': _alertePeremption ? (int.tryParse(_alerteJoursCtrl.text) ?? 30) : null,
      'emplacement': _emplacementCtrl.text.trim().isNotEmpty ? _emplacementCtrl.text.trim() : null,
      'ordonnance': _ordonnance.value,
    };
  }

  // --- Autocomplete field builder for Forme, DCI, Dosage ---
  Widget _buildAutocompleteField({
    required TextEditingController controller,
    required String labelText,
    required String hintText,
    required List<String> suggestions,
  }) {
    return Autocomplete<String>(
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return suggestions; // Show all options when empty
        }
        return suggestions.where((s) =>
          s.toLowerCase().contains(textEditingValue.text.toLowerCase()));
      },
      onSelected: (String selection) {
        controller.text = selection;
      },
      optionsMaxHeight: 200,
      fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
        // Sync with our controller
        if (textController.text.isEmpty && controller.text.isNotEmpty) {
          textController.text = controller.text;
        }
        textController.addListener(() => controller.text = textController.text);
        return TextFormField(
          controller: textController,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: labelText,
            hintText: hintText,
            suffixIcon: const Icon(Icons.arrow_drop_down, size: 20),
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200, maxWidth: 300),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options.elementAt(index);
                  return InkWell(
                    onTap: () => onSelected(option),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Text(option, style: const TextStyle(fontSize: 13)),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFooter(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          const SizedBox(width: 12),
          // Save and continue (only in creation mode)
          if (widget.existing == null) ...[
            OutlinedButton.icon(
              onPressed: _isSubmitting ? null : _submitAndContinue,
              icon: const Icon(Icons.add_circle_outline, size: 18),
              label: const Text('Enregistrer et continuer'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.teal,
                side: const BorderSide(color: Colors.teal),
              ),
            ),
            const SizedBox(width: 12),
          ],
          ElevatedButton.icon(
            onPressed: _isSubmitting ? null : _submit,
            icon: _isSubmitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            label: Text(
              widget.existing != null ? 'Mettre à jour' : 'Enregistrer',
            ),
          ),
        ],
      ),
    );
  }
}
