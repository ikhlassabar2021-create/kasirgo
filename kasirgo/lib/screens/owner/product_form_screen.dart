import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:barcode/barcode.dart' as bc;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import '../../config/app_theme.dart';
import '../../models/product.dart';
import '../../providers/auth_provider.dart';
import '../../services/supabase_service.dart';
import '../../utils/validators.dart';
import 'product_list_screen.dart' show productsProvider;

class ProductFormScreen extends ConsumerStatefulWidget {
  final Product? product;

  const ProductFormScreen({super.key, this.product});

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  late final TextEditingController _costPriceController;
  late final TextEditingController _stockController;
  late final TextEditingController _barcodeController;
  late final TextEditingController _unitController;

  String? _selectedCategory;
  DateTime? _expiredDate;
  String? _imageLocalPath;
  bool _isLoading = false;

  final _categories = [
    'Makanan',
    'Minuman',
    'Sembako',
    'Rokok',
    'Kebersihan',
    'Kesehatan',
    'Lainnya',
  ];

  static const _channels = [
    'offline',
    'tokopedia',
    'shopee',
    'blibli',
    'gofood',
    'grabfood',
    'shopeefood',
  ];

  final Map<String, TextEditingController> _channelPriceControllers = {};
  final Map<String, TextEditingController> _channelFeeControllers = {};

  final TextEditingController _discountPercentController = TextEditingController();
  final TextEditingController _discountAmountController = TextEditingController();
  DateTime? _discountStartDate;
  DateTime? _discountEndDate;
  bool _isFlashSale = false;
  String? _existingDiscountId;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameController = TextEditingController(text: p?.name ?? '');
    _priceController = TextEditingController(text: p != null ? p.price.toStringAsFixed(0) : '');
    _costPriceController = TextEditingController(
      text: p?.costPrice != null ? p!.costPrice!.toStringAsFixed(0) : '',
    );
    _stockController = TextEditingController(text: p != null ? p.stock.toString() : '0');
    _barcodeController = TextEditingController(text: p?.barcode ?? '');
    _unitController = TextEditingController(text: p?.unit ?? 'pcs');
    _selectedCategory = p?.category ?? 'Makanan';
    if (_selectedCategory != null && !_categories.contains(_selectedCategory)) {
      _categories.add(_selectedCategory!);
    }
    _expiredDate = p?.expiredDate;
    _imageLocalPath = kIsWeb ? null : p?.imageLocalPath;

    for (final ch in _channels) {
      _channelPriceControllers[ch] = TextEditingController();
      _channelFeeControllers[ch] = TextEditingController(text: ch == 'offline' ? '0' : '');
    }

