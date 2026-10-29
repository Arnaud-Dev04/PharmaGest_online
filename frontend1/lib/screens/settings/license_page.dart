import 'package:flutter/material.dart';
import 'package:frontend1/services/api_service.dart';

class ClientLicensePage extends StatefulWidget {
  const ClientLicensePage({super.key});

  @override
  State<ClientLicensePage> createState() => _ClientLicensePageState();
}

class _ClientLicensePageState extends State<ClientLicensePage> {
  final ApiService _api = ApiService();
  final TextEditingController _keyController = TextEditingController();

  Map<String, dynamic>? _licenseStatus;
  List<Map<String, dynamic>> _history = [];
  bool _isLoading = true;
  bool _isRedeeming = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final statusRes = await _api.get('/license/status');
      final histRes = await _api.get('/license/history');
      if (mounted) {
        setState(() {
          _licenseStatus = Map<String, dynamic>.from(statusRes.data as Map);
          _history = (histRes.data as List<dynamic>)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _redeemKey() async {
    final key = _keyController.text.trim();
    if (key.isEmpty) return;

    setState(() => _isRedeeming = true);
    try {
      final res = await _api.post('/license/redeem', data: {'key': key});
      final data = res.data as Map<String, dynamic>;
      _keyController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message']?.toString() ?? 'Licence activée avec succès !'),
            backgroundColor: Colors.green,
          ),
        );
      }
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur d\'activation: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRedeeming = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Erreur: $_error', style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: const Text('Réessayer')),
          ],
        ),
      );
    }

    final daysRemaining = _licenseStatus?['days_remaining'] as int? ?? 0;
    final plan = _licenseStatus?['plan']?.toString().toUpperCase() ?? 'BASIC';
    final isValid = _licenseStatus?['is_valid'] as bool? ?? false;
    final maxUsers = _licenseStatus?['max_users'] ?? 3;
    final activeUsers = _licenseStatus?['active_users'] ?? 1;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion de la Licence Pharmacie'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isValid ? Icons.verified : Icons.warning_amber_rounded,
                              color: isValid ? Colors.green : Colors.orange,
                              size: 28,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Formule Actuelle : $plan',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ],
                        ),
                        Chip(
                          label: Text(isValid ? 'Actif' : 'Expiré'),
                          backgroundColor: isValid ? Colors.green[100] : Colors.red[100],
                          labelStyle: TextStyle(
                            color: isValid ? Colors.green[800] : Colors.red[800],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildKpiItem('Jours Restants', '$daysRemaining jours', Icons.timer),
                        _buildKpiItem('Utilisateurs Actifs', '$activeUsers / $maxUsers', Icons.people),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Redeem Key Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Renouveler ou Mettre Ã  Niveau la Licence',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Saisissez la clé de licence délivrée par l\'administrateur de la plateforme pour prolonger votre accès.',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _keyController,
                            decoration: const InputDecoration(
                              hintText: 'Exemple : PRO-A1B2-C3D4-365D',
                              prefixIcon: Icon(Icons.vpn_key),
                              border: OutlineInputBorder(),
                            ),
                            textCapitalization: TextCapitalization.characters,
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: _isRedeeming ? null : _redeemKey,
                            icon: _isRedeeming
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.check),
                            label: const Text('Activer la Clé'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // History Section
            Text(
              'Historique des Activations',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            if (_history.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Aucun historique d\'activation trouvé pour cette pharmacie.'),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _history.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, idx) {
                  final item = _history[idx];
                  return Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Colors.blueGrey,
                        child: Icon(Icons.history, color: Colors.white),
                      ),
                      title: Text(
                        'Clé : ${item['key']}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'Plan : ${item['plan']?.toString().toUpperCase()} â€¢ ${item['duration_days']} jours â€¢ Activé le : ${item['used_at']?.toString().substring(0, 10) ?? ""}',
                      ),
                      trailing: const Icon(Icons.verified, color: Colors.green),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiItem(String title, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.blueGrey),
        const SizedBox(height: 4),
        Text(title, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }
}

