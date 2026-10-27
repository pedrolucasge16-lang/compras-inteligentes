import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../models/shopping_item.dart';

class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();
  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    final path = p.join(await getDatabasesPath(), 'compras_inteligentes.db');
    _db = await openDatabase(path, version: 2,
      onCreate: (db, version) async {
        await db.execute('''CREATE TABLE shopping_items (
          id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL,
          quantity REAL NOT NULL, unit TEXT NOT NULL,
          unit_price_cents INTEGER NOT NULL, is_bought INTEGER NOT NULL DEFAULT 0,
          replaced_by TEXT, original_item_id INTEGER, original_item_name TEXT,
          actual_unit_price_cents INTEGER)''');
        await db.execute('''CREATE TABLE purchases (
          id INTEGER PRIMARY KEY AUTOINCREMENT, purchased_at TEXT NOT NULL,
          total_cents INTEGER NOT NULL, items_count INTEGER NOT NULL)''');
        await db.execute('''CREATE TABLE purchase_items (
          id INTEGER PRIMARY KEY AUTOINCREMENT, purchase_id INTEGER NOT NULL,
          name TEXT NOT NULL, quantity REAL NOT NULL, unit TEXT NOT NULL,
          unit_price_cents INTEGER NOT NULL, subtotal_cents INTEGER NOT NULL,
          replaced_from TEXT, FOREIGN KEY(purchase_id) REFERENCES purchases(id) ON DELETE CASCADE)''');
        await db.execute('CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)');
        await db.insert('settings', {'key': 'budget_cents', 'value': '0'});
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE shopping_items ADD COLUMN original_item_name TEXT');
        }
      },
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
    );
    return _db!;
  }

  Future<List<ShoppingItem>> getItems() async {
    final rows = await (await database).query('shopping_items', orderBy: 'id DESC');
    return rows.map(ShoppingItem.fromMap).toList();
  }

  Future<int> saveItem(ShoppingItem item) async {
    final db = await database;
    final values = item.toMap()..remove('id');
    if (item.id == null) return db.insert('shopping_items', values);
    return db.update('shopping_items', values, where: 'id = ?', whereArgs: [item.id]);
  }

  Future<void> deleteItem(int id) async =>
      (await database).delete('shopping_items', where: 'id = ?', whereArgs: [id]);

  Future<void> setBudget(int cents) async {
    await (await database).insert('settings', {'key': 'budget_cents', 'value': '$cents'},
      conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> getBudget() async {
    final rows = await (await database).query('settings', where: 'key = ?', whereArgs: ['budget_cents']);
    return rows.isEmpty ? 0 : int.tryParse(rows.first['value'] as String) ?? 0;
  }

  /// Saves only checked, active items. Unchecked items stay in the current list.
  Future<int> finishPurchase() async {
    final db = await database;
    final all = await getItems();
    final bought = all.where((i) => i.replacedBy == null && i.isBought).toList();
    if (bought.isEmpty) throw StateError('Marque pelo menos um produto como comprado.');
    final purchaseId = await db.transaction((txn) async {
      final total = bought.fold<int>(0, (sum, item) => sum + item.subtotalCents);
      final id = await txn.insert('purchases', {
        'purchased_at': DateTime.now().toIso8601String(),
        'total_cents': total,
        'items_count': bought.length,
      });
      for (final item in bought) {
        await txn.insert('purchase_items', {
          'purchase_id': id,
          'name': item.name,
          'quantity': item.quantity,
          'unit': item.unit,
          'unit_price_cents': item.actualUnitPriceCents ?? item.unitPriceCents,
          'subtotal_cents': item.subtotalCents,
          'replaced_from': item.originalItemName,
        });
        if (item.id != null) {
          await txn.delete('shopping_items', where: 'id = ?', whereArgs: [item.id]);
        }
      }
      // Remove only obsolete rows representing products that were replaced.
      await txn.delete('shopping_items', where: 'replaced_by IS NOT NULL');
      return id;
    });
    return purchaseId;
  }

  Future<List<Map<String, Object?>>> getPurchasesSince(DateTime since) async =>
      (await database).query('purchases', where: 'purchased_at >= ?',
        whereArgs: [since.toIso8601String()], orderBy: 'purchased_at DESC');

  Future<List<Map<String, Object?>>> getPurchaseItems(int purchaseId) async =>
      (await database).query('purchase_items', where: 'purchase_id = ?', whereArgs: [purchaseId], orderBy: 'id');

  Future<int> getSpendSince(DateTime since) async {
    final rows = await getPurchasesSince(since);
    return rows.fold<int>(0, (sum, row) => sum + (row['total_cents'] as num).toInt());
  }

  Future<List<Map<String, Object?>>> getPriceHistory(String productName) async {
    final db = await database;
    return db.rawQuery('''SELECT pi.name, pi.unit, pi.quantity, pi.unit_price_cents,
      pi.subtotal_cents, p.purchased_at FROM purchase_items pi
      INNER JOIN purchases p ON p.id = pi.purchase_id
      WHERE lower(trim(pi.name)) = lower(trim(?))
      ORDER BY p.purchased_at DESC''', [productName]);
  }
}
