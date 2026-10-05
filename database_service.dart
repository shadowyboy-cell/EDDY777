import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models.dart';

class DatabaseService {
  DatabaseService._();
  static final instance = DatabaseService._();

  late Database db;

  Future<void> init() async {
    final path = join(await getDatabasesPath(), 'ism_almizania.db');
    db = await openDatabase(
      path,
      version: 2,
      onCreate: (database, version) async {
        await database.execute('''
          CREATE TABLE transactions(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            category TEXT NOT NULL,
            amount REAL NOT NULL,
            is_income INTEGER NOT NULL,
            date INTEGER NOT NULL,
            source TEXT NOT NULL,
            sms_id TEXT UNIQUE
          )
        ''');
        await database.execute('''
          CREATE TABLE needs(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            category TEXT NOT NULL DEFAULT 'أخرى',
            done INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await database.execute('''
          CREATE TABLE price_checks(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            product TEXT NOT NULL,
            source TEXT NOT NULL,
            price REAL NOT NULL,
            store TEXT NOT NULL,
            url TEXT NOT NULL,
            checked_at INTEGER NOT NULL
          )
        ''');
        await database.execute('''
          CREATE TABLE settings(
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
      },
      onUpgrade: (database, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await database.execute("ALTER TABLE needs ADD COLUMN category TEXT NOT NULL DEFAULT 'أخرى'");
        }
      },
    );
  }

  Future<int> addTransaction(TransactionModel t) async =>
      db.insert('transactions', t.toMap(),
          conflictAlgorithm: ConflictAlgorithm.ignore);

  Future<List<TransactionModel>> getTransactions() async {
    final rows = await db.query(
      'transactions',
      orderBy: 'date DESC, id DESC',
    );
    return rows.map(TransactionModel.fromMap).toList();
  }

  Future<List<TransactionModel>> getMonthTransactions(DateTime month) async {
    final start = DateTime(month.year, month.month);
    final end = DateTime(month.year, month.month + 1);
    final rows = await db.query(
      'transactions',
      where: 'date >= ? AND date < ?',
      whereArgs: [
        start.millisecondsSinceEpoch,
        end.millisecondsSinceEpoch,
      ],
      orderBy: 'date DESC',
    );
    return rows.map(TransactionModel.fromMap).toList();
  }

  Future<bool> smsExists(String smsId) async {
    final r = await db.query(
      'transactions',
      columns: ['id'],
      where: 'sms_id = ?',
      whereArgs: [smsId],
      limit: 1,
    );
    return r.isNotEmpty;
  }

  Future<int> addNeed(NeedModel n) =>
      db.insert('needs', n.toMap());

  Future<List<NeedModel>> getNeeds() async {
    final rows = await db.query('needs', orderBy: 'done ASC, id DESC');
    return rows.map(NeedModel.fromMap).toList();
  }

  Future<void> toggleNeed(int id, bool done) async {
    await db.update(
      'needs',
      {'done': done ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteNeed(int id) async {
    await db.delete('needs', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> addPriceCheck(PriceCheckModel p) =>
      db.insert('price_checks', p.toMap());

  Future<List<PriceCheckModel>> getPriceChecks(String product) async {
    final rows = await db.query(
      'price_checks',
      where: 'product = ?',
      whereArgs: [product],
      orderBy: 'price ASC, checked_at DESC',
    );
    return rows.map(PriceCheckModel.fromMap).toList();
  }
}