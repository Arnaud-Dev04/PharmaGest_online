import 'package:flutter/material.dart';
import 'package:frontend1/widgets/pos/cart_panel.dart';
import 'package:frontend1/widgets/pos/product_grid.dart';

class POSPage extends StatelessWidget {
  const POSPage({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Desktop View
        if (constraints.maxWidth > 900) {
          return const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 4,
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: ProductGrid(),
                ),
              ),
              SizedBox(
                width: 380,
                height: double.infinity,
                child: CartPanel(),
              ),
            ],
          );
        }

        // Mobile/Tablet View
        return Scaffold(
          body: const Padding(
            padding: EdgeInsets.all(8.0),
            child: ProductGrid(),
          ),
          floatingActionButton: Builder(
            builder: (context) {
              return FloatingActionButton.extended(
                onPressed: () {
                  Scaffold.of(context).openEndDrawer();
                },
                icon: const Icon(Icons.shopping_cart),
                label: const Text('Panier'),
              );
            },
          ),
          endDrawer: const Drawer(width: 350, child: CartPanel()),
        );
      },
    );
  }
}
