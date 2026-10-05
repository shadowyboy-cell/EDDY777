import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models.dart';
import 'classifier.dart';
import 'database_service.dart';

class SmsSyncResult {
  final int added;
  final int skipped;
  final int unreadable;

  SmsSyncResult(this.added, this.skipped, this.unreadable);
}

class SmsService {
  final SmsQuery _query = SmsQuery();

  Future<bool> requestPermission() async {
    final status = await Permission.sms.request();
    return status.isGranted;
  }

  Future<SmsSyncResult> sync() async {
    final granted = await requestPermission();
    if (!granted) {
      throw Exception('لم يتم السماح للتطبيق بقراءة الرسائل النصية.');
    }

    final messages = await _query.querySms(
      kinds: [SmsQueryKind.inbox],
      count: 200,
    );

    var added = 0;
    var skipped = 0;
    var unreadable = 0;

    for (final message in messages) {
      final id = '${message.id ?? ''}_${message.date?.millisecondsSinceEpoch ?? 0}';
      if (id == '_0' || await DatabaseService.instance.smsExists(id)) {
        skipped++;
        continue;
      }

      final parsed = SmsClassifier.parse(
        message.body ?? '',
        message.sender,
      );

      if (parsed == null) {
        unreadable++;
        continue;
      }

      await DatabaseService.instance.addTransaction(
        TransactionModel(
          title: parsed.merchant,
          category: parsed.category,
          amount: parsed.amount,
          isIncome: parsed.isIncome,
          date: message.date ?? DateTime.now(),
          source: 'sms',
          smsId: id,
        ),
      );

      added++;
    }

    return SmsSyncResult(added, skipped, unreadable);
  }
}