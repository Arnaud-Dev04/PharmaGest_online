import 'package:flutter/material.dart';
import 'package:frontend1/models/customer_model.dart';
import 'package:frontend1/services/customer_service.dart';

class CustomerSearchField extends StatelessWidget {
  final Function(Customer) onSelected;
  final CustomerService _customerService = CustomerService();

  CustomerSearchField({super.key, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Autocomplete<Customer>(
      displayStringForOption: (Customer option) =>
          '${option.firstName} ${option.lastName} (${option.phone})',
      optionsBuilder: (TextEditingValue textEditingValue) async {
        if (textEditingValue.text.length < 2) {
          return const Iterable<Customer>.empty();
        }
        final results = await _customerService.searchCustomers(
          textEditingValue.text,
        );
        return results.map((json) => Customer.fromJson(json)).toList();
      },
      onSelected: onSelected,
      fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          onEditingComplete: onEditingComplete,
          decoration: InputDecoration(
            hintText: 'Rechercher client (Nom/Tél)',
            prefixIcon: const Icon(Icons.search, color: Colors.grey),
            isDense: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 8,
            ),
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            child: SizedBox(
              width: 300, // Fixed width or dynamic based on parent constraint
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (BuildContext context, int index) {
                  final Customer option = options.elementAt(index);
                  return ListTile(
                    title: Text('${option.firstName} ${option.lastName}'),
                    subtitle: Text(
                      '${option.phone} • Pts: ${option.totalPoints}',
                    ),
                    onTap: () {
                      onSelected(option);
                    },
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
