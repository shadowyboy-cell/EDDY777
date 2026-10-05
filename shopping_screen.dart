import 'package:flutter/material.dart';
import '../services/shopping_service.dart';
import '../models.dart';
import '../services/database_service.dart';

class ShoppingScreen extends StatefulWidget {
  const ShoppingScreen({super.key});

  @override
  State<ShoppingScreen> createState() => _ShoppingScreenState();
}

class _ShoppingScreenState extends State<ShoppingScreen> {
  final controller = TextEditingController();
  String category = 'الكل';
  final categories = const ['الكل', 'غذاء', 'صحة', 'سيارة', 'منزل', 'إلكترونيات'];

  List<NeedModel> items = [];

  @override
  void initState() {
    super.initState();
    loadItems();
  }

  Future<void> loadItems() async {
    final data = await DatabaseService.instance.getNeeds();
    if (mounted) setState(() => items = data);
  }

  void addItem() {
    final name = controller.text.trim();
    if (name.isEmpty) return;
    final selected = category == 'الكل' ? 'أخرى' : category;
    DatabaseService.instance.addNeed(NeedModel(name: name, category: selected)).then((_) {
      controller.clear();
      loadItems();
    });
  }

  Future<void> search(String name, String source) async {
    final uri = switch (source) {
      'D4D' => ShoppingService.d4dSearch(name),
      'ClicFlyer' => ShoppingService.clicFlyerSearch(name),
      _ => ShoppingService.webSearch(name),
    };
    final ok = await ShoppingService.open(uri);
    if (!mounted || ok) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تعذر فتح مصدر البحث.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 22, 18, 110),
        children: [
          const Text('الاحتياجات والأسعار', style: TextStyle(fontSize: 29, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text('اكتب ما تحتاجه، ثم افتح مصادر العروض والأسعار وقارن قبل الشراء.', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 18),
          TextField(
            controller: controller,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => addItem(),
            decoration: InputDecoration(
              hintText: 'مثال: زيت محرك 5W-30',
              prefixIcon: IconButton(onPressed: addItem, icon: const Icon(Icons.add)),
              suffixIcon: const Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => ChoiceChip(
                label: Text(categories[i]),
                selected: category == categories[i],
                onSelected: (_) => setState(() => category = categories[i]),
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (items.isEmpty)
            Container(
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
              child: const Column(
                children: [
                  Icon(Icons.shopping_cart_outlined, size: 48, color: Color(0xFF176B5B)),
                  SizedBox(height: 10),
                  Text('لا توجد احتياجات بعد', style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 5),
                  Text('أضف أول غرض تريد شراءه.', style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          ...items.map((item) => _itemCard(item)),
        ],
      ),
    );
  }

  Future<void> addPrice(String product) async {
    final store = TextEditingController();
    final price = TextEditingController();
    final source = TextEditingController(text: 'سعر يدوي');
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('إضافة سعر: $product'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: store, decoration: const InputDecoration(labelText: 'المتجر')),
            const SizedBox(height: 10),
            TextField(controller: price, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'السعر', suffixText: 'ر.ع')),
            const SizedBox(height: 10),
            TextField(controller: source, decoration: const InputDecoration(labelText: 'المصدر')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () async {
              final p = double.tryParse(price.text.trim());
              if (store.text.trim().isEmpty || p == null || p <= 0) return;
              await DatabaseService.instance.addPriceCheck(PriceCheckModel(
                product: product, source: source.text.trim().isEmpty ? 'سعر يدوي' : source.text.trim(),
                price: p, store: store.text.trim(), url: '', checkedAt: DateTime.now(),
              ));
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) setState(() {});
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  Widget _itemCard(NeedModel item) {
    final name = item.name;
    final itemCategory = item.category;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const CircleAvatar(backgroundColor: Color(0xFFE7F2EF), child: Icon(Icons.shopping_bag_outlined, color: Color(0xFF176B5B))),
            const SizedBox(width: 12),
            Expanded(child: Text(name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold))),
            Text(itemCategory, style: const TextStyle(color: Colors.grey)),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: OutlinedButton.icon(onPressed: () => search(name, 'D4D'), icon: const Icon(Icons.local_offer_outlined), label: const Text('D4D'))),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton.icon(onPressed: () => search(name, 'ClicFlyer'), icon: const Icon(Icons.receipt_long_outlined), label: const Text('ClicFlyer'))),
            const SizedBox(width: 8),
            IconButton(onPressed: () => search(name, 'web'), icon: const Icon(Icons.language), tooltip: 'بحث عام'),
            IconButton(onPressed: () => addPrice(name), icon: const Icon(Icons.price_check_outlined), tooltip: 'إضافة سعر'),
            IconButton(onPressed: () async { if (item.id != null) { await DatabaseService.instance.deleteNeed(item.id!); await loadItems(); } }, icon: const Icon(Icons.delete_outline), tooltip: 'حذف'),
          ]),
          const SizedBox(height: 8),
          FutureBuilder<List<PriceCheckModel>>(
            future: DatabaseService.instance.getPriceChecks(name),
            builder: (context, snapshot) {
              final prices = snapshot.data ?? const <PriceCheckModel>[];
              if (prices.isEmpty) {
                return const Text('لا توجد أسعار محفوظة بعد — أضف سعرًا بعد المقارنة.', style: TextStyle(color: Colors.grey, fontSize: 12));
              }
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFFF4F8F7), borderRadius: BorderRadius.circular(14)),
                child: Column(
                  children: prices.take(3).map((p) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      Expanded(child: Text('${p.store} • ${p.source}')),
                      Text('${p.price.toStringAsFixed(3)} ر.ع', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ]),
                  )).toList(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
