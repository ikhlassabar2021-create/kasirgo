import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/app_theme.dart';
import '../../models/employee.dart';
import '../../providers/auth_provider.dart';
import '../../services/supabase_service.dart';

class EmployeeScreen extends ConsumerStatefulWidget {
  const EmployeeScreen({super.key});

  @override
  ConsumerState<EmployeeScreen> createState() => _EmployeeScreenState();
}

class _EmployeeScreenState extends ConsumerState<EmployeeScreen> {
  final _supabaseService = SupabaseService();
  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isLoading = true;
  List<Employee> _employees = [];

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadEmployees() async {
    setState(() => _isLoading = true);
    final user = ref.read(currentUserProvider);
    final outletId = user?.outletId;
    if (outletId != null && outletId.isNotEmpty) {
      final list = await _supabaseService.getEmployees(outletId);
      if (mounted) {
        setState(() {
          _employees = list;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showAddEmployeeDialog() {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();
    String selectedRole = 'cashier';
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
                  Icon(Icons.person_add_alt_1, color: AppTheme.primaryColor),
                  SizedBox(width: 8),
                  Text('Tambah Karyawan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Nama Karyawan *',
                          prefixIcon: Icon(Icons.person, color: AppTheme.textSecondary),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Nama wajib diisi' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Nomor WhatsApp / HP',
                          prefixIcon: Icon(Icons.phone, color: AppTheme.textSecondary),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email Akun (Opsional)',
                          prefixIcon: Icon(Icons.email, color: AppTheme.textSecondary),
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: selectedRole,
                        decoration: const InputDecoration(
                          labelText: 'Role / Hak Akses',
                          prefixIcon: Icon(Icons.badge, color: AppTheme.textSecondary),
                        ),
                        dropdownColor: AppTheme.surfaceColor,
                        items: const [
                          DropdownMenuItem(value: 'cashier', child: Text('Kasir (POS & Transaksi)')),
                          DropdownMenuItem(value: 'admin', child: Text('Admin (Produk & Laporan)')),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            setDialogState(() => selectedRole = v);
                          }
                        },
                      ),
                    ],
                  ),
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

                          final newEmployee = Employee(
                            id: '',
                            outletId: outletId,
                            userId: '',
                            name: nameController.text.trim(),
                            role: selectedRole,
                            phone: phoneController.text.trim().isEmpty ? null : phoneController.text.trim(),
                            email: emailController.text.trim().isEmpty ? null : emailController.text.trim(),
                            isActive: true,
                          );

                          final res = await _supabaseService.createEmployee(newEmployee);
                          if (!dialogCtx.mounted) return;
                          Navigator.pop(dialogCtx);
                          if (!mounted) return;
                          if (res != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Karyawan berhasil ditambahkan')),
                            );
                            _loadEmployees();
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Gagal menambahkan karyawan')),
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

  void _showRoleAssignmentDialog(Employee employee) {
    String currentRole = employee.role.toLowerCase() == 'admin' ? 'admin' : 'cashier';
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.surfaceColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.admin_panel_settings, color: AppTheme.accentColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Role: ${employee.name}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pilih role baru untuk karyawan:',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  RadioGroup<String>(
                    groupValue: currentRole,
                    onChanged: (v) {
                      if (v != null) setDialogState(() => currentRole = v);
                    },
                    child: Column(
                      children: [
                        RadioListTile<String>(
                          title: const Text('Kasir', style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: const Text('Akses POS, buat pesanan, QRIS'),
                          value: 'cashier',
                          activeColor: AppTheme.primaryColor,
                        ),
                        RadioListTile<String>(
                          title: const Text('Admin', style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: const Text('Akses manajemen produk & laporan standar'),
                          value: 'admin',
                          activeColor: AppTheme.primaryColor,
                        ),
                      ],
                    ),
                  ),
                ],
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
                          setDialogState(() => isSubmitting = true);
                          final ok = await _supabaseService.updateEmployeeRole(
                            employee.id,
                            currentRole,
                            userId: employee.userId,
                            outletId: employee.outletId,
                          );
                          if (!dialogCtx.mounted) return;
                          Navigator.pop(dialogCtx);
                          if (!mounted) return;
                          if (ok) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Role ${employee.name} diubah ke ${currentRole.toUpperCase()}')),
                            );
                            _loadEmployees();
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Gagal mengubah role karyawan')),
                            );
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Simpan Role'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return Colors.orangeAccent;
      case 'owner':
        return AppTheme.accentColor;
      default:
        return AppTheme.primaryColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _employees.where((e) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final matchName = e.name.toLowerCase().contains(q);
      final matchRole = e.role.toLowerCase().contains(q);
      final matchPhone = e.phone?.toLowerCase().contains(q) ?? false;
      return matchName || matchRole || matchPhone;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Karyawan'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primaryColor,
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text('Karyawan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: _showAddEmployeeDialog,
      ),
      body: RefreshIndicator(
        onRefresh: _loadEmployees,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
                decoration: const InputDecoration(
                  hintText: 'Cari karyawan atau role...',
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
                                  Icon(Icons.badge_outlined, size: 64, color: AppTheme.textSecondary),
                                  SizedBox(height: 12),
                                  Text(
                                    'Belum ada data karyawan',
                                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Tekan tombol + Karyawan untuk mendaftarkan staf',
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
                            final employee = filtered[index];
                            final roleColor = _getRoleColor(employee.role);
                            final phoneDisplay = (employee.phone != null && employee.phone!.isNotEmpty)
                                ? employee.phone!
                                : (employee.email ?? 'Tidak ada kontak');

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
                                      backgroundColor: roleColor.withValues(alpha: 0.15),
                                      child: Text(
                                        employee.name.isNotEmpty ? employee.name[0].toUpperCase() : '?',
                                        style: TextStyle(
                                          color: roleColor,
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
                                            employee.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                              color: AppTheme.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              const Icon(Icons.contact_phone, size: 13, color: AppTheme.textSecondary),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  phoneDisplay,
                                                  style: const TextStyle(
                                                    color: AppTheme.textSecondary,
                                                    fontSize: 12,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    InkWell(
                                      borderRadius: BorderRadius.circular(8),
                                      onTap: () => _showRoleAssignmentDialog(employee),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: roleColor.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: roleColor.withValues(alpha: 0.4)),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              employee.role.toUpperCase(),
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 11,
                                                color: roleColor,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Icon(Icons.edit, size: 12, color: roleColor),
                                          ],
                                        ),
                                      ),
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
