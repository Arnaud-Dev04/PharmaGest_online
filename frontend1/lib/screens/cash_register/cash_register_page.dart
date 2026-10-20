import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:frontend1/providers/auth_provider.dart';
import 'package:frontend1/services/cash_register_service.dart';
import 'package:provider/provider.dart';

class CashRegisterPage extends StatefulWidget {
  const CashRegisterPage({super.key});

  @override
  State<CashRegisterPage> createState() => _CashRegisterPageState();
}

class _CashRegisterPageState extends State<CashRegisterPage> {
  final CashRegisterService _service = CashRegisterService();
  Map<String, dynamic>? _session;
  List<Map<String, dynamic>> _history = [];
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final cashier = context.read<AuthProvider>().user?.username ?? '';
      final currentSession = await _service.getCurrentSession(cashier: cashier);
      Map<String, dynamic>? sessions;
      try {
        sessions = await _service.getSessions(pageSize: 20);
      } catch (_) {
        // Keep the locally cached open session visible while the server is offline.
      }
      if (!mounted) return;
      final history = sessions?['items'] as List? ?? [];
      setState(() {
        _session = currentSession;
        _history = history
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = cashRegisterErrorMessage(error);
        _loading = false;
      });
    }
  }

  Future<void> _runAction(
    Future<Map<String, dynamic>> Function() action,
  ) async {
    setState(() => _busy = true);
    try {
      await action();
      await _refresh();
    } catch (error) {
      if (mounted) _showMessage(cashRegisterErrorMessage(error), isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : null,
      ),
    );
  }

  Future<void> _openSession() async {
    final amount = TextEditingController(text: '0');
    final notes = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ouvrir la caisse'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Fond de caisse'),
            ),
            TextField(
              controller: notes,
              decoration: const InputDecoration(
                labelText: 'Note (facultative)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ouvrir'),
          ),
        ],
      ),
    );
    if (accepted == true) {
      final value = double.tryParse(amount.text.replaceAll(',', '.'));
      if (value == null || value < 0) {
        _showMessage('Saisissez un montant valide.', isError: true);
      } else {
        await _runAction(
          () => _service.openSession(
            openingAmount: value,
            notes: notes.text,
            cashier: context.read<AuthProvider>().user?.username ?? '',
          ),
        );
      }
    }
    amount.dispose();
    notes.dispose();
  }

  Future<void> _addMovement(String type) async {
    final session = _session;
    if (session == null) return;
    final amount = TextEditingController();
    final reason = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          type == 'cash_in' ? 'Entrée d’espèces' : 'Sortie d’espèces',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Montant'),
            ),
            TextField(
              controller: reason,
              decoration: const InputDecoration(labelText: 'Motif'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    if (accepted == true) {
      final value = double.tryParse(amount.text.replaceAll(',', '.'));
      if (value == null || value <= 0 || reason.text.trim().length < 2) {
        _showMessage(
          'Vérifiez le montant et indiquez un motif.',
          isError: true,
        );
      } else {
        await _runAction(
          () => _service.addMovement(
            sessionId: session['id'] as int,
            movementType: type,
            amount: value,
            reason: reason.text,
            cashier: context.read<AuthProvider>().user?.username ?? '',
          ),
        );
      }
    }
    amount.dispose();
    reason.dispose();
  }

  Future<void> _closeSession([Map<String, dynamic>? targetSession]) async {
    final session = targetSession ?? _session;
    if (session == null || session['status'] != 'open') return;
    final amount = TextEditingController(
      text: _number(session['current_expected_amount']),
    );
    final notes = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clôturer la caisse'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Montant attendu : ${_money(session['current_expected_amount'])}',
            ),
            TextField(
              controller: amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Montant compté'),
            ),
            TextField(
              controller: notes,
              decoration: const InputDecoration(
                labelText: 'Note (facultative)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clôturer'),
          ),
        ],
      ),
    );
    if (accepted == true) {
      final value = double.tryParse(amount.text.replaceAll(',', '.'));
      if (value == null || value < 0) {
        _showMessage('Saisissez un montant valide.', isError: true);
      } else {
        await _runAction(
          () => _service.closeSession(
            sessionId: session['id'] as int,
            countedAmount: value,
            notes: notes.text,
            cashier: context.read<AuthProvider>().user?.username ?? '',
          ),
        );
      }
    }
    amount.dispose();
    notes.dispose();
  }

  static String _number(dynamic value) =>
      (value is num ? value : num.tryParse(value?.toString() ?? '') ?? 0)
          .toStringAsFixed(2);

  static String _money(dynamic value) => '${_number(value)} FBu';

  static String _date(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    return date == null ? '—' : DateFormat('dd/MM/yyyy HH:mm').format(date);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final session = _session;
    final role = context.watch<AuthProvider>().user?.role.toLowerCase();
    final isAdmin = role == 'admin' || role == 'super_admin';
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(8),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Gestion de caisse',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                onPressed: _refresh,
                tooltip: 'Actualiser',
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          if (_error != null)
            Card(
              color: Colors.red.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _error!,
                  style: TextStyle(color: Colors.red.shade900),
                ),
              ),
            ),
          if (session == null) ...[
            const Card(
              child: ListTile(
                leading: Icon(Icons.point_of_sale),
                title: Text('Aucune session ouverte'),
                subtitle: Text(
                  'Ouvrez votre caisse avant d’effectuer un paiement en espèces.',
                ),
              ),
            ),
            FilledButton.icon(
              onPressed: _busy ? null : _openSession,
              icon: const Icon(Icons.lock_open),
              label: const Text('Ouvrir une session'),
            ),
          ] else ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.point_of_sale, color: Colors.green),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Session ouverte',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Chip(
                          label: Text(
                            session['sync_status'] == 'synced'
                                ? 'Synchronisée'
                                : 'En attente de sync',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Ouverte : ${_date(session['opened_at'])}'),
                    Text('Fond initial : ${_money(session['opening_amount'])}'),
                    const Divider(height: 24),
                    _totalRow('Ventes espèces', session['cash_sales_total']),
                    _totalRow('Entrées', session['cash_in_total']),
                    _totalRow(
                      'Sorties',
                      session['cash_out_total'],
                      subtract: true,
                    ),
                    const Divider(),
                    _totalRow(
                      'Montant attendu',
                      session['current_expected_amount'],
                      prominent: true,
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _busy
                              ? null
                              : () => _addMovement('cash_in'),
                          icon: const Icon(Icons.add),
                          label: const Text('Entrée'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _busy
                              ? null
                              : () => _addMovement('cash_out'),
                          icon: const Icon(Icons.remove),
                          label: const Text('Sortie'),
                        ),
                        FilledButton.icon(
                          onPressed: _busy ? null : _closeSession,
                          icon: const Icon(Icons.lock),
                          label: const Text('Clôturer'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 12, bottom: 4),
              child: Text(
                'Mouvements de la session',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ...((session['movements'] as List? ?? []).map((item) {
              final movement = Map<String, dynamic>.from(item as Map);
              final incoming = movement['movement_type'] == 'cash_in';
              return ListTile(
                leading: Icon(
                  incoming ? Icons.south_west : Icons.north_east,
                  color: incoming ? Colors.green : Colors.deepOrange,
                ),
                title: Text(movement['reason']?.toString() ?? ''),
                subtitle: Text(_date(movement['occurred_at'])),
                trailing: Text(
                  '${incoming ? '+' : '-'}${_money(movement['amount'])}',
                ),
              );
            })),
          ],
          const Padding(
            padding: EdgeInsets.only(top: 20, bottom: 4),
            child: Text(
              'Sessions récentes',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          if (_history.isEmpty)
            const ListTile(title: Text('Aucune session enregistrée'))
          else
            ..._history.map(
              (item) => Card(
                child: ListTile(
                  leading: Icon(
                    item['status'] == 'open'
                        ? Icons.lock_open
                        : Icons.lock_outline,
                  ),
                  title: Text(
                    '${item['cashier_username'] ?? ''} · ${_money(item['expected_amount'] ?? item['current_expected_amount'])}',
                  ),
                  subtitle: Text(
                    '${_date(item['opened_at'])} · ${item['status'] == 'open' ? 'Ouverte' : 'Clôturée'}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (item['variance'] != null)
                        Text('Écart ${_money(item['variance'])}'),
                      if (isAdmin && item['status'] == 'open')
                        IconButton(
                          tooltip: 'Clôturer cette caisse',
                          onPressed: _busy ? null : () => _closeSession(item),
                          icon: const Icon(Icons.lock),
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _totalRow(
    String label,
    dynamic value, {
    bool subtract = false,
    bool prominent = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontWeight: prominent ? FontWeight.bold : null),
            ),
          ),
          Text(
            '${subtract ? '−' : ''}${_money(value)}',
            style: TextStyle(
              fontWeight: prominent ? FontWeight.bold : null,
              fontSize: prominent ? 18 : null,
            ),
          ),
        ],
      ),
    );
  }
}
