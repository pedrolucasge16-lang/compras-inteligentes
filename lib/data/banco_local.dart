import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../domain/item_compra.dart';

class BancoLocal {
  BancoLocal._();
  static final BancoLocal instancia = BancoLocal._();

  Database? _db;

  Future<Database> get _banco async {
    final existente = _db;
    if (existente != null) return existente;
    final caminho = p.join(await getDatabasesPath(), 'compras.db');
    final novo = await openDatabase(
      caminho,
      version: 1,
      onCreate: (db, versao) async {
        await db.execute(
          'CREATE TABLE itens ('
          'id INTEGER PRIMARY KEY AUTOINCREMENT, '
          'nome TEXT NOT NULL, '
          'preco_centavos INTEGER NOT NULL, '
          'quantidade INTEGER NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE config (chave TEXT PRIMARY KEY, valor TEXT NOT NULL)',
        );
      },
    );
    _db = novo;
    return novo;
  }

  Future<List<ItemCompra>> listarItens() async {
    final db = await _banco;
    final linhas = await db.query('itens', orderBy: 'id DESC');
    return linhas.map(ItemCompra.fromMap).toList();
  }

  Future<int> inserirItem(ItemCompra item) async {
    final db = await _banco;
    return db.insert('itens', item.toMap());
  }

  Future<void> atualizarItem(ItemCompra item) async {
    final db = await _banco;
    await db.update('itens', item.toMap(), where: 'id = ?', whereArgs: [item.id]);
  }

  Future<void> removerItem(int id) async {
    final db = await _banco;
    await db.delete('itens', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> lerOrcamento() async {
    final db = await _banco;
    final linhas = await db.query('config', where: 'chave = ?', whereArgs: ['orcamento']);
    if (linhas.isEmpty) return 0;
    return int.tryParse(linhas.first['valor'] as String) ?? 0;
  }

  Future<void> salvarOrcamento(int centavos) async {
    final db = await _banco;
    await db.insert(
      'config',
      {'chave': 'orcamento', 'valor': centavos.toString()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
