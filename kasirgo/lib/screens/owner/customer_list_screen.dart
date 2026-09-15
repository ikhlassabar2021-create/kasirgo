import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/app_theme.dart';
import '../../models/customer.dart';
import '../../providers/auth_provider.dart';
import '../../services/supabase_service.dart';
import '../../utils/formatters.dart';

class CustomerListScreen extends ConsumerStatefulWidget {
  const CustomerListScreen({super.key});

  @override
  ConsumerState<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends ConsumerState<CustomerListScreen> {
  final _searchController = TextEditingController();
  final _supabaseService = SupabaseService();
  String _searchQuery = '';
  bool _isLoading = true;
  List<Customer> _customers = [];

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomers() async {
    setState(() => _isLoading = true);
    final user = ref.read(currentUserProvider);
    final outletId = user?.outletId;
    if (outletId != null && outletId.isNotEmpty) {
      final list = await _supabaseService.getCustomers(outletId);
      if (mounted) {
        setState(() {
          _customers = list;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showAddCustomerDialog() {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.surfaceColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.person_add, color: AppTheme.primaryColor),
                  SizedBox(width: 8),
                  Text('Tambah Pelanggan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Nama Pelanggan *',
                        prefixIcon: Icon(Icons.person, color: AppTheme.textSecondary),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Nama wajib diisi';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Nomor WhatsApp / HP',
                        hintText: '081234567890',
                        prefixIcon: Icon(Icons.phone, color: AppTheme.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(dialogCtx),
                  child: const Text('Batal', style: TextStyle(color: AppTheme.textSecondary)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDialogState(() => isSubmitting = true);

                          final user = ref.read(currentUserProvider);
                          final outletId = user?.outletId;
                          if (outletId == null || outletId.isEmpty) {
                            setDialogState(() => isSubmitting = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Outlet ID tidak ditemukan')),
                            );
                            return;
                          }

                          final newCustomer = Customer(
                            id: '',
                            outletId: outletId,
                            name: nameController.text.trim(),
                            phone: phoneController.text.trim().isEmpty ? null : phoneController.text.trim(),
                            totalSpent: 0,
                          );

                          final res = await _supabaseService.createCustomer(newCustomer);
                          if (!dialogCtx.mounted) return;
                          Navigator.pop(dialogCtx);
                          if (!mounted) return;
                          if (res != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Pelanggan berhasil ditambahkan')),
                            );
                            _loadCustomers();
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Gagal menambahkan pelanggan')),
                            );
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _customers.where((c) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final nameMatches = c.name.toLowerCase().contains(q);
      final phoneMatches = c.phone?.toLowerCase().contains(q) ?? false;
      return nameMatches || phoneMatches;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pelanggan'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primaryColor,
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text('Pelanggan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: _showAddCustomerDialog,
      ),
      body: RefreshIndicator(
        onRefresh: _loadCustomers,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
                decoration: const InputDecoration(
                  hintText: 'Cari pelanggan atau nomor WA...',
                  prefixIcon: Icon(Icons.search, color: AppTheme.textSecondary),
                ),
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filtered.isEmpty
                      ? ListView(
                          children: [
                            SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                            const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.people_outline, size: 64, color: AppTheme.textSecondary),
                                  SizedBox(height: 12),
                                  Text(
                                    'Belum ada data pelanggan',
                                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Tekan tombol + Pelanggan untuk menambah',
                                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final customer = filtered[index];
                            final phoneDisplay = (customer.phone != null && customer.phone!.isNotEmpty)
                                ? customer.phone!
                                : 'Tidak ada WA/HP';
                            final totalSpentDisplay = Formatters.currency(customer.totalSpent ?? 0);

                            return Card(
                              color: AppTheme.surfaceColor,
                              margin: const EdgeInsets.only(bottom: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: AppTheme.borderColor.withValues(alpha: 0.5),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 22,
                                      backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.15),
                                      child: Text(
                                        customer.name.isNotEmpty ? customer.name[0].toUpperCase() : '?',
                                        style: const TextStyle(
                                          color: AppTheme.accentColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            customer.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                              color: AppTheme.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              const Icon(Icons.phone, size: 13, color: AppTheme.textSecondary),
                                              const SizedBox(width: 4),
                                              Text(
                                                phoneDisplay,
                                                style: const TextStyle(
                                                  color: AppTheme.textSecondary,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        const Text(
                                          'Total Belanja',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: AppTheme.textSecondary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          totalSpentDisplay,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: AppTheme.accentColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
