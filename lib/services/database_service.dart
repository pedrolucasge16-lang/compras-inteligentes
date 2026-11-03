import 'dart:convert';
import 'dart:io';
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
      version: 4,
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
          bought_quantity REAL NOT NULL DEFAULT 0.0,
          image_path TEXT,
          market_name TEXT)''');
        await db.execute('''CREATE TABLE purchases (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          purchased_at TEXT NOT NULL,
          total_cents INTEGER NOT NULL,
          items_count INTEGER NOT NULL,
          market_name TEXT,
          market_location TEXT)''');
        await db.execute('''CREATE TABLE purchase_items (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          purchase_id INTEGER NOT NULL,
          name TEXT NOT NULL,
          quantity REAL NOT NULL,
          unit TEXT NOT NULL,
          unit_price_cents INTEGER NOT NULL,
          subtotal_cents INTEGER NOT NULL,
          replaced_from TEXT,
          image_path TEXT,
          category TEXT,
          market_name TEXT,
          FOREIGN KEY(purchase_id) REFERENCES purchases(id) ON DELETE CASCADE)''');
        await db.execute('CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)');
        await db.insert('settings', {'key': 'budget_cents', 'value': '0'});
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _safeAddColumn(db, 'shopping_items', 'original_item_name TEXT');
        }
        if (oldVersion < 3) {
          await _safeAddColumn(db, 'shopping_items', "category TEXT NOT NULL DEFAULT 'Outros'");
          await _safeAddColumn(db, 'shopping_items', 'bought_quantity REAL NOT NULL DEFAULT 0.0');
        }
        if (oldVersion < 4) {
          await _safeAddColumn(db, 'shopping_items', 'image_path TEXT');
          await _safeAddColumn(db, 'shopping_items', 'market_name TEXT');
          await _safeAddColumn(db, 'purchases', 'market_name TEXT');
          await _safeAddColumn(db, 'purchases', 'market_location TEXT');
          await _safeAddColumn(db, 'purchase_items', 'image_path TEXT');
          await _safeAddColumn(db, 'purchase_items', 'category TEXT');
          await _safeAddColumn(db, 'purchase_items', 'market_name TEXT');
        }
      },
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
    );
    return _db!;
  }

  Future<void> _safeAddColumn(Database db, String table, String columnDef) async {
    try {
      await db.execute('ALTER TABLE $table ADD COLUMN $columnDef');
    } catch (_) {
      // Coluna já existe
    }
  }

  /// Copia a foto tirada pela câmera para a pasta persistente do aplicativo
  Future<String> persistProductImage(String sourcePath) async {
    try {
      final dbDir = await getDatabasesPath();
      final photosDir = Directory(p.join(dbDir, 'product_photos'));
      if (!photosDir.existsSync()) {
        photosDir.createSync(recursive: true);
      }
      final ext = p.extension(sourcePath).isNotEmpty ? p.extension(sourcePath) : '.jpg';
      final fileName = 'prod_${DateTime.now().millisecondsSinceEpoch}$ext';
      final destPath = p.join(photosDir.path, fileName);
      await File(sourcePath).copy(destPath);
      return destPath;
    } catch (_) {
      return sourcePath;
    }
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
    } catch (_) {}
    _customCategoriesLoaded = true;
    return ProductCategory.customKeywords;
  }

  Future<void> saveCustomCategoryItem(String category, String productName) async {
    if (!_customCategoriesLoaded) {
      await loadCustomCategories();
    }
    ProductCategory.addCustomKeyword(category, productName);
    await _persistCustomCategories();
  }

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

  /// Obtém e salva o mercado atual (nome e localização)
  Future<(String, String)> getCurrentMarket() async {
    final db = await database;
    final rows = await db.query('settings', where: 'key = ?', whereArgs: ['current_market']);
    if (rows.isEmpty) return ('', '');
    try {
      final map = jsonDecode(rows.first['value'] as String) as Map<String, dynamic>;
      return ((map['name'] as String?) ?? '', (map['location'] as String?) ?? '');
    } catch (_) {
      return ('', '');
    }
  }

  Future<void> setCurrentMarket(String name, String location) async {
    final db = await database;
    final encoded = jsonEncode({'name': name.trim(), 'location': location.trim()});
    await db.insert(
      'settings',
      {'key': 'current_market', 'value': encoded},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    if (name.trim().isNotEmpty) {
      await _addSavedMarketToList(name.trim(), location.trim());
    }
  }

  Future<List<Map<String, String>>> getSavedMarkets() async {
    final db = await database;
    final rows = await db.query('settings', where: 'key = ?', whereArgs: ['saved_markets']);
    if (rows.isEmpty) return [];
    try {
      final list = jsonDecode(rows.first['value'] as String) as List<dynamic>;
      return list
          .map((e) => {
                'name': ((e as Map)['name'] ?? '').toString(),
                'location': (e['location'] ?? '').toString(),
              })
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _addSavedMarketToList(String name, String location) async {
    final current = await getSavedMarkets();
    current.removeWhere((m) => m['name']!.toLowerCase() == name.toLowerCase());
    current.insert(0, {'name': name, 'location': location});
    final db = await database;
    await db.insert(
      'settings',
      {'key': 'saved_markets', 'value': jsonEncode(current.take(15).toList())},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Retorna os itens ordenados com os recém-adicionados SEMPRE no topo (id DESC)
  Future<List<ShoppingItem>> getItems() async {
    if (!_customCategoriesLoaded) {
      await loadCustomCategories();
    }
    final rows = await (await database).query('shopping_items', orderBy: 'id DESC');
    return rows.map(ShoppingItem.fromMap).toList();
  }

  Future<int> saveItem(ShoppingItem item) async {
    final db = await database;
    final market = await getCurrentMarket();
    final effectiveMarket = (item.marketName != null && item.marketName!.isNotEmpty)
        ? item.marketName
        : (market.$1.isNotEmpty ? market.$1 : null);
    final values = item.copyWith(marketName: effectiveMarket).toMap()..remove('id');
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

  /// Salva itens comprados ou parcialmente comprados no histórico com o mercado atual.
  Future<int> finishPurchase() async {
    final db = await database;
    final all = await getItems();
    final active = all.where((i) => i.replacedBy == null).toList();
    final boughtOrPartial = active.where((i) => i.isFullyBought || i.isPartiallyBought).toList();
    if (boughtOrPartial.isEmpty) {
      throw StateError('Marque pelo menos um produto como comprado.');
    }
    final market = await getCurrentMarket();
    final marketName = market.$1.isNotEmpty ? market.$1 : 'Mercado Geral';
    final marketLocation = market.$2;

    final purchaseId = await db.transaction((txn) async {
      final total = boughtOrPartial.fold<int>(0, (sum, item) => sum + item.boughtSubtotalCents);
      final id = await txn.insert('purchases', {
        'purchased_at': DateTime.now().toIso8601String(),
        'total_cents': total,
        'items_count': boughtOrPartial.length,
        'market_name': marketName,
        'market_location': marketLocation,
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
          'image_path': item.imagePath,
          'category': item.category,
          'market_name': item.marketName ?? marketName,
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
pi.subtotal_cents, pi.image_path, pi.category, COALESCE(pi.market_name, p.market_name) AS market_name,
p.market_location, p.purchased_at FROM purchase_items pi
INNER JOIN purchases p ON p.id = pi.purchase_id
WHERE lower(trim(pi.name)) = lower(trim(?))
ORDER BY p.purchased_at DESC''', [productName]);
  }

  /// Retorna todos os registros de produtos dos últimos 30 dias + lista atual
  /// para alimentar a vitrine comparativa de mercados do site.
  Future<List<Map<String, Object?>>> getRecentCatalogRecords() async {
    final db = await database;
    final since = DateTime.now().subtract(const Duration(days: 31)).toIso8601String();
    return db.rawQuery('''
      SELECT
        pi.name,
        pi.unit,
        pi.unit_price_cents,
        pi.image_path,
        COALESCE(pi.category, 'Outros') AS category,
        COALESCE(pi.market_name, p.market_name, 'Mercado Geral') AS market_name,
        COALESCE(p.market_location, '') AS market_location,
        p.purchased_at
      FROM purchase_items pi
      INNER JOIN purchases p ON p.id = pi.purchase_id
      WHERE p.purchased_at >= ?
      ORDER BY p.purchased_at DESC
    ''', [since]);
  }
}
