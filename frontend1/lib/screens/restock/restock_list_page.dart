import 'package:flutter/material.dart';

import 'package:frontend1/models/restock.dart';
import 'package:frontend1/models/supplier.dart';
import 'package:frontend1/services/restock_service.dart';
import 'package:intl/intl.dart';
import 'restock_form_page.dart';

class RestockListPage extends StatefulWidget {
  final Supplier supplier;

  const RestockListPage({super.key, required this.supplier});

  @override
  State<RestockListPage> createState() => _RestockListPageState();
}

class _RestockListPageState extends State<RestockListPage> {
  final RestockService _restockService = RestockService();
  List<RestockOrder> _orders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() => _isLoading = true);
    try {
      final data = await _restockService.getOrders(
        supplierId: widget.supplier.id,
      );
      setState(() => _orders = data);
    } catch (e) {
      // Error handling via global interceptor
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmOrder(RestockOrder order) async {
    final confirm = await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Confirmer le réapprovisionnement"),
        content: const Text(
          "Cela mettra à jour le stock et les dates d'expiration. Continuer ?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text("Confirmer"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _restockService.confirmOrder(order.id);
        _loadOrders();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Commande confirmée et stock mis à jour"),
            ),
          );
        }
      } catch (e) {
        // Handled by interceptor
      }
    }
  }

  Future<void> _cancelOrder(RestockOrder order) async {
    // Logic similar to confirm
    try {
      await _restockService.cancelOrder(order.id);
      _loadOrders();
    } catch (e) {
      // Handled by interceptor
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Commandes - ${widget.supplier.name}"),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              final res = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RestockFormPage(supplier: widget.supplier),
                ),
              );
              if (res == true) _loadOrders();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _orders.length,
              itemBuilder: (context, index) {
                final order = _orders[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ExpansionTile(
                    leading: _buildStatusIcon(order.status),
                    title: Text(
                      "Commande #${order.id} - ${DateFormat('dd/MM/yyyy').format(order.date)}",
                    ),
                    subtitle: Text(
                      "${order.totalAmount} FBu - ${order.status.name.toUpperCase()}",
                    ),
                    children: [
                      ...order.items.map(
                        (item) => ListTile(
                          title: Text(item.medicineName),
                          subtitle: Text(
                            "${item.quantity} x ${item.priceBuy} FBu"
                                "${item.expiryDate != null ? " (Exp: ${DateFormat('dd/MM/yy').format(item.expiryDate!)})" : ""}",
                          ),
                          trailing: Text(
                            "${item.quantity * item.priceBuy} FBu",
                          ),
                        ),
                      ),
                      if (order.isDraft)
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () => _cancelOrder(order),
                                child: const Text(
                                  "Annuler",
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () => _confirmOrder(order),
                                child: const Text("Confirmer Réception"),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildStatusIcon(RestockStatus status) {
    switch (status) {
      case RestockStatus.draft:
        return const Icon(Icons.edit_note, color: Colors.orange);
      case RestockStatus.confirmed:
        return const Icon(Icons.check_circle, color: Colors.green);
      case RestockStatus.received:
        return const Icon(Icons.check_circle, color: Colors.green);
      case RestockStatus.cancelled:
        return const Icon(Icons.cancel, color: Colors.red);
    }
  }
}
