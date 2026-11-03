import 'dart:convert';
import 'dart:io';
import 'database_service.dart';

class SiteSyncService {
  SiteSyncService._();

  /// Gera o JSON completo da Vitrine de Mercados e Produtos (com fotos, preço de agora e preço de até 1 mês atrás)
  static Future<String> buildVitrineJson() async {
    final db = DatabaseService.instance;
    final currentMarket = await db.getCurrentMarket();
    final defaultMarketName = currentMarket.$1.isNotEmpty ? currentMarket.$1 : 'Mercado Principal';
    final defaultMarketLoc = currentMarket.$2;

    final activeItems = (await db.getItems()).where((i) => i.replacedBy == null).toList();
    final historyRows = await db.getRecentCatalogRecords();

    // Agrupa registros por chave (mercado + nome do produto)
    final Map<String, List<Map<String, dynamic>>> grouped = {};

    // 1. Inclui os itens atuais que já possuem preço
    final nowIso = DateTime.now().toIso8601String();
    for (final item in activeItems) {
      final price = item.actualUnitPriceCents ?? item.unitPriceCents;
      if (price <= 0) continue;
      final mName = (item.marketName != null && item.marketName!.isNotEmpty)
          ? item.marketName!
          : defaultMarketName;
      final key = '${mName.toLowerCase()}||${item.name.trim().toLowerCase()}';
      grouped.putIfAbsent(key, () => []).add({
        'name': item.name.trim(),
        'unit': item.unit,
        'priceCents': price,
        'category': item.category,
        'marketName': mName,
        'marketLocation': defaultMarketLoc,
        'imagePath': item.imagePath,
        'recordedAt': nowIso,
      });
    }

    // 2. Inclui os registros do histórico dos últimos 30 dias
    for (final row in historyRows) {
      final price = (row['unit_price_cents'] as num?)?.toInt() ?? 0;
      if (price <= 0) continue;
      final name = (row['name'] as String?)?.trim() ?? '';
      if (name.isEmpty) continue;
      final mName = (row['market_name'] as String?)?.trim() ?? defaultMarketName;
      final key = '${mName.toLowerCase()}||${name.toLowerCase()}';
      grouped.putIfAbsent(key, () => []).add({
        'name': name,
        'unit': (row['unit'] as String?) ?? 'un',
        'priceCents': price,
        'category': (row['category'] as String?) ?? 'Outros',
        'marketName': mName,
        'marketLocation': (row['market_location'] as String?) ?? defaultMarketLoc,
        'imagePath': row['image_path'] as String?,
        'recordedAt': (row['purchased_at'] as String?) ?? nowIso,
      });
    }

    final productsPayload = <Map<String, dynamic>>[];

    for (final entries in grouped.values) {
      // Ordena do mais recente para o mais antigo (até 1 mês atrás)
      entries.sort((a, b) => (b['recordedAt'] as String).compareTo(a['recordedAt'] as String));
      final latest = entries.first;
      // Busca o preço anterior (ou de até 1 mês atrás) se houver mais de um registro
      final oldestInMonth = entries.length > 1 ? entries.last : null;

      String? photoDataUri;
      for (final e in entries) {
        final pPath = e['imagePath'] as String?;
        if (pPath != null && pPath.isNotEmpty) {
          final file = File(pPath);
          if (file.existsSync()) {
            try {
              final bytes = await file.readAsBytes();
              // Limita fotos muito grandes para manter o JSON leve
              if (bytes.length <= 900 * 1024) {
                photoDataUri = 'data:image/jpeg;base64,${base64Encode(bytes)}';
                break;
              }
            } catch (_) {}
          }
        }
      }

      productsPayload.add({
        'name': latest['name'],
        'category': latest['category'],
        'unit': latest['unit'],
        'marketName': latest['marketName'],
        'marketLocation': latest['marketLocation'],
        'currentPriceCents': latest['priceCents'],
        'currentDate': latest['recordedAt'],
        'previousPriceCents': oldestInMonth != null ? oldestInMonth['priceCents'] : null,
        'previousDate': oldestInMonth != null ? oldestInMonth['recordedAt'] : null,
        'photoDataUri': photoDataUri,
      });
    }

    final payload = {
      'updatedAt': DateTime.now().toIso8601String(),
      'products': productsPayload,
    };

    final jsonStr = const JsonEncoder.withIndent('  ').convert(payload);

    // Tenta salvar uma cópia direta na pasta Download do Android para facilitar o envio ao site
    try {
      final dlFile = File('/sdcard/Download/vitrine_dados.json');
      await dlFile.writeAsString(jsonStr);
    } catch (_) {}

    return jsonStr;
  }
}
