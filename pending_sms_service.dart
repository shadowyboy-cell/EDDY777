import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models.dart';
import 'database_service.dart';
import 'notification_service.dart';

class PendingSmsService {
  static Future<int> process() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('pending_sms');
    if (raw == null || raw.trim().isEmpty) return 0;

    final decoded = jsonDecode(raw);
    if (decoded is! List) return 0;

    final remaining = <Map<String, dynamic>>[];
    var added = 0;
    var balanceDelta = 0.0;

    for (final item in decoded) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final smsId = map['smsId']?.toString();
      if (smsId == null || smsId.isEmpty) continue;

      if (await DatabaseService.instance.smsExists(smsId)) continue;

      try {
        await DatabaseService.instance.addTransaction(
          TransactionModel(
            title: map['title']?.toString() ?? 'عملية بنكية',
            category: map['category']?.toString() ?? 'أخرى',
            amount: (map['amount'] as num).toDouble(),
            isIncome: map['isIncome'] == true,
            date: DateTime.fromMillisecondsSinceEpoch(
              (map['date'] as num).toInt(),
            ),
            source: 'sms_auto',
            smsId: smsId,
          ),
        );
        added++;
        final amount = (map['amount'] as num).toDouble();
        balanceDelta += map['isIncome'] == true ? amount : -amount;
      } catch (_) {
        // Keep failed items for the next app launch.
        remaining.add(map);
      }
    }

    await prefs.setString('pending_sms', jsonEncode(remaining));

    if (added > 0) {
      final transactions = await DatabaseService.instance.getTransactions();
      final totalIncome = transactions
          .where((t) => t.isIncome)
          .fold<double>(0, (s, t) => s + t.amount);
      final totalExpense = transactions
          .where((t) => !t.isIncome)
          .fold<double>(0, (s, t) => s + t.amount);
      final existingBalance = prefs.getDouble('manual_balance');
      final balance = (existingBalance ?? (totalIncome - totalExpense)) +
          (existingBalance == null ? 0 : balanceDelta);
      final threshold = prefs.getDouble('low_balance_threshold') ?? 50.0;
      await prefs.setDouble('manual_balance', balance);
      if (balance < threshold) {
        await NotificationService.instance.lowBalance(balance, threshold);
      }
    }

    return added;
  }
}
