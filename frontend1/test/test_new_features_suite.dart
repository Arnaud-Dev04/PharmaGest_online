import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend1/models/navigation_item.dart';
import 'package:frontend1/models/user.dart';
import 'package:frontend1/widgets/dashboard/stats_card.dart';

void main() {
  group('1. Tests Navigation & Rôles (RBAC Sidebar)', () {
    test('Platform Admin ne voit que les modules de plateforme', () {
      final items = NavigationItems.filterByRole('platform_admin');
      expect(items.any((i) => i.route == '/platform-admin'), isTrue);
      expect(items.any((i) => i.route == '/pos'), isFalse);
      expect(items.any((i) => i.route == '/stock'), isFalse);
    });

    test('Admin de Pharmacie voit les nouveaux onglets Analyse et Licence', () {
      final items = NavigationItems.filterByRole('admin');
      expect(items.any((i) => i.route == '/analyse'), isTrue);
      expect(items.any((i) => i.route == '/license'), isTrue);
      expect(items.any((i) => i.route == '/pos'), isTrue);
      expect(items.any((i) => i.route == '/users'), isTrue);
      expect(items.any((i) => i.route == '/platform-admin'), isFalse);
    });

    test(
      'Pharmacien / Caissier a un accès restreint (pas d\'accès Analyse/Licence/Users)',
      () {
        final items = NavigationItems.filterByRole('pharmacist');
        expect(items.any((i) => i.route == '/analyse'), isFalse);
        expect(items.any((i) => i.route == '/license'), isFalse);
        expect(items.any((i) => i.route == '/users'), isFalse);
        expect(items.any((i) => i.route == '/pos'), isTrue);
      },
    );
  });

  group('2. Tests Modèle Utilisateur & Permissions Granulaires', () {
    test('Désérialisation JSON de User avec allowed_features', () {
      final jsonMap = {
        'id': 42,
        'username': 'caissier_pierre',
        'role': 'pharmacist',
        'is_active': true,
        'allowed_features': ['pos', 'stock'],
      };

      final user = User.fromJson(jsonMap);
      expect(user.username, equals('caissier_pierre'));
      expect(user.role, equals('pharmacist'));
      expect(user.allowedFeatures, containsAll(['pos', 'stock']));
      expect(user.isAdmin, isFalse);
    });
  });

  group('3. Tests Widgets Dashboard (Taille réduite & Rendu StatsCard)', () {
    testWidgets(
      'StatsCard s\'affiche correctement avec le nouveau format compact',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: StatsCard(
                icon: Icons.medication,
                label: 'Total Médicaments',
                value: '1 250',
                iconBgColor: Colors.blue,
              ),
            ),
          ),
        );

        // Vérifier la présence du label et de la valeur
        expect(find.text('Total Médicaments'), findsOneWidget);
        expect(find.text('1 250'), findsOneWidget);
        expect(find.byIcon(Icons.medication), findsOneWidget);
      },
    );
  });
}
