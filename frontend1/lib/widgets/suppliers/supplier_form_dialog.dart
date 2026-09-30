import 'package:flutter/material.dart';
import 'package:frontend1/core/theme.dart';
import 'package:frontend1/models/supplier.dart';
import 'package:frontend1/services/supplier_service.dart';

class SupplierFormDialog extends StatefulWidget {
  final Supplier? supplier;

  const SupplierFormDialog({super.key, this.supplier});

  @override
  State<SupplierFormDialog> createState() => _SupplierFormDialogState();
}

class _SupplierFormDialogState extends State<SupplierFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  
  bool _isLoading = false;
  final SupplierService _supplierService = SupplierService();

  @override
  void initState() {
    super.initState();
    if (widget.supplier != null) {
      _nameCtrl.text = widget.supplier!.name;
      _contactCtrl.text = widget.supplier!.contact;
      _phoneCtrl.text = widget.supplier!.phone;
      _emailCtrl.text = widget.supplier!.email;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _contactCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      // Envoyer null pour les champs optionnels vides (EmailStr rejette "")
      final data = {
        'name': _nameCtrl.text.trim(),
        'contact_name': _contactCtrl.text.trim().isEmpty ? null : _contactCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        'email': _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
      };

      if (widget.supplier == null) {
        await _supplierService.createSupplier(data);
      } else {
        await _supplierService.updateSupplier(widget.supplier!.id, data);
      }

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.supplier == null ? 'Fournisseur ajouté' : 'Fournisseur modifié'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppTheme.dangerColor),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.supplier != null;
    return AlertDialog(
      title: Text(isEdit ? 'Modifier Fournisseur' : 'Nouveau Fournisseur'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildInput('Nom *', _nameCtrl, required: true),
              _buildInput('Personne de contact', _contactCtrl),
              _buildInput('Téléphone', _phoneCtrl, type: TextInputType.phone),
              _buildInput('Email (optionnel)', _emailCtrl, type: TextInputType.emailAddress),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading 
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : Text(isEdit ? 'Enregistrer' : 'Créer'),
        ),
      ],
    );
  }

  Widget _buildInput(String label, TextEditingController ctrl, {
    bool required = false,
    TextInputType type = TextInputType.text,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: ctrl,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: const OutlineInputBorder(),
        ),
        keyboardType: type,
        maxLines: maxLines,
        validator: required ? (v) => v == null || v.isEmpty ? 'Champ requis' : null : null,
      ),
    );
  }
}
