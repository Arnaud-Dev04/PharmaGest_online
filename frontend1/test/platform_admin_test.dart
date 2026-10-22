import 'package:flutter_test/flutter_test.dart';
import 'package:frontend1/models/navigation_item.dart';
import 'package:frontend1/models/pharmacy.dart';
import 'package:frontend1/services/platform_admin_service.dart';

void main() {
  test('platform admin only sees platform navigation', () {
    final routes = NavigationItems.filterByRole(
      'platform_admin',
    ).map((item) => item.route).toList();

    expect(routes, ['/platform-admin']);
  });

  test('pharmacy super admin cannot see platform navigation', () {
    final routes = NavigationItems.filterByRole(
      'super_admin',
    ).map((item) => item.route).toList();

    expect(routes, isNot(contains('/platform-admin')));
    expect(routes, contains('/super-admin'));
  });

  test('pharmacy page parses server pagination metadata', () {
    final page = PharmacyPage.fromJson({
      'items': [
        {
          'id': 7,
          'name': 'Pharmacie Test',
          'code': 'PHARMA-7',
          'is_active': true,
          'plan': 'pro',
          'max_users': 10,
        },
      ],
      'total': 51,
      'page': 3,
      'page_size': 25,
      'total_pages': 3,
    });

    expect(page.items, hasLength(1));
    expect(page.items.single.id, 7);
    expect(page.total, 51);
    expect(page.page, 3);
    expect(page.pageSize, 25);
    expect(page.totalPages, 3);
  });

  test(
    'platform account parses role and forced password change without secrets',
    () {
      final account = PlatformAccount.fromJson({
        'id': 12,
        'username': 'pharmacy_admin',
        'role': 'admin',
        'is_active': true,
        'must_change_password': true,
        'pharmacy_id': 7,
        'pharmacy_name': 'Pharmacie Test',
      });

      expect(account.id, 12);
      expect(account.username, 'pharmacy_admin');
      expect(account.role, 'admin');
      expect(account.isActive, isTrue);
      expect(account.mustChangePassword, isTrue);
      expect(account.pharmacyName, 'Pharmacie Test');
    },
  );
}
