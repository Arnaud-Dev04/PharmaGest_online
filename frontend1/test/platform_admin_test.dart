import 'package:flutter_test/flutter_test.dart';
import 'package:frontend1/models/navigation_item.dart';
import 'package:frontend1/models/pharmacy.dart';

void main() {
  test('platform admin only sees platform navigation', () {
    final routes = NavigationItems.filterByRole('platform_admin')
        .map((item) => item.route)
        .toList();

    expect(routes, ['/platform-admin']);
  });

  test('pharmacy super admin cannot see platform navigation', () {
    final routes = NavigationItems.filterByRole('super_admin')
        .map((item) => item.route)
        .toList();

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
}