import 'dart:convert';
import 'dart:io';

class MarketPlaceSuggestion {
  const MarketPlaceSuggestion({
    required this.name,
    required this.location,
  });

  final String name;
  final String location;
}

class LocationMarketService {
  LocationMarketService._();

  /// Detecta a cidade/região atual e busca supermercados próximos via OpenStreetMap
  static Future<(String detectedCity, List<MarketPlaceSuggestion> markets)>
      detectLocationAndNearbyMarkets([String? customQuery]) async {
    String city = 'Rio de Janeiro, RJ';
    double? lat;
    double? lon;

    // 1. Tenta detectar a cidade/coordenadas atuais pela rede
    try {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
      final req = await client.getUrl(Uri.parse('https://ipwho.is/?lang=pt-BR'));
      req.headers.set('User-Agent', 'ComprasInteligentesApp/1.2');
      final res = await req.close();
      if (res.statusCode == 200) {
        final body = await res.transform(utf8.decoder).join();
        final data = jsonDecode(body) as Map<String, dynamic>;
        final c = (data['city'] as String?)?.trim() ?? '';
        final r = (data['region_code'] as String?)?.trim() ??
            (data['region'] as String?)?.trim() ??
            '';
        if (c.isNotEmpty) {
          city = r.isNotEmpty ? '$c, $r' : c;
        }
        lat = (data['latitude'] as num?)?.toDouble();
        lon = (data['longitude'] as num?)?.toDouble();
      }
      client.close();
    } catch (_) {}

    // 2. Busca supermercados na região via OpenStreetMap Nominatim
    final suggestions = <MarketPlaceSuggestion>[];
    try {
      final searchTerm = (customQuery != null && customQuery.trim().isNotEmpty)
          ? 'supermercado ${customQuery.trim()}'
          : 'supermercado $city';
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': searchTerm,
        'format': 'json',
        'addressdetails': '1',
        'limit': '8',
        'countrycodes': 'br',
        if (lat != null && lon != null && (customQuery == null || customQuery.isEmpty))
          'viewbox': '${lon - 0.15},${lat + 0.15},${lon + 0.15},${lat - 0.15}',
      });

      final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
      final req = await client.getUrl(uri);
      req.headers.set('User-Agent', 'ComprasInteligentesApp/1.2');
      final res = await req.close();
      if (res.statusCode == 200) {
        final body = await res.transform(utf8.decoder).join();
        final list = jsonDecode(body) as List<dynamic>;
        for (final raw in list) {
          final map = raw as Map<String, dynamic>;
          final displayName = (map['display_name'] as String?) ?? '';
          final nameField = (map['name'] as String?)?.trim() ?? '';
          final addr = (map['address'] as Map<String, dynamic>?) ?? {};
          final suburb = (addr['suburb'] ??
                  addr['neighbourhood'] ??
                  addr['city_district'] ??
                  '')
              .toString();
          final town = (addr['city'] ?? addr['town'] ?? addr['municipality'] ?? city).toString();

          final marketTitle = nameField.isNotEmpty
              ? nameField
              : displayName.split(',').first.trim();
          final locLabel = suburb.isNotEmpty ? '$suburb - $town' : town;

          if (marketTitle.isNotEmpty &&
              !suggestions.any((s) =>
                  s.name.toLowerCase() == marketTitle.toLowerCase() &&
                  s.location.toLowerCase() == locLabel.toLowerCase())) {
            suggestions.add(MarketPlaceSuggestion(
              name: marketTitle,
              location: locLabel,
            ));
          }
        }
      }
      client.close();
    } catch (_) {}

    // 3. Caso esteja sem sinal dentro do mercado, garante opções rápidas locais
    if (suggestions.isEmpty) {
      suggestions.addAll([
        MarketPlaceSuggestion(name: 'Supermercado Guanabara', location: city),
        MarketPlaceSuggestion(name: 'Supermercado Mundial', location: city),
        MarketPlaceSuggestion(name: 'Assaí Atacadista', location: city),
        MarketPlaceSuggestion(name: 'Supermercados Prezunic', location: city),
        MarketPlaceSuggestion(name: 'Carrefour', location: city),
        MarketPlaceSuggestion(name: 'Atacadão', location: city),
      ]);
    }

    return (city, suggestions);
  }
}
