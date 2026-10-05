import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../services/sms_service.dart';
import 'shopping_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int tab = 0;
  bool loading = true;
  bool syncing = false;

  double balance = 0;
  double income = 0;
  double threshold = 50;

  List<TransactionModel> transactions = [];
  List<NeedModel> needs = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final all = await DatabaseService.instance.getTransactions();
    final currentMonth =
        all.where((t) => t.date.month == DateTime.now().month &&
            t.date.year == DateTime.now().year).toList();

    final totalIncome = all
        .where((t) => t.isIncome)
        .fold<double>(0, (s, t) => s + t.amount);
    final totalExpense = all
        .where((t) => !t.isIncome)
        .fold<double>(0, (s, t) => s + t.amount);

    setState(() {
      balance = prefs.getDouble('manual_balance') ??
          (totalIncome - totalExpense);
      income = currentMonth
          .where((t) => t.isIncome)
          .fold<double>(0, (s, t) => s + t.amount);
      threshold = prefs.getDouble('low_balance_threshold') ?? 50;
      transactions = all;
      loading = false;
    });

    needs = await DatabaseService.instance.getNeeds();
    if (mounted) setState(() {});
  }

  Future<void> syncSms() async {
    setState(() => syncing = true);

    try {
      final result = await SmsService().sync();
      await load();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تمت المزامنة: ${result.added} عملية جديدة، '
            '${result.skipped} مكررة.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => syncing = false);
    }
  }

  Future<void> addExpense() async {
    final title = TextEditingController();
    final amount = TextEditingController();
    String category = 'أخرى';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('مصروف جديد'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                textAlign: TextAlign.right,
                decoration: const InputDecoration(labelText: 'المتجر / الوصف'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: amount,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.right,
                decoration: const InputDecoration(
                  labelText: 'المبلغ',
                  suffixText: 'ر.ع',
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: category,
                decoration: const InputDecoration(labelText: 'التصنيف'),
                items: const [
                  'وقود','مشتريات','مطاعم','سيارة','منزل',
                  'اتصالات','ترفيه','أخرى'
                ].map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(),
                onChanged: (v) => setLocal(() => category = v ?? 'أخرى'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () async {
                final a = double.tryParse(amount.text.trim());
                if (title.text.trim().isEmpty || a == null || a <= 0) return;

                await DatabaseService.instance.addTransaction(
                  TransactionModel(
                    title: title.text.trim(),
                    category: category,
                    amount: a,
                    isIncome: false,
                    date: DateTime.now(),
                  ),
                );

                final prefs = await SharedPreferences.getInstance();
                final newBalance = balance - a;
                await prefs.setDouble('manual_balance', newBalance);

                if (newBalance < threshold) {
                  await NotificationService.instance
                      .lowBalance(newBalance, threshold);
                }

                if (ctx.mounted) Navigator.pop(ctx);
                await load();
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> addNeed() async {
    final controller = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إضافة احتياج'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textAlign: TextAlign.right,
          decoration: const InputDecoration(
            hintText: 'مثال: زيت محرك',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () async {
              if (controller.text.trim().isEmpty) return;
              await DatabaseService.instance.addNeed(
                NeedModel(name: controller.text.trim()),
              );
              if (ctx.mounted) Navigator.pop(ctx);
              needs = await DatabaseService.instance.getNeeds();
              if (mounted) setState(() {});
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  Future<void> settings() async {
    final balanceController =
        TextEditingController(text: balance.toStringAsFixed(3));
    final thresholdController =
        TextEditingController(text: threshold.toStringAsFixed(3));

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('الإعدادات المالية'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: balanceController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'الرصيد الحالي',
                suffixText: 'ر.ع',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: thresholdController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'حد التنبيه',
                suffixText: 'ر.ع',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () async {
              final b = double.tryParse(balanceController.text);
              final t = double.tryParse(thresholdController.text);
              if (b == null || t == null || b < 0 || t < 0) return;

              final prefs = await SharedPreferences.getInstance();
              await prefs.setDouble('manual_balance', b);
              await prefs.setDouble('low_balance_threshold', t);

              if (ctx.mounted) Navigator.pop(ctx);
              await load();
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: SafeArea(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : IndexedStack(
                  index: tab,
                  children: [
                    dashboard(),
                    transactionsPage(),
                    analysisPage(),
                    needsPage(),
                  ],
                ),
        ),
        floatingActionButton: tab == 0
            ? FloatingActionButton.extended(
                onPressed: addExpense,
                icon: const Icon(Icons.add),
                label: const Text('مصروف جديد'),
              )
            : tab == 3
                ? FloatingActionButton.extended(
                    onPressed: addNeed,
                    icon: const Icon(Icons.add_shopping_cart),
                    label: const Text('احتياج'),
                  )
                : null,
        bottomNavigationBar: NavigationBar(
          selectedIndex: tab,
          onDestinationSelected: (i) => setState(() => tab = i),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'الرئيسية',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long),
              label: 'المعاملات',
            ),
            NavigationDestination(
              icon: Icon(Icons.analytics_outlined),
              selectedIcon: Icon(Icons.analytics),
              label: 'التحليل',
            ),
            NavigationDestination(
              icon: Icon(Icons.shopping_cart_outlined),
              selectedIcon: Icon(Icons.shopping_cart),
              label: 'احتياجاتي',
            ),
          ],
        ),
      ),
    );
  }

  Widget dashboard() {
    final expenses = transactions
        .where((t) => !t.isIncome)
        .fold<double>(0, (s, t) => s + t.amount);

    final daysLeft = 25;
    final daily = daysLeft == 0 ? balance : balance / daysLeft;

    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 110),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('مرحباً 👋',
                        style: TextStyle(color: Colors.grey)),
                    SizedBox(height: 4),
                    Text('اسم الميزانية',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                        )),
                  ],
                ),
              ),
              IconButton(
                onPressed: settings,
                icon: const Icon(Icons.settings_outlined),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              gradient: const LinearGradient(
                colors: [Color(0xFF176B5B), Color(0xFF0C4C41)],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('الرصيد الحالي',
                    style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 8),
                Text(
                  '${balance.toStringAsFixed(3)} ر.ع',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 35,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    _whiteStat('دخل الشهر', income),
                    const SizedBox(width: 25),
                    _whiteStat('المصروف', expenses),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (balance < threshold)
            _warning(
              'رصيدك منخفض',
              'رصيدك ${balance.toStringAsFixed(3)} ر.ع، وهو أقل من حد التنبيه.',
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _card(
                  Icons.speed,
                  'الصرف الآمن اليوم',
                  '${daily.clamp(0, 999999).toStringAsFixed(3)} ر.ع',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _card(
                  Icons.receipt_long,
                  'عدد العمليات',
                  '${transactions.length}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              const Expanded(
                child: Text('آخر العمليات',
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                    )),
              ),
              TextButton(
                onPressed: () => setState(() => tab = 1),
                child: const Text('عرض الكل'),
              ),
            ],
          ),
          ...transactions.take(6).map(transactionTile),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: syncing ? null : syncSms,
            icon: syncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sms_outlined),
            label: Text(
              syncing ? 'جارٍ قراءة الرسائل...' : 'مزامنة الرسائل البنكية',
            ),
          ),
        ],
      ),
    );
  }

  Widget _whiteStat(String label, double value) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 3),
            Text(
              '${value.toStringAsFixed(3)} ر.ع',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );

  Widget _card(IconData icon, String title, String value) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: const Color(0xFF176B5B)),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 4),
            Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 17)),
          ],
        ),
      );

  Widget _warning(String title, String body) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFE9E9),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(body),
                ],
              ),
            ),
          ],
        ),
      );

  Widget transactionTile(TransactionModel t) {
    final icon = switch (t.category) {
      'وقود' => Icons.local_gas_station,
      'مطاعم' => Icons.restaurant,
      'مشتريات' => Icons.shopping_bag,
      'اتصالات' => Icons.phone_android,
      'سيارة' => Icons.directions_car,
      'منزل' => Icons.home,
      _ => Icons.receipt_long,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFFE7F2EF),
            child: Icon(icon, color: const Color(0xFF176B5B)),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.title,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  '${t.category} • ${DateFormat('dd/MM/yyyy').format(t.date)}'
                  '${t.source == 'sms' ? ' • SMS' : ''}',
                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                ),
              ],
            ),
          ),
          Text(
            '${t.isIncome ? '+' : '-'}${t.amount.toStringAsFixed(3)}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: t.isIncome ? Colors.green : Colors.redAccent,
            ),
          ),
        ],
      ),
    );
  }

  Widget transactionsPage() => ListView(
        padding: const EdgeInsets.fromLTRB(18, 22, 18, 100),
        children: [
          const Text('المعاملات',
              style: TextStyle(fontSize: 29, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text('كل العمليات المستخرجة أو المدخلة يدويًا',
              style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 18),
          ...transactions.map(transactionTile),
        ],
      );

  Widget analysisPage() {
    final map = <String, double>{};
    for (final t in transactions.where((x) => !x.isIncome)) {
      map[t.category] = (map[t.category] ?? 0) + t.amount;
    }

    final sorted = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final total = sorted.fold<double>(0, (s, e) => s + e.value);

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 100),
      children: [
        const Text('التحليل',
            style: TextStyle(fontSize: 29, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(
          'إجمالي المصروف المسجل: ${total.toStringAsFixed(3)} ر.ع',
          style: const TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: sorted.map((e) {
              final percent = total == 0 ? 0 : e.value / total;
              return Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(e.key)),
                        Text('${e.value.toStringAsFixed(3)} ر.ع',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 7),
                    LinearProgressIndicator(
                      value: percent.toDouble(),
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget needsPage() => ListView(
        padding: const EdgeInsets.fromLTRB(18, 22, 18, 100),
        children: [
          const Text('احتياجاتي 🛒',
              style: TextStyle(fontSize: 29, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text(
            'قائمة مشترياتك. سيتم ربطها لاحقًا بمحرك مقارنة الأسعار.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 18),
          ...needs.map(
            (n) => Container(
              margin: const EdgeInsets.only(bottom: 9),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: CheckboxListTile(
                value: n.done,
                title: Text(
                  n.name,
                  style: TextStyle(
                    decoration: n.done
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                  ),
                ),
                secondary: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    if (n.id == null) return;
                    await DatabaseService.instance.deleteNeed(n.id!);
                    needs = await DatabaseService.instance.getNeeds();
                    if (mounted) setState(() {});
                  },
                ),
                onChanged: (v) async {
                  if (n.id == null) return;
                  await DatabaseService.instance.toggleNeed(n.id!, v ?? false);
                  needs = await DatabaseService.instance.getNeeds();
                  if (mounted) setState(() {});
                },
              ),
            ),
          ),
          if (needs.isEmpty)
            const Padding(
              padding: EdgeInsets.all(30),
              child: Center(child: Text('قائمة الاحتياجات فارغة')),
            ),
        ],
      );
}