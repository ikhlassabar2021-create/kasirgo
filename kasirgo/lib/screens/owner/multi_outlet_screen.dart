import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/supabase_service.dart';
import '../../widgets/common/app_close_button.dart';
import '../../widgets/common/supporter_gate.dart';

/// Multi-Outlet (Program Pendukung): kelola banyak outlet dalam 1 akun owner.
/// Tap outlet untuk berpindah outlet aktif di seluruh aplikasi.
class MultiOutletScreen extends ConsumerStatefulWidget {
  const MultiOutletScreen({super.key});

  @override
  ConsumerState<MultiOutletScreen> createState() => _MultiOutletScreenState();
}

class _MultiOutletScreenState extends ConsumerState<MultiOutletScreen> {
  final _svc = SupabaseService();
  List<Map<String, dynamic>> _outlets = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final data = await _svc.listOwnerOutlets();
    if (!mounted) return;
    setState(() {
      _outlets = data;
      _isLoading = false;
    });
  }

  Future<void> _addOutlet() async {
    if (!await requireSupporterFeature(context, ref, 'multi_outlet')) return;
    if (!mounted) return;

    final nameController = TextEditingController();
    final addressController = TextEditingController();
    String type = 'kelontong';
    bool isSubmitting = false;

    await showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surfaceColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Expanded(
                child: Text('Tambah Outlet',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              AppCloseButton(onTap: () => Navigator.pop(dialogCtx)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Nama Outlet',
                  prefixIcon: Icon(Icons.storefront_rounded),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: type,
                decoration: const InputDecoration(
                  labelText: 'Tipe Usaha',
                  prefixIcon: Icon(Icons.category_rounded),
                ),
                dropdownColor: AppTheme.surfaceColor,
                items: const [
                  DropdownMenuItem(value: 'kelontong', child: Text('Kelontong / Warung Sembako')),
                  DropdownMenuItem(value: 'retail', child: Text('Retail / Minimarket')),
                  DropdownMenuItem(value: 'cafe', child: Text('Cafe / Resto')),
                  DropdownMenuItem(value: 'warteg', child: Text('Warteg / Rumah Makan')),
                  DropdownMenuItem(value: 'gerobak', child: Text('Gerobak / Food Truck')),
                ],
                onChanged: (v) => setDialogState(() => type = v ?? 'kelontong'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: addressController,
                decoration: const InputDecoration(
                  labelText: 'Alamat (opsional)',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(dialogCtx),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (nameController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text('Nama outlet wajib diisi')));
                        return;
                      }
                      setDialogState(() => isSubmitting = true);
                      final messenger = ScaffoldMessenger.of(context);
                      final created = await _svc.addOwnerOutlet(
                        name: nameController.text,
                        type: type,
                        address: addressController.text,
                      );
                      if (!mounted) return;
                      if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                      if (created != null) {
                        messenger.showSnackBar(SnackBar(
                          content:
                              Text('Outlet "${created['name']}" berhasil dibuat!'),
                          backgroundColor: AppTheme.successColor,
                        ));
                        _load();
                      } else {
                        messenger.showSnackBar(const SnackBar(
                          content: Text('Gagal menambah outlet'),
                          backgroundColor: AppTheme.errorColor,
                        ));
                      }
                    },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _switchOutlet(Map<String, dynamic> outlet) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final newId = outlet['id']?.toString() ?? '';
    if (newId.isEmpty || newId == user.outletId) return;

    ref
        .read(currentUserProvider.notifier)
        .setUserDirectly(user.copyWith(outletId: newId));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Berpindah ke outlet "${outlet['name'] ?? '-'}"'),
      backgroundColor: AppTheme.successColor,
    ));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final activeId = user?.outletId ?? '';

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: const Border(bottom: BorderSide(color: AppTheme.borderColor)),
        title: const Text('Multi Outlet'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addOutlet,
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_business_rounded),
        label: Text('Tambah Outlet',
            style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      'Semua outlet milik Anda. Tap untuk berpindah outlet aktif.',
                      style: TextStyle(
                          fontSize: 12.5, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    ..._outlets.map((o) {
                      final id = o['id']?.toString() ?? '';
                      final isActive = id == activeId;
                      final tipe = (o['outlet_type'] ?? o['type'] ?? '-')
                          .toString();
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isActive
                                ? AppTheme.primaryColor
                                : AppTheme.borderColor,
                            width: isActive ? 1.5 : 1,
                          ),
                        ),
                        child: ListTile(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              isActive
                                  ? Icons.store_rounded
                                  : Icons.store_mall_directory_rounded,
                              color: AppTheme.primaryColor,
                              size: 22,
                            ),
                          ),
                          title: Text(
                            o['name']?.toString() ?? '-',
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary),
                          ),
                          subtitle: Text(
                            isActive
                                ? '${tipe.toUpperCase()} - Outlet aktif'
                                : tipe.toUpperCase(),
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: isActive
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isActive
                                    ? AppTheme.primaryColor
                                    : AppTheme.textSecondary),
                          ),
                          trailing: isActive
                              ? const Icon(Icons.check_circle_rounded,
                                  color: AppTheme.successColor)
                              : const Icon(Icons.chevron_right,
                                  color: AppTheme.textSecondary),
                          onTap: () => _switchOutlet(o),
                        ),
                      );
                    }),
                    const SizedBox(height: 8),
                    Text(
                      'Fitur Multi-Outlet tersedia untuk peserta Program Pendukung. '
                      'Satu akun owner dapat mengelola beberapa cabang toko.',
                      style: TextStyle(
                          fontSize: 11.5, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
