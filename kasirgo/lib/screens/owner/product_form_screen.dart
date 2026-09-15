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
import '../../config/app_theme.dart';
import '../../config/constants.dart';
import '../../models/product.dart';
import '../../providers/auth_provider.dart';
import '../../services/supabase_service.dart';
import '../../utils/validators.dart';
import 'product_list_screen.dart';

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
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _costPriceController.dispose();
    _stockController.dispose();
    _barcodeController.dispose();
    _unitController.dispose();
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

    final isNew = widget.product == null || widget.product!.id.isEmpty;
    if (isNew) {
      final existingProducts = ref.read(productsProvider).valueOrNull ?? [];
      if (existingProducts.length >= AppConstants.freeTierMaxProducts) {
        final outlet = await SupabaseService().getOutlet(outletId);
        final tier = outlet?.subscriptionTier ?? 'free';
        if (tier == 'free') {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Batas produk paket gratis (500 produk) tercapai. Silakan upgrade paket.'),
                backgroundColor: AppTheme.errorColor,
                duration: Duration(seconds: 4),
              ),
            );
          }
          return;
        }
      }
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

  Widget _buildBarcodePreview() {
    final code = _barcodeController.text.trim();
    if (code.isEmpty) return const SizedBox.shrink();

    final isValid = bc.Barcode.code128().isValid(code);
    if (!isValid) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          'Format barcode tidak valid untuk Code128',
          style: TextStyle(color: Colors.amber.shade300, fontSize: 11),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppTheme.borderColor.withValues(alpha: 0.5),
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
                          prefixIcon: Icon(Icons.money_off),
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
                        validator: (v) => Validators.number(v, 'Stok'),
                        decoration: const InputDecoration(
                          labelText: 'Stok',
                          prefixIcon: Icon(Icons.numbers),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _unitController,
                        decoration: const InputDecoration(
                          labelText: 'Satuan',
                          prefixIcon: Icon(Icons.square_foot),
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
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Barcode',
                          prefixIcon: Icon(Icons.qr_code),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton.filledTonal(
                      onPressed: _openBarcodeScanner,
                      tooltip: 'Scan Barcode',
                      icon: const Icon(Icons.qr_code_scanner),
                    ),
                    const SizedBox(width: 4),
                    IconButton.filledTonal(
                      onPressed: _generateBarcode,
                      tooltip: 'Generate Barcode',
                      icon: const Icon(Icons.auto_awesome),
                    ),
                  ],
                ),
                _buildBarcodePreview(),
                const SizedBox(height: 12),
                InkWell(
                  onTap: _selectExpiredDate,
                  borderRadius: BorderRadius.circular(12),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Expired Date',
                      prefixIcon: const Icon(Icons.calendar_today),
                      suffixIcon: _expiredDate != null
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () => setState(() => _expiredDate = null),
                            )
                          : null,
                    ),
                    child: Text(
                      _expiredDate != null
                          ? '${_expiredDate!.day.toString().padLeft(2, '0')}/${_expiredDate!.month.toString().padLeft(2, '0')}/${_expiredDate!.year}'
                          : 'Pilih Tanggal Kedaluwarsa (opsional)',
                      style: TextStyle(
                        color: _expiredDate != null ? Colors.white : AppTheme.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
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

