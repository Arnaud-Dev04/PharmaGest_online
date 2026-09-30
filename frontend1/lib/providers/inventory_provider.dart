import 'package:flutter/foundation.dart';
import 'package:frontend1/services/dashboard_service.dart';

class InventoryProvider extends ChangeNotifier {
  final DashboardService _dashboardService = DashboardService();

  double totalPurchaseValue = 0.0;
  double totalSellValue = 0.0;
  bool loading = false;

  Future<void> loadTotals({int days = 7}) async {
    if (loading) return;
    loading = true;
    try {
      final stats = await _dashboardService.getDashboardStats(days);
      totalPurchaseValue = stats.totalPurchaseValue;
      totalSellValue = stats.totalSellValue;
      notifyListeners();
    } catch (e) {
      // ignore, keep previous values
    } finally {
      loading = false;
    }
  }
}