    if (p != null && p.id.isNotEmpty) {
      _loadChannelPrices(p.id);
      _loadProductDiscount(p.id);
    }
  }

  Future<void> _loadChannelPrices(String productId) async {
    try {
      final client = sb.Supabase.instance.client;
      final res = await client
          .from('product_prices')
          .select('channel, price, platform_fee_percent')
          .eq('product_id', productId);
      final list = res as List<dynamic>;
      for (final row in list) {
        final ch = row['channel'] as String?;
        if (ch != null && _channelPriceControllers.containsKey(ch)) {
          final price = (row['price'] as num?)?.toDouble();
          final fee = (row['platform_fee_percent'] as num?)?.toDouble();
          if (price != null) {
            _channelPriceControllers[ch]?.text = price.toStringAsFixed(0);
          }
          if (fee != null) {
            _channelFeeControllers[ch]?.text = fee.toStringAsFixed(1);
          }
        }
      }
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _loadProductDiscount(String productId) async {
    try {
      final client = sb.Supabase.instance.client;
      final res = await client
          .from('product_discounts')
          .select('id, discount_percent, discount_amount, start_date, end_date, is_flash_sale')
          .eq('product_id', productId)
          .order('end_date', ascending: false)
          .limit(1)
          .maybeSingle();

      if (res != null) {
        _existingDiscountId = res['id'] as String?;
        final pVal = (res['discount_percent'] as num?)?.toDouble();
        final aVal = (res['discount_amount'] as num?)?.toDouble();
        if (pVal != null && pVal > 0) {
          _discountPercentController.text = pVal.toStringAsFixed(1);
        }
        if (aVal != null && aVal > 0) {
          _discountAmountController.text = aVal.toStringAsFixed(0);
        }
        if (res['start_date'] != null) {
          _discountStartDate = DateTime.tryParse(res['start_date'] as String)?.toLocal();
        }
        if (res['end_date'] != null) {
          _discountEndDate = DateTime.tryParse(res['end_date'] as String)?.toLocal();
        }
        _isFlashSale = res['is_flash_sale'] as bool? ?? false;
        if (mounted) setState(() {});
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _costPriceController.dispose();
    _stockController.dispose();
    _barcodeController.dispose();
    _unitController.dispose();
    for (final c in _channelPriceControllers.values) {
      c.dispose();
    }
    for (final c in _channelFeeControllers.values) {
      c.dispose();
    }
    _discountPercentController.dispose();
    _discountAmountController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, maxWidth: 800, imageQuality: 85);
      if (picked == null) return;

      String finalPath;
      if (!kIsWeb) {
        final dir = await getApplicationDocumentsDirectory();
        final ext = picked.path.split('.').last;
        final fileName = 'prod_${DateTime.now().millisecondsSinceEpoch}.$ext';
        final savedFile = await File(picked.path).copy('${dir.path}/$fileName');
        finalPath = savedFile.path;
      } else {
        finalPath = picked.path;
      }

      setState(() {
        _imageLocalPath = finalPath;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengambil foto: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              InkWell(
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera);
                },
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: AppTheme.primaryColor,
                      child: Icon(Icons.camera_alt, color: Colors.white, size: 28),
                    ),
                    SizedBox(height: 8),
                    Text('Kamera'),
                  ],
                ),
              ),
              InkWell(
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.gallery);
                },
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: AppTheme.secondaryColor,
                      child: Icon(Icons.photo_library, color: Colors.white, size: 28),
                    ),
                    SizedBox(height: 8),
                    Text('Galeri'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openBarcodeScanner() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: AppTheme.surfaceColor,
          insetPadding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: SizedBox(
            height: 400,
            child: Column(
              children: [
                AppBar(
                  title: const Text('Arahkan Barcode ke Kamera', style: TextStyle(fontSize: 16)),
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  automaticallyImplyLeading: false,
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(dialogContext),
                    ),
                  ],
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: MobileScanner(
                      onDetect: (capture) {
                        for (final barcode in capture.barcodes) {
                          final code = barcode.rawValue ?? barcode.displayValue;
                          if (code != null && code.isNotEmpty) {
                            setState(() {
                              _barcodeController.text = code;
                            });
                            Navigator.pop(dialogContext);
                            break;
                          }
                        }
                      },
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'Posisikan barcode di dalam frame kamera',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _generateBarcode() {
    final rand = Random();
    final number = '899${rand.nextInt(90000000) + 10000000}${rand.nextInt(9)}';
    final barcodeObj = bc.Barcode.code128();
    if (barcodeObj.isValid(number)) {
      setState(() {
        _barcodeController.text = number;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Barcode dibuat: $number'),
          backgroundColor: AppTheme.primaryColor,
        ),
      );
    }
  }

  Future<void> _selectExpiredDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiredDate ?? now.add(const Duration(days: 90)),
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 10)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.primaryColor,
              surface: AppTheme.surfaceColor,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _expiredDate = picked;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(currentUserProvider);
    final outletId = user?.outletId;
    if (outletId == null || outletId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Outlet ID tidak valid'), backgroundColor: AppTheme.errorColor),
      );
      return;
    }

    setState(() => _isLoading = true);

    final product = Product(
      id: widget.product?.id ?? '',
      outletId: outletId,
      name: _nameController.text.trim(),
      category: _selectedCategory,
      barcode: _barcodeController.text.trim().isEmpty ? null : _barcodeController.text.trim(),
      costPrice: double.tryParse(_costPriceController.text),
      basePrice: double.tryParse(_priceController.text) ?? 0.0,
      stock: int.tryParse(_stockController.text) ?? 0,
      unit: _unitController.text.trim().isEmpty ? 'pcs' : _unitController.text.trim(),
      expiredDate: _expiredDate,
      imageLocalPath: kIsWeb ? null : _imageLocalPath,
      thumbKey: widget.product?.thumbKey,
      isActive: true,
    );

    final service = SupabaseService();
    Product? result;
    if (widget.product != null && widget.product!.id.isNotEmpty) {
      result = await service.updateProduct(product);
    } else {
      result = await service.createProduct(product);
    }

    if (result != null && result.id.isNotEmpty) {
      await _saveChannelPrices(result.id);
      await _saveProductDiscount(result.id);
    }

    setState(() => _isLoading = false);

    if (mounted) {
      if (result != null) {
        ref.invalidate(productsProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.product != null ? 'Produk berhasil diperbarui' : 'Produk berhasil ditambahkan',
            ),
            backgroundColor: AppTheme.successColor,
          ),
        );
        context.pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal menyimpan produk ke server'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _saveChannelPrices(String productId) async {
    try {
      final client = sb.Supabase.instance.client;
      for (final ch in _channels) {
        final priceText = _channelPriceControllers[ch]?.text.trim() ?? '';
        final feeText = _channelFeeControllers[ch]?.text.trim() ?? '';
        final price = double.tryParse(priceText);
        final fee = double.tryParse(feeText) ?? 0.0;

        if (price != null && price > 0) {
          final existing = await client
              .from('product_prices')
              .select('id')
              .eq('product_id', productId)
              .eq('channel', ch)
              .maybeSingle();

          if (existing != null) {
            await client.from('product_prices').update({
              'price': price,
              'platform_fee_percent': fee,
            }).eq('id', existing['id']);
          } else {
            await client.from('product_prices').insert({
              'product_id': productId,
              'channel': ch,
              'price': price,
              'platform_fee_percent': fee,
            });
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _saveProductDiscount(String productId) async {
    try {
      final client = sb.Supabase.instance.client;
      final pct = double.tryParse(_discountPercentController.text.trim());
      final amt = double.tryParse(_discountAmountController.text.trim());

      final hasDiscount = (pct != null && pct > 0) || (amt != null && amt > 0);
      if (!hasDiscount) {
        if (_existingDiscountId != null) {
          await client.from('product_discounts').delete().eq('id', _existingDiscountId!);
        }
        return;
      }

      final start = _discountStartDate ?? DateTime.now();
      final end = _discountEndDate ?? DateTime.now().add(const Duration(days: 7));

      final data = {
        'product_id': productId,
        'discount_percent': pct,
        'discount_amount': amt,
        'start_date': start.toUtc().toIso8601String(),
        'end_date': end.toUtc().toIso8601String(),
        'is_flash_sale': _isFlashSale,
      };

      if (_existingDiscountId != null) {
        await client.from('product_discounts').update(data).eq('id', _existingDiscountId!);
      } else {
        await client.from('product_discounts').insert(data);
      }
    } catch (_) {}
  }

  Widget _buildImagePreview() {
    Widget imageWidget;
    if (_imageLocalPath != null && _imageLocalPath!.isNotEmpty) {
      if (kIsWeb) {
        imageWidget = Image.network(
          _imageLocalPath!,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => const Icon(
            Icons.check_circle,
            color: AppTheme.successColor,
            size: 36,
          ),
        );
      } else {
        final file = File(_imageLocalPath!);
        if (file.existsSync()) {
          imageWidget = Image.file(file, fit: BoxFit.cover);
        } else {
          imageWidget = const Icon(Icons.broken_image, color: AppTheme.textSecondary, size: 36);
        }
      }
    } else {
      imageWidget = const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_a_photo, color: AppTheme.primaryColor, size: 32),
          SizedBox(height: 4),
          Text('Foto Produk', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
        ],
      );
    }

    return Center(
      child: Stack(
        children: [
          InkWell(
            onTap: _showImageSourceDialog,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.primaryColor.withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: imageWidget,
            ),
          ),
          if (_imageLocalPath != null && _imageLocalPath!.isNotEmpty)
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: () => setState(() => _imageLocalPath = null),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.black87,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 14),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildChannelPricingSection() {
    final cost = double.tryParse(_costPriceController.text) ?? 0.0;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.storefront, color: AppTheme.primaryColor, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Harga per Channel',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Atur harga jual dan potongan platform tiap channel untuk melihat margin bersih.',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 12),
          ..._channels.map((ch) {
            final priceCtrl = _channelPriceControllers[ch]!;
            final feeCtrl = _channelFeeControllers[ch]!;
            final price = double.tryParse(priceCtrl.text) ?? 0.0;
            final fee = double.tryParse(feeCtrl.text) ?? 0.0;
            final netReceive = price * (1 - (fee / 100));
            final margin = netReceive - cost;
            final marginPercent = price > 0 ? (margin / price) * 100 : 0.0;

            final channelLabel = switch (ch) {
              'offline' => 'Offline (Toko)',
              'tokopedia' => 'Tokopedia',
              'shopee' => 'Shopee',
              'blibli' => 'Blibli',
              'gofood' => 'GoFood',
              'grabfood' => 'GrabFood',
              'shopeefood' => 'ShopeeFood',
              _ => ch,
            };

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.backgroundColor.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    channelLabel,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          controller: priceCtrl,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            isDense: true,
                            labelText: 'Harga (Rp)',
                            hintText: _priceController.text.isNotEmpty ? _priceController.text : '0',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: feeCtrl,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            isDense: true,
                            labelText: 'Fee %',
                            hintText: '0',
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (price > 0) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Terima: Rp ${netReceive.toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                        ),
                        Text(
                          'Margin: Rp ${margin.toStringAsFixed(0)} (${marginPercent.toStringAsFixed(1)}%)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: margin >= 0 ? AppTheme.successColor : AppTheme.errorColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDiscountSection() {
    final basePrice = double.tryParse(_priceController.text) ?? 0.0;
    final pct = double.tryParse(_discountPercentController.text) ?? 0.0;
    final amt = double.tryParse(_discountAmountController.text) ?? 0.0;

    double finalDiscountedPrice = basePrice;
    if (pct > 0) {
      finalDiscountedPrice = basePrice * (1 - (pct / 100));
    } else if (amt > 0) {
      finalDiscountedPrice = (basePrice - amt).clamp(0, double.infinity);
    }

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_offer, color: AppTheme.accentColor, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Diskon & Promo',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Atur diskon persentase atau nominal, periode berlaku, dan label Flash Sale.',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _discountPercentController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (val) {
                    if (val.isNotEmpty && _discountAmountController.text.isNotEmpty) {
                      _discountAmountController.clear();
                    }
                    setState(() {});
                  },
                  decoration: const InputDecoration(
                    labelText: 'Diskon %',
                    hintText: 'Misal: 10',
                    prefixIcon: Icon(Icons.percent, size: 18),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _discountAmountController,
                  keyboardType: TextInputType.number,
                  onChanged: (val) {
                    if (val.isNotEmpty && _discountPercentController.text.isNotEmpty) {
                      _discountPercentController.clear();
                    }
                    setState(() {});
                  },
                  decoration: const InputDecoration(
                    labelText: 'Potongan Rp',
                    hintText: 'Misal: 5000',
                    prefixIcon: Icon(Icons.money_off, size: 18),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _discountStartDate ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035),
                    );
                    if (picked != null) {
                      setState(() => _discountStartDate = picked);
                    }
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      isDense: true,
                      labelText: 'Mulai',
                      prefixIcon: const Icon(Icons.play_arrow, size: 16),
                      suffixIcon: _discountStartDate != null
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 14),
                              onPressed: () => setState(() => _discountStartDate = null),
                            )
                          : null,
                    ),
                    child: Text(
                      _discountStartDate != null
                          ? '${_discountStartDate!.day}/${_discountStartDate!.month}/${_discountStartDate!.year}'
                          : 'Sekarang',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _discountEndDate ?? DateTime.now().add(const Duration(days: 7)),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035),
                    );
                    if (picked != null) {
                      setState(() => _discountEndDate = picked);
                    }
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      isDense: true,
                      labelText: 'Selesai',
                      prefixIcon: const Icon(Icons.stop, size: 16),
                      suffixIcon: _discountEndDate != null
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 14),
                              onPressed: () => setState(() => _discountEndDate = null),
                            )
                          : null,
                    ),
                    child: Text(
                      _discountEndDate != null
                          ? '${_discountEndDate!.day}/${_discountEndDate!.month}/${_discountEndDate!.year}'
                          : 'Pilih',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Tandai sebagai Flash Sale', style: TextStyle(fontSize: 13)),
            subtitle: const Text('Akan diprioritaskan di rekomendasi AI & POS', style: TextStyle(fontSize: 11)),
            value: _isFlashSale,
            onChanged: (val) => setState(() => _isFlashSale = val),
            activeThumbColor: AppTheme.accentColor,
          ),
          if ((pct > 0 || amt > 0) && basePrice > 0) ...[
            const Divider(color: AppTheme.borderColor),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Harga Setelah Diskon:', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                Text(
                  'Rp ${finalDiscountedPrice.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.successColor,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBarcodePreview() {
    final code = _barcodeController.text.trim();
    if (code.isEmpty) return const SizedBox.shrink();

    final isValid = bc.Barcode.code128().isValid(code);
    if (!isValid) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          'Format barcode tidak valid untuk Code128',
          style: TextStyle(color: AppTheme.warningColor, fontSize: 11),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 50,
            width: double.infinity,
            child: CustomPaint(
              painter: _BarcodePainter(
                data: code,
                barcode: bc.Barcode.code128(),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            code,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.product != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Produk' : 'Tambah Produk'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppTheme.borderColor,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildImagePreview(),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _nameController,
                      validator: Validators.name,
                      decoration: const InputDecoration(
                        labelText: 'Nama Produk *',
                        prefixIcon: Icon(Icons.inventory_2),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Kategori',
                        prefixIcon: Icon(Icons.category),
                      ),
                      items: _categories
                          .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedCategory = v),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _priceController,
                            keyboardType: TextInputType.number,
                            validator: (v) => Validators.positiveNumber(v, 'Harga jual'),
                            decoration: const InputDecoration(
                              labelText: 'Harga Jual *',
                              prefixIcon: Icon(Icons.sell),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _costPriceController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Harga Modal',
                              prefixIcon: Icon(Icons.shopping_bag_outlined),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _stockController,
                            keyboardType: TextInputType.number,
                            validator: (v) => Validators.positiveNumber(v, 'Stok'),
                            decoration: const InputDecoration(
                              labelText: 'Stok *',
                              prefixIcon: Icon(Icons.warehouse),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _unitController,
                            decoration: const InputDecoration(
                              labelText: 'Satuan (pcs/kg/porsi)',
                              prefixIcon: Icon(Icons.straighten),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _barcodeController,
                            decoration: InputDecoration(
                              labelText: 'Barcode',
                              prefixIcon: const Icon(Icons.qr_code),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.auto_awesome),
                                tooltip: 'Generate Barcode EAN-13',
                                onPressed: _generateBarcode,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.qr_code_scanner),
                          tooltip: 'Scan Barcode',
                          onPressed: _openBarcodeScanner,
                        ),
                      ],
                    ),
                    _buildBarcodePreview(),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.event, color: AppTheme.textSecondary),
                      title: Text(
                        _expiredDate != null
                            ? 'Expired: ${_expiredDate!.day}/${_expiredDate!.month}/${_expiredDate!.year}'
                            : 'Pilih Tanggal Kedaluwarsa (opsional)',
                        style: TextStyle(
                          color: _expiredDate != null ? AppTheme.textPrimary : AppTheme.textSecondary,
                        ),
                      ),
                      trailing: _expiredDate != null
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () => setState(() => _expiredDate = null),
                            )
                          : null,
                      onTap: _selectExpiredDate,
                    ),
                    const SizedBox(height: 20),
                    _buildChannelPricingSection(),
                    const SizedBox(height: 20),
                    _buildDiscountSection(),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _save,
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Text(isEdit ? 'Simpan Perubahan' : 'Simpan Produk'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BarcodePainter extends CustomPainter {
  final String data;
  final bc.Barcode barcode;

  const _BarcodePainter({required this.data, required this.barcode});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    try {
      final paint = Paint()
        ..color = Colors.black
        ..style = PaintingStyle.fill;
      final elements = barcode.make(
        data,
        width: size.width,
        height: size.height,
        drawText: false,
      );
      for (final element in elements) {
        if (element is bc.BarcodeBar && element.black) {
          canvas.drawRect(
            Rect.fromLTWH(element.left, element.top, element.width, element.height),
            paint,
          );
        }
      }
    } catch (_) {}
  }

  @override
  bool shouldRepaint(covariant _BarcodePainter oldDelegate) =>
      oldDelegate.data != data;
}

