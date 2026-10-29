import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../models/category.dart';
import '../models/shopping_item.dart';

class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();
  Database? _db;
  bool _customCategoriesLoaded = false;

  Future<Database> get database async {
    if (_db != null) return _db!;
    final path = p.join(await getDatabasesPath(), 'compras_inteligentes.db');
    _db = await openDatabase(
      path,
      version: 3,
      onCreate: (db, version) async {
        await db.execute('''CREATE TABLE shopping_items (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          quantity REAL NOT NULL,
          unit TEXT NOT NULL,
          unit_price_cents INTEGER NOT NULL,
          is_bought INTEGER NOT NULL DEFAULT 0,
          replaced_by TEXT,
          original_item_id INTEGER,
          original_item_name TEXT,
          actual_unit_price_cents INTEGER,
          category TEXT NOT NULL DEFAULT 'Outros',
          bought_quantity REAL NOT NULL DEFAULT 0.0)''');
        await db.execute('''CREATE TABLE purchases (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          purchased_at TEXT NOT NULL,
          total_cents INTEGER NOT NULL,
          items_count INTEGER NOT NULL)''');
        await db.execute('''CREATE TABLE purchase_items (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          purchase_id INTEGER NOT NULL,
          name TEXT NOT NULL,
          quantity REAL NOT NULL,
          unit TEXT NOT NULL,
          unit_price_cents INTEGER NOT NULL,
          subtotal_cents INTEGER NOT NULL,
          replaced_from TEXT,
          FOREIGN KEY(purchase_id) REFERENCES purchases(id) ON DELETE CASCADE)''');
        await db.execute('CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)');
        await db.insert('settings', {'key': 'budget_cents', 'value': '0'});
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE shopping_items ADD COLUMN original_item_name TEXT');
        }
        if (oldVersion < 3) {
          await db.execute("ALTER TABLE shopping_items ADD COLUMN category TEXT NOT NULL DEFAULT 'Outros'");
          await db.execute("ALTER TABLE shopping_items ADD COLUMN bought_quantity REAL NOT NULL DEFAULT 0.0");
        }
      },
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
    );
    return _db!;
  }

  /// Carrega os itens personalizados que o usuário cadastrou em cada categoria
  Future<Map<String, List<String>>> loadCustomCategories() async {
    final db = await database;
    final rows = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: ['custom_category_items'],
    );
    if (rows.isEmpty) {
      _customCategoriesLoaded = true;
      return ProductCategory.customKeywords;
    }
    try {
      final raw = rows.first['value'] as String;
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final map = <String, List<String>>{};
      for (final entry in decoded.entries) {
        final list = (entry.value as List<dynamic>).map((e) => e.toString()).toList();
        map[entry.key] = list;
      }
      ProductCategory.setCustomKeywords(map);
    } catch (_) {
      // Se houver erro de formato antigo, ignora com segurança
    }
    _customCategoriesLoaded = true;
    return ProductCategory.customKeywords;
  }

  /// Salva um novo item no banco de uma categoria para ser identificado automaticamente
  Future<void> saveCustomCategoryItem(String category, String productName) async {
    if (!_customCategoriesLoaded) {
      await loadCustomCategories();
    }
    ProductCategory.addCustomKeyword(category, productName);
    await _persistCustomCategories();
  }

  /// Remove um item personalizado do banco de uma categoria
  Future<void> removeCustomCategoryItem(String category, String productName) async {
    if (!_customCategoriesLoaded) {
      await loadCustomCategories();
    }
    ProductCategory.removeCustomKeyword(category, productName);
    await _persistCustomCategories();
  }

  Future<void> _persistCustomCategories() async {
    final db = await database;
    final encoded = jsonEncode(ProductCategory.customKeywords);
    await db.insert(
      'settings',
      {'key': 'custom_category_items', 'value': encoded},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<ShoppingItem>> getItems() async {
    if (!_customCategoriesLoaded) {
      await loadCustomCategories();
    }
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

  /// Salva itens comprados ou parcialmente comprados no histórico.
  Future<int> finishPurchase() async {
    final db = await database;
    final all = await getItems();
    final active = all.where((i) => i.replacedBy == null).toList();
    final boughtOrPartial = active.where((i) => i.isFullyBought || i.isPartiallyBought).toList();
    if (boughtOrPartial.isEmpty) {
      throw StateError('Marque pelo menos um produto como comprado.');
    }
    final purchaseId = await db.transaction((txn) async {
      final total = boughtOrPartial.fold<int>(0, (sum, item) => sum + item.boughtSubtotalCents);
      final id = await txn.insert('purchases', {
        'purchased_at': DateTime.now().toIso8601String(),
        'total_cents': total,
        'items_count': boughtOrPartial.length,
      });
      for (final item in boughtOrPartial) {
        final qtyBought = item.isFullyBought ? item.quantity : item.boughtQuantity;
        final subtotal = ((item.actualUnitPriceCents ?? item.unitPriceCents) * qtyBought).round();
        await txn.insert('purchase_items', {
          'purchase_id': id,
          'name': item.name,
          'quantity': qtyBought,
          'unit': item.unit,
          'unit_price_cents': item.actualUnitPriceCents ?? item.unitPriceCents,
          'subtotal_cents': subtotal,
          'replaced_from': item.originalItemName,
        });

        if (item.id != null) {
          if (item.isFullyBought) {
            await txn.delete('shopping_items', where: 'id = ?', whereArgs: [item.id]);
          } else {
            final remaining = item.remainingQuantity;
            await txn.update(
              'shopping_items',
              {
                'quantity': remaining,
                'bought_quantity': 0.0,
                'is_bought': 0,
                'actual_unit_price_cents': null,
              },
              where: 'id = ?',
              whereArgs: [item.id],
            );
          }
        }
      }
      await txn.delete('shopping_items', where: 'replaced_by IS NOT NULL');
      return id;
    });
    return purchaseId;
  }

  Future<List<Map<String, Object?>>> getPurchasesSince(DateTime since) async =>
      (await database).query('purchases',
          where: 'purchased_at >= ?',
          whereArgs: [since.toIso8601String()],
          orderBy: 'purchased_at DESC');

  Future<List<Map<String, Object?>>> getPurchaseItems(int purchaseId) async =>
      (await database).query('purchase_items',
          where: 'purchase_id = ?',
          whereArgs: [purchaseId],
          orderBy: 'id');

  Future<int> getSpendSince(DateTime since) async {
    final rows = await getPurchasesSince(since);
    return rows.fold<int>(0, (sum, row) => sum + (row['total_cents'] as num).toInt());
  }

  Future<List<Map<String, Object?>>> getPriceHistory(String productName) async {
    final db = await database;
    return db.rawQuery('''SELECT pi.name, pi.unit, pi.quantity, pi.unit_price_cents,
p.subtotal_cents, p.purchased_at FROM purchase_items pi
INNER JOIN purchases p ON p.id = pi.purchase_id
WHERE lower(trim(pi.name)) = lower(trim(?))
ORDER BY p.purchased_at DESC''', [productName]);
  }
}
