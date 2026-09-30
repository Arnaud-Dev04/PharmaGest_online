import 'package:flutter/material.dart';
import 'package:data_table_2/data_table_2.dart';

import 'package:frontend1/core/theme.dart';
import 'package:frontend1/screens/restock/restock_list_page.dart'; // Import
import 'package:frontend1/models/supplier.dart';
import 'package:frontend1/services/supplier_service.dart';
import 'package:frontend1/widgets/suppliers/supplier_form_dialog.dart';
import 'package:frontend1/providers/language_provider.dart';
import 'package:provider/provider.dart';
import 'package:frontend1/core/error_helper.dart';

class SuppliersPage extends StatefulWidget {
  const SuppliersPage({super.key});

  @override
  State<SuppliersPage> createState() => _SuppliersPageState();
}

class _SuppliersPageState extends State<SuppliersPage> {
  final SupplierService _supplierService = SupplierService();

  List<Supplier> _suppliers = [];
  bool _isLoading = false;
  String? _error;
  int _currentPage = 1;
  int _totalPages = 1;

  @override
  void initState() {
    super.initState();
    _loadSuppliers();
  }

  Future<void> _loadSuppliers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _supplierService.getSuppliers(page: _currentPage);
      setState(() {
        _suppliers = response.items;
        _totalPages = response.totalPages;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = ErrorHelper.extractErrorMessage(e);
        _isLoading = false;
      });
    }
  }

  Future<void> _showDialog({Supplier? supplier}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => SupplierFormDialog(supplier: supplier),
    );
    if (result == true) _loadSuppliers();
  }

  Future<void> _deleteSupplier(Supplier supplier) async {
    final lp = Provider.of<LanguageProvider>(context, listen: false);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(lp.translate('confirmation')),
        content: Text('${lp.translate('delete')} ${supplier.name} ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(lp.translate('no')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(lp.translate('yes')),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _supplierService.deleteSupplier(supplier.id);
        _loadSuppliers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(lp.translate('supplierDeleted'))),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${lp.translate('error')}: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    // Si on veut rester fidèle au Scroll handling du MainLayout (qui n'a plus de scroll global),
    // SuppliersPage doit remplir l'espace.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  languageProvider.translate('suppliers'),
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  languageProvider.translate('manageSuppliersDescription') ==
                          'manageSuppliersDescription'
                      ? 'Gestion de vos fournisseurs'
                      : languageProvider.translate(
                          'manageSuppliersDescription',
                        ),
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                ),
              ],
            ),
            ElevatedButton.icon(
              onPressed: () => _showDialog(),
              icon: const Icon(Icons.add),
              label: Text(languageProvider.translate('addSupplier')),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Table Card
        Expanded(
          child: Card(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                    child: Text(
                      'Erreur: $_error',
                      style: const TextStyle(color: Colors.red),
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      // Desktop View
                      if (constraints.maxWidth > 800) {
                        return Column(
                          children: [
                            Expanded(
                              child: DataTable2(
                                columnSpacing: 12,
                                horizontalMargin: 12,
                                minWidth: 800,
                                columns: [
                                  DataColumn2(
                                    label: Text(
                                      languageProvider.translate('name'),
                                    ),
                                  ),
                                  DataColumn2(
                                    label: Text(
                                      languageProvider.translate('contact'),
                                    ),
                                  ),
                                  DataColumn2(
                                    label: Text(
                                      languageProvider.translate('phone'),
                                    ),
                                  ),
                                  DataColumn2(
                                    label: Text(
                                      languageProvider.translate('email'),
                                    ),
                                  ),
                                  DataColumn2(
                                    label: Text(
                                      languageProvider.translate('address'),
                                    ),
                                    size: ColumnSize.L,
                                  ),
                                  DataColumn2(
                                    label: Text(
                                      languageProvider.translate('actions'),
                                    ),
                                    fixedWidth: 100,
                                  ),
                                ],
                                rows: _suppliers
                                    .map(
                                      (s) => DataRow(
                                        cells: [
                                          DataCell(
                                            Text(
                                              s.name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          DataCell(Text(s.contact)),
                                          DataCell(Text(s.phone)),
                                          DataCell(Text(s.email)),
                                          DataCell(
                                            Text(
                                              s.address,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          DataCell(
                                            Row(
                                              children: [
                                                IconButton(
                                                  icon: const Icon(
                                                    Icons.shopping_cart,
                                                    size: 18,
                                                    color: Colors.blue,
                                                  ),
                                                  onPressed: () =>
                                                      Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder: (_) =>
                                                              RestockListPage(
                                                                supplier: s,
                                                              ),
                                                        ),
                                                      ),
                                                  tooltip: languageProvider
                                                      .translate('orders'),
                                                ),
                                                IconButton(
                                                  icon: const Icon(
                                                    Icons.edit,
                                                    size: 18,
                                                    color:
                                                        AppTheme.primaryColor,
                                                  ),
                                                  onPressed: () =>
                                                      _showDialog(supplier: s),
                                                ),
                                                IconButton(
                                                  icon: const Icon(
                                                    Icons.delete,
                                                    size: 18,
                                                    color: AppTheme.dangerColor,
                                                  ),
                                                  onPressed: () =>
                                                      _deleteSupplier(s),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                            // Pagination
                            if (_totalPages > 1)
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.chevron_left),
                                      onPressed: _currentPage > 1
                                          ? () {
                                              _currentPage--;
                                              _loadSuppliers();
                                            }
                                          : null,
                                    ),
                                    Text('Page $_currentPage / $_totalPages'),
                                    IconButton(
                                      icon: const Icon(Icons.chevron_right),
                                      onPressed: _currentPage < _totalPages
                                          ? () {
                                              _currentPage++;
                                              _loadSuppliers();
                                            }
                                          : null,
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        );
                      }

                      // Mobile/Tablet View (List)
                      return ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: _suppliers.length,
                        itemBuilder: (context, index) {
                          final s = _suppliers[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text(
                                s.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (s.contact.isNotEmpty)
                                    Text('Contact: ${s.contact}'),
                                  if (s.phone.isNotEmpty)
                                    Text('Tel: ${s.phone}'),
                                  if (s.email.isNotEmpty)
                                    Text('Email: ${s.email}'),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.shopping_cart,
                                      color: Colors.blue,
                                    ),
                                    onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            RestockListPage(supplier: s),
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.edit,
                                      color: AppTheme.primaryColor,
                                    ),
                                    onPressed: () => _showDialog(supplier: s),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      color: AppTheme.dangerColor,
                                    ),
                                    onPressed: () => _deleteSupplier(s),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}
