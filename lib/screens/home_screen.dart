import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../models/category.dart';
import '../models/shopping_item.dart';
import '../services/database_service.dart';
import '../services/location_market_service.dart';
import '../services/money.dart';
import '../services/ocr_service.dart';
import '../services/quantity.dart';
import '../services/site_sync_service.dart';
import '../theme/app_theme.dart';
import 'create_list_screen.dart';
import 'history_screen.dart';
import 'comparator_screen.dart';
import 'tabs/next_item_tab.dart';
import 'tabs/pending_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final db = DatabaseService.instance;
  List<ShoppingItem> items = [];
  int budget = 0;
  String currentMarketName = '';
  String currentMarketLocation = '';
  bool loading = true;
  int _currentTabIndex = 0;
  String _selectedCategoryFilter = 'Todos';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await db.getItems();
    final b = await db.getBudget();
    final market = await db.getCurrentMarket();
    if (!mounted) return;
    setState(() {
      items = data;
      budget = b;
      currentMarketName = market.$1;
      currentMarketLocation = market.$2;
      loading = false;
    });
  }

  List<ShoppingItem> get activeItems => items.where((i) => i.replacedBy == null).toList();
  int get total => activeItems.fold(0, (sum, item) => sum + item.subtotalCents);
  int get boughtTotal => activeItems
      .where((i) => i.isFullyBought || i.isPartiallyBought)
      .fold(0, (sum, item) => sum + item.boughtSubtotalCents);

  bool get isAllSelected =>
      activeItems.isNotEmpty && activeItems.every((i) => i.isFullyBought);

  Future<void> _toggleSelectAll(bool selectAll) async {
    for (final item in activeItems) {
      final updated = item.copyWith(
        isBought: selectAll,
        boughtQuantity: selectAll ? item.quantity : 0.0,
      );
      await db.saveItem(updated);
    }
    await _load();
  }

  Future<void> _toggleItemCheckbox(ShoppingItem item, bool checked) async {
    final updated = item.copyWith(
      isBought: checked,
      boughtQuantity: checked ? item.quantity : 0.0,
    );
    await db.saveItem(updated);
    await _load();
  }

  Future<void> _openQuickAdd() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateListScreen()),
    );
    await _load();
  }

  /// Extrai SOMENTE NÚMEROS de preço a partir do resultado do OCR (para o quadrado de cima da câmera)
  int? _extractNumericPriceOnly(OcrSuggestion suggestion) {
    if (suggestion.priceCents != null && suggestion.priceCents! > 0) {
      return suggestion.priceCents;
    }
    if (suggestion.candidates.isNotEmpty) {
      return suggestion.candidates.first;
    }
    // Procura padrões numéricos de preço (ex: 18,90 ou 18.90 ou números isolados)
    final raw = suggestion.text;
    final decMatch = RegExp(r'(\d{1,4})\s*[,.]\s*(\d{2})').firstMatch(raw);
    if (decMatch != null) {
      final reais = int.tryParse(decMatch.group(1)!) ?? 0;
      final cents = int.tryParse(decMatch.group(2)!) ?? 0;
      final totalCents = reais * 100 + cents;
      if (totalCents > 0) return totalCents;
    }
    final digitsOnly = RegExp(r'\b(\d{1,3})\b').firstMatch(raw);
    if (digitsOnly != null) {
      final val = int.tryParse(digitsOnly.group(1)!) ?? 0;
      if (val > 0) return val * 100;
    }
    return null;
  }

  /// Extrai o NOME DO PRODUTO (ignorando números isolados) para o quadrado de baixo da câmera
  String? _extractProductNameOnly(OcrSuggestion suggestion) {
    if (suggestion.productName != null && suggestion.productName!.trim().isNotEmpty) {
      return suggestion.productName!.trim();
    }
    final lines = suggestion.text
        .split('\n')
        .map((l) => l.replaceAll(RegExp(r'[0-9R\$.,:/-]+'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim())
        .where((l) => l.length >= 3)
        .toList();
    if (lines.isNotEmpty) {
      return lines.first;
    }
    return null;
  }

  /// JANELA COM OS 2 QUADRADINHOS COM "+" SOLICITADA PELO USUÁRIO:
  /// - Quadrado de cima (+): Tira foto do PREÇO (lê somente números)
  /// - Quadrado de baixo (+): Tira foto do NOME / PRODUTO (lê o nome e salva a foto do produto)
  Future<void> _openTwoSquareCameraModal([ShoppingItem? existingItem]) async {
    final nameCtrl = TextEditingController(text: existingItem?.name ?? '');
    final priceCtrl = TextEditingController(
      text: (existingItem != null && existingItem.effectiveUnitPriceCents > 0)
          ? centsToInput(existingItem.effectiveUnitPriceCents)
          : '',
    );
    final qtyCtrl = TextEditingController(
      text: formatQuantity(existingItem?.quantity ?? 1.0),
    );
    String unit = existingItem?.unit ?? 'un';
    String category = existingItem?.category ??
        (nameCtrl.text.isNotEmpty
            ? ProductCategory.detectCategory(nameCtrl.text)
            : ProductCategory.outros);

    String? pricePhotoPreviewPath;
    String? productPhotoPath = existingItem?.imagePath;
    List<int> numericCandidates = [];
    bool readingPrice = false;
    bool readingProduct = false;

    final savedItem = await showDialog<ShoppingItem>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: AppTheme.creamBackground,
          title: Row(
            children: [
              const Icon(Icons.camera_enhance, color: AppTheme.primaryDarkGreen),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  existingItem == null
                      ? 'Adicionar por Câmera'
                      : 'Fotografar: ${existingItem.name}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1º QUADRADO (CIMA): FOTO DO PREÇO (LÊ SOMENTE NÚMEROS)
                const Text(
                  '1. Foto do Preço (lê somente números)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryDarkGreen,
                  ),
                ),
                const SizedBox(height: 6),
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () async {
                    try {
                      final img = await ImagePicker().pickImage(
                        source: ImageSource.camera,
                        imageQuality: 85,
                      );
                      if (img == null) return;
                      setD(() {
                        readingPrice = true;
                        pricePhotoPreviewPath = img.path;
                      });
                      final suggestion = await OcrService.readImage(img.path);
                      final priceCents = _extractNumericPriceOnly(suggestion);
                      setD(() {
                        readingPrice = false;
                        numericCandidates = suggestion.candidates;
                        if (priceCents != null && priceCents > 0) {
                          priceCtrl.text = centsToInput(priceCents);
                        }
                      });
                    } on PlatformException catch (e) {
                      setD(() => readingPrice = false);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Erro na câmera: ${e.message ?? e.code}')),
                        );
                      }
                    } catch (_) {
                      setD(() => readingPrice = false);
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    height: 108,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.cardWhite,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: pricePhotoPreviewPath != null
                            ? AppTheme.accentGreen
                            : AppTheme.primaryDarkGreen,
                        width: 1.6,
                      ),
                    ),
                    child: readingPrice
                        ? const Center(
                            child: CircularProgressIndicator(color: AppTheme.primaryDarkGreen),
                          )
                        : Row(
                            children: [
                              Container(
                                width: 68,
                                height: 68,
                                decoration: BoxDecoration(
                                  color: AppTheme.lightGreen,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: pricePhotoPreviewPath != null &&
                                        File(pricePhotoPreviewPath!).existsSync()
                                    ? Image.file(
                                        File(pricePhotoPreviewPath!),
                                        fit: BoxFit.cover,
                                      )
                                    : const Icon(
                                        Icons.add,
                                        size: 36,
                                        color: AppTheme.primaryDarkGreen,
                                      ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      priceCtrl.text.isNotEmpty
                                          ? 'Preço lido: R\$ ${priceCtrl.text}'
                                          : 'Toque no "+" p/ fotografar o preço',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.primaryText,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'Captura apenas os números da etiqueta.',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.secondaryText,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                  ),
                ),

                if (numericCandidates.length > 1) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: [
                      for (final c in numericCandidates)
                        ActionChip(
                          backgroundColor: AppTheme.lightGreen,
                          label: Text(formatCents(c), style: const TextStyle(fontSize: 12)),
                          onPressed: () => setD(() => priceCtrl.text = centsToInput(c)),
                        ),
                    ],
                  ),
                ],

                const SizedBox(height: 14),

                // 2º QUADRADO (BAIXO): FOTO DO PRODUTO / NOME
                const Text(
                  '2. Foto do Produto (lê o nome e salva a foto)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryDarkGreen,
                  ),
                ),
                const SizedBox(height: 6),
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () async {
                    try {
                      final img = await ImagePicker().pickImage(
                        source: ImageSource.camera,
                        imageQuality: 80,
                      );
                      if (img == null) return;
                      setD(() => readingProduct = true);
                      final savedPath = await db.persistProductImage(img.path);
                      final suggestion = await OcrService.readImage(savedPath);
                      final extractedName = _extractProductNameOnly(suggestion);
                      setD(() {
                        readingProduct = false;
                        productPhotoPath = savedPath;
                        if (extractedName != null &&
                            extractedName.isNotEmpty &&
                            (existingItem == null || nameCtrl.text.trim().isEmpty)) {
                          nameCtrl.text = extractedName;
                          category = ProductCategory.detectCategory(extractedName);
                          unit = ProductCategory.suggestUnit(extractedName, category);
                        }
                      });
                    } on PlatformException catch (e) {
                      setD(() => readingProduct = false);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Erro na câmera: ${e.message ?? e.code}')),
                        );
                      }
                    } catch (_) {
                      setD(() => readingProduct = false);
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    height: 108,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.cardWhite,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: productPhotoPath != null
                            ? AppTheme.accentGreen
                            : AppTheme.primaryDarkGreen,
                        width: 1.6,
                      ),
                    ),
                    child: readingProduct
                        ? const Center(
                            child: CircularProgressIndicator(color: AppTheme.primaryDarkGreen),
                          )
                        : Row(
                            children: [
                              Container(
                                width: 68,
                                height: 68,
                                decoration: BoxDecoration(
                                  color: AppTheme.lightGreen,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: productPhotoPath != null &&
                                        File(productPhotoPath!).existsSync()
                                    ? Image.file(
                                        File(productPhotoPath!),
                                        fit: BoxFit.cover,
                                      )
                                    : const Icon(
                                        Icons.add,
                                        size: 36,
                                        color: AppTheme.primaryDarkGreen,
                                      ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      productPhotoPath != null
                                          ? 'Foto do produto adicionada!'
                                          : 'Toque no "+" p/ fotografar o produto',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.primaryText,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'Lê o nome e guarda a miniatura na lista.',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.secondaryText,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                  ),
                ),

                const Divider(height: 24),

                // Campos de conferência rápida (Nome e Preço numérico)
                TextField(
                  controller: nameCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Nome do produto',
                    prefixIcon: Icon(Icons.shopping_bag_outlined, color: AppTheme.accentGreen),
                  ),
                  onChanged: (v) {
                    setD(() {
                      category = ProductCategory.detectCategory(v);
                      unit = ProductCategory.suggestUnit(v, category);
                    });
                  },
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: priceCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Preço (R\$)',
                          prefixIcon: Icon(Icons.attach_money, color: AppTheme.primaryDarkGreen),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: qtyCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Qtd ($unit)',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.check),
              label: const Text('Confirmar'),
              onPressed: () {
                final finalName = nameCtrl.text.trim().isNotEmpty
                    ? nameCtrl.text.trim()
                    : (existingItem?.name ?? 'Produto fotografado');
                final q = double.tryParse(qtyCtrl.text.replaceAll(',', '.')) ??
                    (existingItem?.quantity ?? 1.0);
                final parsedPrice = priceCtrl.text.trim().isEmpty
                    ? (existingItem?.effectiveUnitPriceCents ?? 0)
                    : parseMoneyToCents(priceCtrl.text);

                Navigator.pop(
                  ctx,
                  ShoppingItem(
                    id: existingItem?.id,
                    name: finalName,
                    quantity: q > 0 ? q : 1.0,
                    unit: unit,
                    unitPriceCents: parsedPrice,
                    actualUnitPriceCents: parsedPrice > 0 ? parsedPrice : existingItem?.actualUnitPriceCents,
                    isBought: parsedPrice > 0 ? true : (existingItem?.isBought ?? false),
                    boughtQuantity: parsedPrice > 0 ? (q > 0 ? q : 1.0) : (existingItem?.boughtQuantity ?? 0.0),
                    category: category,
                    imagePath: productPhotoPath,
                    marketName: currentMarketName.isNotEmpty ? currentMarketName : existingItem?.marketName,
                    replacedBy: existingItem?.replacedBy,
                    originalItemId: existingItem?.originalItemId,
                    originalItemName: existingItem?.originalItemName,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );

    if (savedItem != null) {
      await db.saveItem(savedItem);
      await _load();
      // Atualiza também o arquivo JSON da vitrine em segundo plano
      SiteSyncService.buildVitrineJson();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✅ "${savedItem.name}" salvo com sucesso${savedItem.effectiveUnitPriceCents > 0 ? ' (${formatCents(savedItem.effectiveUnitPriceCents)})' : ''}!',
          ),
        ),
      );
    }
  }

  /// Abre a foto do produto GRANDE e NÍTIDA com zoom quando o usuário clica na miniatura do item
  Future<void> _showFullProductImageDialog(ShoppingItem item) async {
    if (item.imagePath == null || !File(item.imagePath!).existsSync()) return;

    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          decoration: AppTheme.cardDecoration(radius: 22),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Cabeçalho com Nome e Botão Fechar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: AppTheme.primaryDarkGreen,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            '${item.category}${item.marketName != null && item.marketName!.isNotEmpty ? ' • ${item.marketName}' : ''}',
                            style: const TextStyle(
                              color: AppTheme.lightGreen,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),

              // Foto Grande e Nítida com suporte a Zoom (Pinça)
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.62,
                ),
                child: InteractiveViewer(
                  minScale: 1.0,
                  maxScale: 4.0,
                  child: Image.file(
                    File(item.imagePath!),
                    width: double.infinity,
                    fit: BoxFit.contain,
                  ),
                ),
              ),

              // Rodapé com Preço e opção de trocar foto
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Preço registrado',
                          style: TextStyle(fontSize: 12, color: AppTheme.secondaryText),
                        ),
                        Text(
                          formatCents(item.effectiveUnitPriceCents),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primaryDarkGreen,
                          ),
                        ),
                      ],
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.camera_alt_outlined, size: 18),
                      label: const Text('Nova foto'),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _openTwoSquareCameraModal(item);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Diálogo para buscar a localização atual do usuário e selecionar o mercado
  Future<void> _openMarketLocationDialog() async {
    final nameCtrl = TextEditingController(text: currentMarketName);
    final locCtrl = TextEditingController(text: currentMarketLocation);
    final savedMarkets = await db.getSavedMarkets();
    List<MarketPlaceSuggestion> nearby = [];
    bool searchingGps = false;

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: AppTheme.creamBackground,
          title: const Row(
            children: [
              Icon(Icons.location_on, color: AppTheme.primaryDarkGreen),
              SizedBox(width: 8),
              Expanded(child: Text('Mercado e Localização')),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Botão para buscar localização e supermercados próximos automaticamente
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.lightGreen,
                      foregroundColor: AppTheme.primaryDarkGreen,
                    ),
                    icon: searchingGps
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location),
                    label: Text(
                      searchingGps
                          ? 'Buscando localização...'
                          : 'Buscar minha localização atual',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    onPressed: searchingGps
                        ? null
                        : () async {
                            setD(() => searchingGps = true);
                            final res = await LocationMarketService.detectLocationAndNearbyMarkets(
                              nameCtrl.text,
                            );
                            setD(() {
                              searchingGps = false;
                              if (locCtrl.text.trim().isEmpty) {
                                locCtrl.text = res.$1;
                              }
                              nearby = res.$2;
                            });
                          },
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nome do Supermercado',
                    hintText: 'Ex: Guanabara, Mundial, Assaí...',
                    prefixIcon: Icon(Icons.storefront, color: AppTheme.primaryDarkGreen),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: locCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Bairro / Cidade (Localização)',
                    hintText: 'Ex: Tijuca - Rio de Janeiro, RJ',
                    prefixIcon: Icon(Icons.place_outlined, color: AppTheme.accentGreen),
                  ),
                ),

                if (nearby.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const Text(
                    'Mercados encontrados próximos a você (toque p/ escolher):',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryDarkGreen,
                    ),
                  ),
                  const SizedBox(height: 6),
                  for (final m in nearby)
                    Card(
                      margin: const EdgeInsets.only(bottom: 6),
                      child: ListTile(
                        dense: true,
                        leading: const Icon(Icons.store, color: AppTheme.primaryDarkGreen),
                        title: Text(
                          m.name,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                        subtitle: Text(m.location, style: const TextStyle(fontSize: 11)),
                        onTap: () {
                          setD(() {
                            nameCtrl.text = m.name;
                            locCtrl.text = m.location;
                          });
                        },
                      ),
                    ),
                ],

                if (savedMarkets.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Mercados usados recentemente:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final sm in savedMarkets)
                        ActionChip(
                          backgroundColor: AppTheme.lightGreen,
                          label: Text(
                            sm['name'] ?? '',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryDarkGreen,
                            ),
                          ),
                          onPressed: () {
                            setD(() {
                              nameCtrl.text = sm['name'] ?? '';
                              locCtrl.text = sm['location'] ?? '';
                            });
                          },
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                await db.setCurrentMarket(nameCtrl.text, locCtrl.text);
                if (ctx.mounted) Navigator.pop(ctx);
                await _load();
              },
              child: const Text('Salvar Mercado'),
            ),
          ],
        ),
      ),
    );
  }

  /// Gera e sincroniza os dados da vitrine de preços e mercados para o site
  Future<void> _openSiteSyncDialog() async {
    final jsonStr = await SiteSyncService.buildVitrineJson();
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.creamBackground,
        title: const Row(
          children: [
            Icon(Icons.public, color: AppTheme.primaryDarkGreen),
            SizedBox(width: 8),
            Expanded(child: Text('Atualizar Vitrine do Site')),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.lightGreen,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  '✅ Os preços atuais, histórico de até 1 mês atrás, mercados e fotos dos produtos foram preparados em "vitrine_dados.json"!',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryDarkGreen,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'O arquivo foi salvo na pasta Downloads do celular (/sdcard/Download/vitrine_dados.json). Você também pode copiar os dados abaixo para atualizar o site pelo Termux:',
                style: TextStyle(fontSize: 12, color: AppTheme.secondaryText),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: jsonStr));
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Dados copiados para a área de transferência!')),
                );
              }
            },
            child: const Text('Copiar Dados'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Concluir'),
          ),
        ],
      ),
    );
  }

  /// Diálogo de adicionar ou editar produto manualmente
  Future<void> _editItem([ShoppingItem? old]) async {
    final name = TextEditingController(text: old?.name ?? '');
    final qty = TextEditingController(text: formatQuantity(old?.quantity ?? 1));
    final initialPrice = old?.actualUnitPriceCents ?? old?.unitPriceCents ?? 0;
    final price = TextEditingController(text: initialPrice > 0 ? centsToInput(initialPrice) : '');
    String unit = old?.unit ?? 'un';
    String category = old?.category ??
        (name.text.isNotEmpty ? ProductCategory.detectCategory(name.text) : ProductCategory.outros);
    bool manualCategory = old != null;

    final result = await showDialog<ShoppingItem>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: AppTheme.creamBackground,
          title: Text(old == null ? 'Adicionar produto' : 'Editar produto'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: name,
                  autofocus: old == null,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Nome do produto',
                    hintText: 'Ex: Peito de frango, Sabão, Leite...',
                  ),
                  onChanged: (val) {
                    if (!manualCategory) {
                      final detected = ProductCategory.detectCategory(val);
                      setD(() {
                        category = detected;
                        unit = ProductCategory.suggestUnit(val, detected);
                      });
                    }
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: const InputDecoration(labelText: 'Categoria'),
                  items: ProductCategory.all
                      .map((c) => DropdownMenuItem(
                            value: c,
                            child: Row(
                              children: [
                                Icon(ProductCategory.iconFor(c),
                                    size: 18, color: ProductCategory.colorFor(c)),
                                const SizedBox(width: 8),
                                Text(c),
                              ],
                            ),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setD(() {
                        manualCategory = true;
                        category = v;
                      });
                    }
                  },
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: qty,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Quantidade'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: unit,
                        decoration: const InputDecoration(labelText: 'Unidade'),
                        items: const [
                          DropdownMenuItem(value: 'un', child: Text('Unidade (un)')),
                          DropdownMenuItem(value: 'kg', child: Text('kg')),
                          DropdownMenuItem(value: 'g', child: Text('g')),
                          DropdownMenuItem(value: 'L', child: Text('Litro (L)')),
                          DropdownMenuItem(value: 'ml', child: Text('ml')),
                        ],
                        onChanged: (v) {
                          if (v != null) setD(() => unit = v);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: price,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Preço unitário estimado (R\$)',
                    hintText: 'Deixe vazio para ler na prateleira',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final q = double.tryParse(qty.text.replaceAll(',', '.'));
                if (name.text.trim().isEmpty || q == null || q <= 0) return;
                final parsedPrice = price.text.trim().isEmpty ? 0 : parseMoneyToCents(price.text);
                Navigator.pop(
                  ctx,
                  ShoppingItem(
                    id: old?.id,
                    name: name.text.trim(),
                    quantity: q,
                    unit: unit,
                    unitPriceCents: parsedPrice,
                    isBought: old?.isBought ?? false,
                    replacedBy: old?.replacedBy,
                    originalItemId: old?.originalItemId,
                    originalItemName: old?.originalItemName,
                    actualUnitPriceCents: parsedPrice > 0 ? parsedPrice : old?.actualUnitPriceCents,
                    category: category,
                    boughtQuantity: old?.boughtQuantity ?? 0.0,
                    imagePath: old?.imagePath,
                    marketName: old?.marketName,
                  ),
                );
              },
              child: const Text('Salvar alterações'),
            ),
          ],
        ),
      ),
    );
    if (result != null) {
      if (result.category != ProductCategory.outros) {
        await db.saveCustomCategoryItem(result.category, result.name);
      }
      await db.saveItem(result);
      await _load();
    }
  }

  Future<void> _changeQuantity(ShoppingItem item, int direction) async {
    if (item.replacedBy != null) return;
    final next = nextQuantity(item.quantity, item.unit, direction);
    if (next == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A quantidade precisa ser maior que zero.')),
      );
      return;
    }
    await db.saveItem(item.copyWith(
      quantity: next,
      boughtQuantity: item.isBought ? next : item.boughtQuantity,
    ));
    await _load();
  }

  Future<void> _replace(ShoppingItem item) async {
    final name = TextEditingController();
    final price = TextEditingController();
    final result = await showDialog<(String, int)>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.creamBackground,
        title: Text('Trocar ${item.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Nome do substituto'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: price,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Preço unitário (R\$)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              if (name.text.trim().isNotEmpty) {
                Navigator.pop(ctx, (name.text.trim(), parseMoneyToCents(price.text)));
              }
            },
            child: const Text('Substituir'),
          ),
        ],
      ),
    );
    if (result == null) return;
    await db.saveItem(item.copyWith(replacedBy: result.$1));
    await db.saveItem(ShoppingItem(
      name: result.$1,
      quantity: item.quantity,
      unit: item.unit,
      unitPriceCents: result.$2,
      category: ProductCategory.detectCategory(result.$1),
      originalItemId: item.id,
      originalItemName: item.name,
    ));
    await _load();
  }

  Future<void> _budgetDialog() async {
    final controller = TextEditingController(text: budget > 0 ? centsToInput(budget) : '');
    final spentRatio = budget > 0 ? (boughtTotal / budget).clamp(0.0, 1.0) : 0.0;
    final spentPct = (spentRatio * 100).round();

    final value = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.creamBackground,
        title: const Text('Orçamento da Lista'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (budget > 0) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: AppTheme.cardDecoration(radius: 14, withShadow: false),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Orçamento definido',
                        style: TextStyle(fontSize: 12, color: AppTheme.secondaryText),
                      ),
                      Text(
                        formatCents(budget),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primaryDarkGreen,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Gasto até agora: ${formatCents(boughtTotal)}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.accentGreen,
                            ),
                          ),
                          Text(
                            '$spentPct%',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryDarkGreen,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: spentRatio,
                          minHeight: 8,
                          backgroundColor: AppTheme.lightGreen,
                          color: boughtTotal > budget ? AppTheme.alertRed : AppTheme.accentGreen,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Definir / Editar orçamento (R\$)',
                  hintText: 'Ex: 200,00',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, parseMoneyToCents(controller.text)),
            child: const Text('Salvar orçamento'),
          ),
        ],
      ),
    );
    if (value != null) {
      await db.setBudget(value);
      await _load();
    }
  }

  Future<void> _confirmAndShowReceiptScreen() async {
    final selectedItems = activeItems.where((i) => i.isFullyBought || i.isPartiallyBought).toList();
    if (selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione os produtos (ou marque "Selecionar tudo") antes de finalizar.'),
        ),
      );
      return;
    }

    final totalSpentCents = selectedItems.fold<int>(0, (sum, i) => sum + i.subtotalCents);
    final now = DateTime.now();
    final dateFormatted = DateFormat("dd/MM/yyyy 'às' HH:mm", 'pt_BR').format(now);
    final dayOfWeek = DateFormat('EEEE', 'pt_BR').format(now);
    final itemsSnapshot = List<ShoppingItem>.from(selectedItems);

    try {
      await db.finishPurchase();
      await _load();
      SiteSyncService.buildVitrineJson();
      if (!mounted) return;

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => Dialog.fullscreen(
          backgroundColor: AppTheme.creamBackground,
          child: Scaffold(
            backgroundColor: AppTheme.creamBackground,
            appBar: AppBar(
              title: const Text('Resumo da Compra'),
              automaticallyImplyLeading: false,
            ),
            body: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const SizedBox(height: 8),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: const BoxDecoration(
                      color: AppTheme.lightGreen,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_circle, size: 68, color: AppTheme.primaryDarkGreen),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Compra Confirmada!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryDarkGreen,
                  ),
                ),
                if (currentMarketName.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    '📍 $currentMarketName${currentMarketLocation.isNotEmpty ? ' ($currentMarketLocation)' : ''}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.accentGreen,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: AppTheme.cardDecoration(radius: 18),
                  child: Column(
                    children: [
                      const Text(
                        'TOTAL QUE VOCÊ GASTOU',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.secondaryText,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        formatCents(totalSpentCents),
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primaryDarkGreen,
                        ),
                      ),
                      const Divider(height: 28),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.calendar_today, size: 18, color: AppTheme.accentGreen),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Dia: $dateFormatted',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primaryText,
                                ),
                              ),
                              Text(
                                dayOfWeek.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.secondaryText,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Itens comprados (${itemsSnapshot.length}):',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryText,
                  ),
                ),
                const SizedBox(height: 10),
                for (final it in itemsSnapshot)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: AppTheme.cardDecoration(radius: 14, withShadow: false),
                    child: ListTile(
                      leading: it.imagePath != null && File(it.imagePath!).existsSync()
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.file(
                                File(it.imagePath!),
                                width: 44,
                                height: 44,
                                fit: BoxFit.cover,
                              ),
                            )
                          : CircleAvatar(
                              backgroundColor: AppTheme.lightGreen,
                              child: Icon(
                                ProductCategory.iconFor(it.category),
                                color: AppTheme.primaryDarkGreen,
                                size: 20,
                              ),
                            ),
                      title: Text(
                        it.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryText,
                        ),
                      ),
                      subtitle: Text(
                        '${formatQuantity(it.quantity)} ${it.unit} • ${it.category}',
                        style: const TextStyle(color: AppTheme.secondaryText),
                      ),
                      trailing: Text(
                        formatCents(it.subtotalCents),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: AppTheme.primaryDarkGreen,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.check),
                  label: const Text('Concluir e Voltar ao Início'),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  /// Cartão do Produto na Página Principal:
  /// Mostra a FOTO DO PRODUTO visível (clicável para ampliar com nitidez!),
  /// controles de quantidade [-] 1 kg [+] e o botão de câmera que abre a janela de 2 quadrados!
  Widget _buildProductCard(ShoppingItem item) {
    final replaced = item.replacedBy != null;
    final catColor = ProductCategory.colorFor(item.category);
    final catIcon = ProductCategory.iconFor(item.category);
    final unitPrice = item.actualUnitPriceCents ?? item.unitPriceCents;
    final hasPhoto = item.imagePath != null && File(item.imagePath!).existsSync();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: AppTheme.cardDecoration(radius: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (replaced)
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.swap_horiz, color: AppTheme.softOrange),
                  )
                else
                  Checkbox(
                    value: item.isFullyBought,
                    onChanged: (v) => _toggleItemCheckbox(item, v ?? false),
                  ),

                // MINIATURA VISÍVEL DA FOTO DO PRODUTO (Toque para ver grande e nítida!)
                GestureDetector(
                  onTap: hasPhoto
                      ? () => _showFullProductImageDialog(item)
                      : () => _openTwoSquareCameraModal(item),
                  child: Stack(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: catColor.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: hasPhoto ? AppTheme.accentGreen : AppTheme.subtleBorder,
                            width: hasPhoto ? 1.5 : 1.0,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: hasPhoto
                            ? Image.file(
                                File(item.imagePath!),
                                fit: BoxFit.cover,
                              )
                            : Icon(catIcon, color: catColor, size: 26),
                      ),
                      if (hasPhoto)
                        Positioned(
                          right: 2,
                          bottom: 2,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.65),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(
                              Icons.zoom_in,
                              size: 13,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Nome, Categoria e Preço
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: replaced ? AppTheme.secondaryText : AppTheme.primaryText,
                          decoration: replaced ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: catColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              item.category,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: catColor,
                              ),
                            ),
                          ),
                          if (item.isFullyBought)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.lightGreen,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Comprado',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primaryDarkGreen,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (replaced)
                        Text(
                          'Substituído por ${item.replacedBy}',
                          style: const TextStyle(fontSize: 12, color: AppTheme.secondaryText),
                        )
                      else ...[
                        Text(
                          item.actualUnitPriceCents != null
                              ? 'Preço unitário confirmado'
                              : 'Preço unitário estimado',
                          style: const TextStyle(fontSize: 11, color: AppTheme.secondaryText),
                        ),
                        Row(
                          children: [
                            Text(
                              formatCents(unitPrice),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.primaryText,
                              ),
                            ),
                            if (item.quantity != 1) ...[
                              const SizedBox(width: 6),
                              Text(
                                '• Sub: ${formatCents(item.subtotalCents)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.accentGreen,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                // Menu de opções
                if (!replaced)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: AppTheme.secondaryText),
                    onSelected: (v) async {
                      if (v == 'view_photo' && hasPhoto) {
                        await _showFullProductImageDialog(item);
                      }
                      if (v == 'camera') await _openTwoSquareCameraModal(item);
                      if (v == 'edit') await _editItem(item);
                      if (v == 'replace') await _replace(item);
                      if (v == 'delete') {
                        final yes = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: AppTheme.creamBackground,
                            title: const Text('Excluir produto?'),
                            content: Text('Deseja remover ${item.name} da lista?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancelar'),
                              ),
                              FilledButton(
                                style: FilledButton.styleFrom(backgroundColor: AppTheme.alertRed),
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Remover da lista'),
                              ),
                            ],
                          ),
                        );
                        if (yes == true && item.id != null) {
                          await db.deleteItem(item.id!);
                          await _load();
                        }
                      }
                    },
                    itemBuilder: (_) => [
                      if (hasPhoto)
                        const PopupMenuItem(value: 'view_photo', child: Text('Ver foto ampliada')),
                      const PopupMenuItem(value: 'camera', child: Text('Fotografar preço / produto')),
                      const PopupMenuItem(value: 'edit', child: Text('Detalhes / Editar')),
                      const PopupMenuItem(value: 'replace', child: Text('Trocar produto')),
                      const PopupMenuItem(value: 'delete', child: Text('Remover da lista')),
                    ],
                  ),
              ],
            ),

            // Controles inferiores: Cápsula [-] 1 kg [+] e Botão de Câmera (abre os 2 quadradinhos!)
            if (!replaced) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (hasPhoto)
                    InkWell(
                      onTap: () => _showFullProductImageDialog(item),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: Text(
                          '🔍 Toque na foto p/ ampliar',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.accentGreen,
                          ),
                        ),
                      ),
                    )
                  else
                    const SizedBox.shrink(),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.creamBackground,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppTheme.subtleBorder),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: nextQuantity(item.quantity, item.unit, -1) == null
                                  ? null
                                  : () => _changeQuantity(item, -1),
                              child: Padding(
                                padding: const EdgeInsets.all(6),
                                child: Icon(
                                  Icons.remove,
                                  size: 16,
                                  color: nextQuantity(item.quantity, item.unit, -1) == null
                                      ? AppTheme.subtleBorder
                                      : AppTheme.primaryText,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: Text(
                                '${formatQuantity(item.quantity)} ${item.unit}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primaryText,
                                ),
                              ),
                            ),
                            InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => _changeQuantity(item, 1),
                              child: const Padding(
                                padding: EdgeInsets.all(6),
                                child: Icon(
                                  Icons.add,
                                  size: 16,
                                  color: AppTheme.primaryDarkGreen,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Ícone de Câmera dentro do quadrado do item: abre os 2 quadradinhos (Preço e Foto)
                      InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => _openTwoSquareCameraModal(item),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: AppTheme.lightGreen,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppTheme.accentGreen.withOpacity(0.3)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.camera_alt, size: 16, color: AppTheme.primaryDarkGreen),
                              SizedBox(width: 5),
                              Text(
                                'Foto/Preço',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primaryDarkGreen,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMainTab() {
    final screenHeight = MediaQuery.of(context).size.height;
    final bannerHeight = (screenHeight * 0.23).clamp(175.0, 230.0);

    final over = budget > 0 && total > budget;
    final totalDistinct = activeItems.length;
    final boughtDistinct = activeItems.where((i) => i.isFullyBought).length;
    final remainingDistinct = totalDistinct - boughtDistinct;

    final progressRatio = budget > 0
        ? (total / budget).clamp(0.0, 1.0)
        : (totalDistinct == 0 ? 0.0 : (boughtDistinct / totalDistinct).clamp(0.0, 1.0));
    final progressPercentage = (progressRatio * 100).round();

    // IMPORTANTE: items já vem ordenado por `id DESC` do banco, garantindo que
    // TODO item recém-adicionado fique sempre no TOPO da lista!
    final filteredItems = _selectedCategoryFilter == 'Todos'
        ? items
        : items.where((i) => i.category == _selectedCategoryFilter).toList();

    return RefreshIndicator(
      color: AppTheme.primaryDarkGreen,
      onRefresh: _load,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // 1. BANNER FOTOGRÁFICO + CARTÃO DE RESUMO FINANCEIRO
          Stack(
            clipBehavior: Clip.none,
            children: [
              SizedBox(
                height: bannerHeight,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      AppTheme.bannerAsset,
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                      errorBuilder: (_, __, ___) => Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppTheme.primaryDarkGreen, AppTheme.accentGreen],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.65),
                            Colors.black.withOpacity(0.25),
                            Colors.black.withOpacity(0.45),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 10, 12, 0),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Compras Inteligentes',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            shadows: [
                              Shadow(
                                color: Colors.black54,
                                blurRadius: 6,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.28),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          tooltip: 'Publicar preços no site',
                          icon: const Icon(Icons.public, color: Colors.white),
                          onPressed: _openSiteSyncDialog,
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.28),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          tooltip: 'Comparador de preços',
                          icon: const Icon(Icons.compare_arrows, color: Colors.white),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ComparatorScreen()),
                          ),
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.28),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          tooltip: 'Histórico de compras',
                          icon: const Icon(Icons.history, color: Colors.white),
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const HistoryScreen()),
                            );
                            await _load();
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              Padding(
                padding: EdgeInsets.fromLTRB(16, bannerHeight - 48, 16, 0),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: AppTheme.cardDecoration(radius: 20),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          flex: 5,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                'Total da lista',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.secondaryText,
                                ),
                              ),
                              const SizedBox(height: 2),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  formatCents(total),
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.primaryDarkGreen,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              InkWell(
                                onTap: _budgetDialog,
                                borderRadius: BorderRadius.circular(6),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 2),
                                  child: Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          budget == 0
                                              ? 'Orçamento: Definir'
                                              : 'Orçamento: ${formatCents(budget)}',
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: over ? AppTheme.alertRed : AppTheme.secondaryText,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(
                                        Icons.edit_outlined,
                                        size: 13,
                                        color: AppTheme.accentGreen,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: LinearProgressIndicator(
                                        value: progressRatio,
                                        minHeight: 7,
                                        backgroundColor: AppTheme.lightGreen,
                                        color: over ? AppTheme.alertRed : AppTheme.accentGreen,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '$progressPercentage%',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.primaryText,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 1,
                          margin: const EdgeInsets.symmetric(horizontal: 14),
                          color: AppTheme.subtleBorder,
                        ),
                        Expanded(
                          flex: 5,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.account_balance_wallet_outlined,
                                    size: 15,
                                    color: AppTheme.accentGreen,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Comprado: ${formatCents(boughtTotal)}',
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.primaryText,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.account_balance_wallet_outlined,
                                    size: 15,
                                    color: AppTheme.lightWood,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Pendente: ${formatCents((total - boughtTotal) < 0 ? 0 : (total - boughtTotal))}',
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.secondaryText,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 16),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.check_circle,
                                    size: 16,
                                    color: AppTheme.accentGreen,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '$boughtDistinct concluídos',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.accentGreen,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.schedule,
                                    size: 16,
                                    color: AppTheme.softOrange,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '$remainingDistinct pendentes',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.softOrange,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          // 2. CORPO DA TELA PRINCIPAL
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Barra de Localização / Mercado Atual
                InkWell(
                  onTap: _openMarketLocationDialog,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.lightGreen,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.subtleBorder),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on, size: 18, color: AppTheme.primaryDarkGreen),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            currentMarketName.isEmpty
                                ? 'Toque p/ buscar sua localização e definir o mercado'
                                : '$currentMarketName${currentMarketLocation.isNotEmpty ? ' • $currentMarketLocation' : ''}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryDarkGreen,
                            ),
                          ),
                        ),
                        const Icon(Icons.my_location, size: 16, color: AppTheme.accentGreen),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Botões Principais: [+ Adicionar] e [📷 Fotografar]
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.primaryDarkGreen,
                          foregroundColor: AppTheme.cardWhite,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        onPressed: _openQuickAdd,
                        icon: const Icon(Icons.add_circle_outline, size: 20),
                        label: const Text('Adicionar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: AppTheme.cardWhite,
                          foregroundColor: AppTheme.primaryDarkGreen,
                          side: const BorderSide(color: AppTheme.primaryDarkGreen, width: 1.3),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        onPressed: () => _openTwoSquareCameraModal(),
                        icon: const Icon(Icons.camera_alt_outlined, size: 20),
                        label: const Text('Fotografar'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Botão: [✓ Finalizar compra]
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: AppTheme.cardWhite,
                      foregroundColor: AppTheme.primaryText,
                      side: const BorderSide(color: AppTheme.subtleBorder, width: 1.3),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    onPressed: _confirmAndShowReceiptScreen,
                    icon: const Icon(
                      Icons.check_circle_outline,
                      color: AppTheme.primaryDarkGreen,
                      size: 20,
                    ),
                    label: const Text(
                      'Finalizar compra',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryText,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Barra de Filtros de Categorias
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildCategoryFilterChip(
                        label: 'Todos',
                        icon: Icons.shopping_basket_outlined,
                        color: AppTheme.primaryDarkGreen,
                        isSelected: _selectedCategoryFilter == 'Todos',
                        onTap: () => setState(() => _selectedCategoryFilter = 'Todos'),
                      ),
                      for (final cat in ProductCategory.all)
                        if (items.any((i) => i.category == cat))
                          _buildCategoryFilterChip(
                            label: cat,
                            icon: ProductCategory.iconFor(cat),
                            color: ProductCategory.colorFor(cat),
                            isSelected: _selectedCategoryFilter == cat,
                            onTap: () => setState(() => _selectedCategoryFilter = cat),
                          ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Barra "Selecionar tudo (Select All)"
                if (activeItems.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: AppTheme.cardDecoration(
                      color: isAllSelected ? AppTheme.lightGreen : AppTheme.cardWhite,
                      borderColor: isAllSelected ? AppTheme.accentGreen : AppTheme.subtleBorder,
                      radius: 14,
                      withShadow: false,
                    ),
                    child: CheckboxListTile(
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: isAllSelected,
                      onChanged: (val) => _toggleSelectAll(val ?? false),
                      title: const Text(
                        'Selecionar tudo (Select All)',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppTheme.primaryText,
                        ),
                      ),
                      subtitle: Text(
                        isAllSelected
                            ? 'Todos os $totalDistinct itens selecionados!'
                            : 'Marque para selecionar todos os itens de uma vez.',
                        style: const TextStyle(fontSize: 12, color: AppTheme.secondaryText),
                      ),
                      secondary: isAllSelected
                          ? FilledButton(
                              style: FilledButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              onPressed: _confirmAndShowReceiptScreen,
                              child: const Text('Confirmar', style: TextStyle(fontSize: 12)),
                            )
                          : null,
                    ),
                  ),

                if (activeItems.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(28),
                    decoration: AppTheme.cardDecoration(radius: 18, withShadow: false),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: const BoxDecoration(
                            color: AppTheme.lightGreen,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.shopping_basket_outlined,
                            size: 40,
                            color: AppTheme.primaryDarkGreen,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Sua lista está vazia',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryText,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Toque em "Adicionar" ou "Fotografar" para montar sua lista.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: AppTheme.secondaryText),
                        ),
                      ],
                    ),
                  ),

                // Cartões dos Produtos (Itens recém-adicionados SEMPRE no topo!)
                for (final item in filteredItems) _buildProductCard(item),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilterChip({
    required String label,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryDarkGreen : AppTheme.cardWhite,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? AppTheme.primaryDarkGreen : AppTheme.subtleBorder,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? AppTheme.cardWhite : color,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? AppTheme.cardWhite : AppTheme.primaryText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.primaryDarkGreen),
        ),
      );
    }

    return Scaffold(
      appBar: _currentTabIndex == 0
          ? null
          : AppBar(
              title: Text(
                _currentTabIndex == 1 ? 'Faltam Comprar' : 'Próximo Item',
              ),
              actions: [
                IconButton(
                  tooltip: 'Publicar preços no site',
                  onPressed: _openSiteSyncDialog,
                  icon: const Icon(Icons.public),
                ),
                IconButton(
                  tooltip: 'Comparador',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ComparatorScreen()),
                  ),
                  icon: const Icon(Icons.compare_arrows),
                ),
                IconButton(
                  tooltip: 'Histórico',
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const HistoryScreen()),
                    );
                    await _load();
                  },
                  icon: const Icon(Icons.history),
                ),
              ],
            ),
      body: IndexedStack(
        index: _currentTabIndex,
        children: [
          _buildMainTab(),
          PendingTab(
            items: items,
            onConfirmPurchase: (item) => _toggleItemCheckbox(item, !item.isFullyBought),
            onScanItem: (target) => _openTwoSquareCameraModal(target),
          ),
          NextItemTab(
            items: items,
            onConfirmPurchase: (item) => _toggleItemCheckbox(item, true),
            onScanItem: (target) => _openTwoSquareCameraModal(target),
            onFinishPurchase: _confirmAndShowReceiptScreen,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentTabIndex,
        onDestinationSelected: (idx) => setState(() => _currentTabIndex = idx),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.shopping_bag_outlined),
            selectedIcon: Icon(Icons.shopping_bag),
            label: 'Minha Lista',
          ),
          NavigationDestination(
            icon: Icon(Icons.fact_check_outlined),
            selectedIcon: Icon(Icons.fact_check),
            label: 'Faltam Comprar',
          ),
          NavigationDestination(
            icon: Icon(Icons.play_circle_outline),
            selectedIcon: Icon(Icons.play_circle),
            label: 'Próximo Item',
          ),
        ],
      ),
    );
  }
}
