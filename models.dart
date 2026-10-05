class TransactionModel {
  final int? id;
  final String title;
  final String category;
  final double amount;
  final bool isIncome;
  final DateTime date;
  final String source;
  final String? smsId;

  TransactionModel({
    this.id,
    required this.title,
    required this.category,
    required this.amount,
    required this.isIncome,
    required this.date,
    this.source = 'manual',
    this.smsId,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'category': category,
        'amount': amount,
        'is_income': isIncome ? 1 : 0,
        'date': date.millisecondsSinceEpoch,
        'source': source,
        'sms_id': smsId,
      };

  factory TransactionModel.fromMap(Map<String, dynamic> m) =>
      TransactionModel(
        id: m['id'] as int?,
        title: m['title'] as String,
        category: m['category'] as String,
        amount: (m['amount'] as num).toDouble(),
        isIncome: (m['is_income'] as int) == 1,
        date: DateTime.fromMillisecondsSinceEpoch(m['date'] as int),
        source: (m['source'] as String?) ?? 'manual',
        smsId: m['sms_id'] as String?,
      );
}

class NeedModel {
  final int? id;
  final String name;
  final String category;
  final bool done;

  NeedModel({
    this.id,
    required this.name,
    this.category = 'أخرى',
    this.done = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'category': category,
        'done': done ? 1 : 0,
      };

  factory NeedModel.fromMap(Map<String, dynamic> m) => NeedModel(
        id: m['id'] as int?,
        name: m['name'] as String,
        category: (m['category'] as String?) ?? 'أخرى',
        done: (m['done'] as int) == 1,
      );
}

class PriceCheckModel {
  final int? id;
  final String product;
  final String source;
  final double price;
  final String store;
  final String url;
  final DateTime checkedAt;

  PriceCheckModel({
    this.id,
    required this.product,
    required this.source,
    required this.price,
    required this.store,
    required this.url,
    required this.checkedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'product': product,
        'source': source,
        'price': price,
        'store': store,
        'url': url,
        'checked_at': checkedAt.millisecondsSinceEpoch,
      };

  factory PriceCheckModel.fromMap(Map<String, dynamic> m) => PriceCheckModel(
        id: m['id'] as int?,
        product: m['product'] as String,
        source: m['source'] as String,
        price: (m['price'] as num).toDouble(),
        store: m['store'] as String,
        url: m['url'] as String,
        checkedAt: DateTime.fromMillisecondsSinceEpoch(m['checked_at'] as int),
      );
}