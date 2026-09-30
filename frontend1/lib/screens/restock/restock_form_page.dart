import 'package:flutter/material.dart';
import 'package:frontend1/models/supplier.dart';
import 'package:frontend1/models/medicine.dart';
import 'package:frontend1/services/stock_service.dart';
import 'package:frontend1/services/restock_service.dart';
import 'package:intl/intl.dart';

class RestockFormPage extends StatefulWidget {
  final Supplier supplier;
  const RestockFormPage({super.key, required this.supplier});

  @override
  State<RestockFormPage> createState() => _RestockFormPageState();
}

class _RestockFormPageState extends State<RestockFormPage> {
  final StockService _stockService = StockService();
  final RestockService _restockService = RestockService();

  List<Medicine> _allMedicines = [];
  final List<Map<String, dynamic>> _cartItems = []; // {medicine, qty, price, expiry}

  Medicine? _selectedMedicine;
  final TextEditingController _qtyCtrl = TextEditingController();
  final TextEditingController _priceCtrl = TextEditingController();
  DateTime? _selectedExpiryDate;

  @override
  void initState() {
    super.initState();
    _loadMedicines();
  }

  Future<void> _loadMedicines() async {
    // Load all medicines for dropdown (simplified)
    final res = await _stockService.getMedicines(page: 1, limit: 1000);
    setState(() => _allMedicines = res.items);
  }

  void _addItem() {
    if (_selectedMedicine == null ||
        _qtyCtrl.text.isEmpty ||
        _priceCtrl.text.isEmpty) {
      return;
    }

    setState(() {
      _cartItems.add({
        'medicine': _selectedMedicine,
        'quantity': int.parse(_qtyCtrl.text),
        'price_buy': double.parse(_priceCtrl.text),
        'expiry_date': _selectedExpiryDate, // THE NEW FIELD
      });
      // Reset form
      _selectedMedicine = null;
      _qtyCtrl.clear();
      _priceCtrl.clear();
      _selectedExpiryDate = null;
    });
  }

  Future<void> _submitOrder() async {
    if (_cartItems.isEmpty) return;

    final orderData = {
      'supplier_id': widget.supplier.id,
      'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      'items': _cartItems
          .map(
            (item) => {
              'medicine_id': (item['medicine'] as Medicine).id,
              'quantity': item['quantity'],
              'price_buy': item['price_buy'],
              'expiry_date': item['expiry_date'] != null
                  ? DateFormat('yyyy-MM-dd').format(item['expiry_date'])
                  : null,
            },
          )
          .toList(),
    };

    try {
      await _restockService.createOrder(orderData);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Commande créée")));
        Navigator.pop(context, true);
      }
    } catch (e) {
      // Interceptor handles error
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Nouvelle Commande")),
      body: Row(
        children: [
          // Left: Form
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Fournisseur: ${widget.supplier.name}",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Medicine Dropdown
                  DropdownButtonFormField<Medicine>(
                    key: ValueKey(_selectedMedicine),
                    initialValue: _selectedMedicine,
                    decoration: const InputDecoration(labelText: "Médicament"),
                    items: _allMedicines
                        .map(
                          (m) => DropdownMenuItem(
                            value: m,
                            child: Text("${m.name} (Stock: ${m.quantity})"),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedMedicine = val;
                        if (val != null) {
                          _priceCtrl.text = val.priceBuy.toString();
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _qtyCtrl,
                          decoration: const InputDecoration(
                            labelText: "Quantité",
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _priceCtrl,
                          decoration: const InputDecoration(
                            labelText: "Prix Achat",
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // --- EXPIRY DATE PICKER ---
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now().add(
                          const Duration(days: 365),
                        ),
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2050),
                      );
                      if (picked != null) {
                        setState(() => _selectedExpiryDate = picked);
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: "Nouvelle Date d'Expiration (Optionnel)",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.calendar_today),
                      ),
                      child: Text(
                        _selectedExpiryDate == null
                            ? "Sélectionner une date..."
                            : DateFormat(
                                'dd/MM/yyyy',
                              ).format(_selectedExpiryDate!),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _addItem,
                      icon: const Icon(Icons.add_shopping_cart),
                      label: const Text("Ajouter au panier"),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const VerticalDivider(width: 1),
          // Right: Cart
          Expanded(
            flex: 6,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.grey[100],
                  width: double.infinity,
                  child: const Text(
                    "Articles à commander",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _cartItems.length,
                    itemBuilder: (context, index) {
                      final item = _cartItems[index];
                      final med = item['medicine'] as Medicine;
                      return ListTile(
                        title: Text(med.name),
                        subtitle: Text(
                          "Exp: ${item['expiry_date'] != null ? DateFormat('dd/MM/yyyy').format(item['expiry_date']) : 'Inchangée'}",
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "${item['quantity']}x = ${item['quantity'] * item['price_buy']} F",
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              onPressed: () =>
                                  setState(() => _cartItems.removeAt(index)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    onPressed: _submitOrder,
                    child: const Text(
                      "Valider la commande",
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
