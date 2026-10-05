class ParsedFinancialMessage {
  final double amount;
  final bool isIncome;
  final String merchant;
  final String category;

  ParsedFinancialMessage({
    required this.amount,
    required this.isIncome,
    required this.merchant,
    required this.category,
  });
}

class SmsClassifier {
  static const _incomeWords = [
    'إيداع',
    'ايداع',
    'تم إيداع',
    'تم ايداع',
    'credited',
    'credit',
    'deposit',
    'salary',
    'راتب',
    'تحويل وارد',
  ];

  static const _debitWords = [
    'خصم',
    'سحب',
    'شراء',
    'دفع',
    'تم خصم',
    'debit',
    'purchase',
    'payment',
    'withdraw',
    'transaction',
  ];

  static final Map<String, String> merchantCategories = {
    'oman oil': 'وقود',
    'ooredoo': 'اتصالات',
    'omantel': 'اتصالات',
    'lulu': 'مشتريات',
    'lu lu': 'مشتريات',
    'carrefour': 'مشتريات',
    'nesto': 'مشتريات',
    'talabat': 'مطاعم',
    'mcdonald': 'مطاعم',
    'kfc': 'مطاعم',
    'starbucks': 'مطاعم',
    'shell': 'وقود',
    'al maha': 'وقود',
    'maha': 'وقود',
  };

  static ParsedFinancialMessage? parse(String body, String? sender) {
    final normalized = _normalize(body);

    final amount = _extractAmount(normalized);
    if (amount == null || amount <= 0) return null;

    final lower = normalized.toLowerCase();
    final isIncome = _incomeWords.any(lower.contains);

    final looksFinancial =
        isIncome || _debitWords.any(lower.contains);
    if (!looksFinancial) return null;

    final merchant = _extractMerchant(normalized, sender);
    final category = _classify('$merchant $normalized');

    return ParsedFinancialMessage(
      amount: amount,
      isIncome: isIncome,
      merchant: merchant,
      category: category,
    );
  }

  static String _normalize(String input) {
    const ar = '٠١٢٣٤٥٦٧٨٩';
    const en = '0123456789';
    var s = input;
    for (var i = 0; i < ar.length; i++) {
      s = s.replaceAll(ar[i], en[i]);
    }
    return s.replaceAll(',', '.').replaceAll('٬', '.');
  }

  static double? _extractAmount(String s) {
    final patterns = [
      RegExp(r'(?:OMR|ر\.?\s*ع|ريال\s*عماني)\s*([0-9]+(?:\.[0-9]{1,3})?)',
          caseSensitive: false),
      RegExp(r'(?:amount|amt|المبلغ|بقيمة|بمبلغ)\s*[:\-]?\s*([0-9]+(?:\.[0-9]{1,3})?)',
          caseSensitive: false),
      RegExp(r'([0-9]+(?:\.[0-9]{1,3})?)\s*(?:OMR|ر\.?\s*ع|ريال)',
          caseSensitive: false),
    ];

    for (final p in patterns) {
      final m = p.firstMatch(s);
      if (m != null) return double.tryParse(m.group(1)!);
    }

    final fallback = RegExp(r'(?<!\d)([0-9]+\.[0-9]{2,3})(?!\d)');
    final m = fallback.firstMatch(s);
    return m == null ? null : double.tryParse(m.group(1)!);
  }

  static String _extractMerchant(String s, String? sender) {
    final patterns = [
      RegExp(r'(?:لدى|من|عند|merchant|at)\s+([A-Za-z0-9\u0600-\u06FF&._ -]{2,40})',
          caseSensitive: false),
      RegExp(r'(?:from|to)\s+([A-Za-z0-9\u0600-\u06FF&._ -]{2,40})',
          caseSensitive: false),
    ];

    for (final p in patterns) {
      final m = p.firstMatch(s);
      if (m != null) {
        return m.group(1)!.trim().split(RegExp(r'\s+(?:بطاقة|card|رقم|ending)\b',
                caseSensitive: false))
            .first
            .trim();
      }
    }

    return (sender ?? 'عملية بنكية').trim();
  }

  static String _classify(String text) {
    final lower = text.toLowerCase();

    for (final entry in merchantCategories.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }

    if (lower.contains('fuel') ||
        lower.contains('petrol') ||
        lower.contains('وقود') ||
        lower.contains('محطة')) return 'وقود';

    if (lower.contains('restaurant') ||
        lower.contains('مطعم') ||
        lower.contains('cafe') ||
        lower.contains('مقهى')) return 'مطاعم';

    if (lower.contains('grocery') ||
        lower.contains('سوبر') ||
        lower.contains('بقالة')) return 'مشتريات';

    if (lower.contains('internet') ||
        lower.contains('اتصالات') ||
        lower.contains('mobile')) return 'اتصالات';

    return 'أخرى';
  }
}