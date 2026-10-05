import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/app_theme.dart';
import '../../models/employee.dart';
import '../../providers/auth_provider.dart';
import '../../providers/module_provider.dart';
import '../../providers/outlet_provider.dart';
import '../../services/supabase_service.dart';
import '../../widgets/common/supporter_gate.dart';

class EmployeeScreen extends ConsumerStatefulWidget {
  const EmployeeScreen({super.key});

  @override
  ConsumerState<EmployeeScreen> createState() => _EmployeeScreenState();
}

class _EmployeeScreenState extends ConsumerState<EmployeeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _supabaseService = SupabaseService();
  final _searchController = TextEditingController();

  String _searchQuery = '';
  bool _isLoadingStaff = true;
  bool _isLoadingAttendance = true;
  bool _isChecking = false;

  List<Employee> _employees = [];
  List<Map<String, dynamic>> _attendanceLogs = [];

  String _selectedShift = 'pagi'; // pagi | siang | malam

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadEmployees(),
      _loadAttendance(),
    ]);
  }

  Future<void> _loadEmployees() async {
    setState(() => _isLoadingStaff = true);
    final user = ref.read(currentUserProvider);
    final outletId = user?.outletId;
    if (outletId != null && outletId.isNotEmpty) {
      final list = await _supabaseService.getEmployees(outletId);
      final local = await _loadLocalStaff(outletId);
      if (mounted) {
        setState(() {
          _employees = [...local, ...list];
          _isLoadingStaff = false;
        });
      }
    } else {
      if (mounted) setState(() => _isLoadingStaff = false);
    }
  }

  Future<List<Employee>> _loadLocalStaff(String outletId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('local_staff_$outletId');
      if (raw == null || raw.isEmpty) return [];
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => Employee.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveLocalStaff(String outletId, List<Employee> staff) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'local_staff_$outletId',
        jsonEncode(staff.map((e) => e.toJson()).toList()),
      );
    } catch (_) {}
  }

  Future<void> _loadAttendance() async {
    setState(() => _isLoadingAttendance = true);
    final user = ref.read(currentUserProvider);
    final outletId = user?.outletId;
    if (outletId != null && outletId.isNotEmpty) {
      final logs = await _supabaseService.getAttendanceLogs(outletId);
      if (mounted) {
        setState(() {
          _attendanceLogs = logs;
          _isLoadingAttendance = false;
        });
      }
    } else {
      if (mounted) setState(() => _isLoadingAttendance = false);
    }
  }

  Map<String, dynamic>? _getTodayActiveAttendance(String? userId) {
    if (userId == null || userId.isEmpty) return null;
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    for (final log in _attendanceLogs) {
      final logDate = log['date']?.toString() ?? '';
      final logUserId = log['user_id']?.toString() ?? '';
      final checkOut = log['check_out_time'];
      if (logUserId == userId && logDate.startsWith(todayStr) && checkOut == null) {
        return log;
      }
    }
    return null;
  }

  Future<void> _handleCheckIn() async {
    final user = ref.read(currentUserProvider);
    final outletId = user?.outletId;
    final userId = user?.id;
    if (outletId == null || userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data user/outlet tidak valid')),
      );
      return;
    }

    setState(() => _isChecking = true);
    final res = await _supabaseService.checkInEmployee(
      outletId: outletId,
      userId: userId,
      shift: _selectedShift,
      employeeName: user?.name,
    );

    if (mounted) {
      setState(() => _isChecking = false);
      if (res != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Check-in shift $_selectedShift berhasil!')),
        );
        _loadAttendance();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal melakukan check-in')),
        );
      }
    }
  }

  Future<void> _handleCheckOut(String attendanceId) async {
    setState(() => _isChecking = true);
    final ok = await _supabaseService.checkOutEmployee(attendanceId);

    if (mounted) {
      setState(() => _isChecking = false);
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Check-out berhasil! Terima kasih atas kerjanya.')),
        );
        _loadAttendance();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal melakukan check-out')),
        );
      }
    }
  }

  Future<void> _handleAddEmployee() async {
    if (!await requireSupporterFeature(context, ref, 'extra_staff')) return;
    if (mounted) _showAddEmployeeDialog();
  }

  void _showAddEmployeeDialog() {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    bool obscurePassword = true;
    bool createLogin = false;
    String selectedRole = 'cashier';
    bool isSubmitting = false;
    // Koki hanya relevan utk usaha makanan/minuman (cafe/warteg).
    final userSnapshot = ref.read(currentUserProvider);
    final isFoodBusiness = ModuleConfig.isFoodBusiness(
        ref.read(outletTypeProvider(userSnapshot?.outletId ?? '')));

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
                        validator: (v) {
                          final val = (v ?? '').trim();
                          if (val.isEmpty && createLogin) return 'Email wajib diisi untuk akun login';
                          if (val.isNotEmpty && !val.contains('@')) return 'Format email tidak valid';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Buat akun login (Kasir/Admin)',
                              style: TextStyle(fontSize: 13, color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
                            ),
                          ),
                          Switch(
                            value: createLogin,
                            activeColor: AppTheme.primaryColor,
                            onChanged: (v) => setDialogState(() => createLogin = v),
                          ),
                        ],
                      ),
                      if (createLogin) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Karyawan bisa login dengan email & password ini untuk masuk ke aplikasi KasirGo sesuai role.',
                            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: passwordController,
                          obscureText: obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Password Akun *',
                            prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.textSecondary),
                            suffixIcon: IconButton(
                              icon: Icon(
                                obscurePassword ? Icons.visibility_off : Icons.visibility,
                                color: AppTheme.textSecondary,
                              ),
                              onPressed: () => setDialogState(() => obscurePassword = !obscurePassword),
                            ),
                          ),
                          validator: createLogin
                              ? (v) {
                                  final val = v ?? '';
                                  if (val.isEmpty) return 'Password wajib diisi';
                                  if (val.length < 6) return 'Minimal 6 karakter';
                                  return null;
                                }
                              : null,
                        ),
                      ],
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: selectedRole,
                        decoration: const InputDecoration(
                          labelText: 'Role / Hak Akses',
                          prefixIcon: Icon(Icons.badge, color: AppTheme.textSecondary),
                        ),
                        dropdownColor: AppTheme.surfaceColor,
                        items: isFoodBusiness
                            ? const [
                                DropdownMenuItem(value: 'cashier', child: Text('Kasir (POS & Transaksi)')),
                                DropdownMenuItem(value: 'kitchen', child: Text('Koki (KDS Dapur Saja)')),
                                DropdownMenuItem(value: 'admin', child: Text('Admin (Produk & Laporan)')),
                              ]
                            : const [
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
                  child: const Icon(Icons.close_rounded, size: 20),
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

                          String? newUserId = '';
                          try {
                            if (createLogin) {
                              final authService = ref.read(authServiceProvider);
                              final staffEmail = emailController.text.trim();
                              final staffPassword = passwordController.text;
                              newUserId = await authService.createStaffAccount(
                                email: staffEmail,
                                password: staffPassword,
                                outletId: outletId,
                                role: selectedRole,
                                name: nameController.text.trim(),
                              );
                            }
                          } catch (e) {
                            setDialogState(() => isSubmitting = false);
                            if (context.mounted) {
                              final msg = e.toString();
                              final isRateLimit = msg.contains('rate limit') ||
                                  msg.contains('429') ||
                                  msg.contains('over_email');
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    isRateLimit
                                        ? 'Kuota email Supabase habis (maks ~3/jam). Tunggu 1 jam, atau minta admin menonaktifkan "Confirm email" sementara, lalu coba lagi.'
                                        : 'Gagal membuat akun login: $e',
                                  ),
                                  backgroundColor: AppTheme.errorColor,
                                  duration: const Duration(seconds: 8),
                                ),
                              );
                            }
                            return;
                          }

                          final newEmployee = Employee(
                            id: '',
                            outletId: outletId,
                            userId: newUserId ?? '',
                            name: nameController.text.trim(),
                            role: selectedRole,
                            phone: phoneController.text.trim().isEmpty ? null : phoneController.text.trim(),
                            email: emailController.text.trim().isEmpty ? null : emailController.text.trim(),
                            isActive: true,
                          );

                          dynamic saved;
                          try {
                            saved = await _supabaseService.createEmployee(newEmployee);
                          } catch (e) {
                            debugPrint('createEmployee error: $e');
                            saved = null;
                          }
                          if (saved == null) {
                            final local = await _loadLocalStaff(outletId);
                            final newLocal = newEmployee.copyWith(
                              id: 'local_${DateTime.now().millisecondsSinceEpoch}',
                            );
                            local.add(newLocal);
                            await _saveLocalStaff(outletId, local);
                            saved = newLocal;
                          }
                          if (!dialogCtx.mounted) return;
                          Navigator.pop(dialogCtx);
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                createLogin
                                    ? 'Karyawan ditambahkan. Akun login dibuat: ${emailController.text.trim()}'
                                    : 'Karyawan berhasil ditambahkan',
                              ),
                              backgroundColor: AppTheme.successColor,
                              duration: const Duration(seconds: 5),
                            ),
                          );
                          _loadEmployees();
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
                  child: const Icon(Icons.close_rounded, size: 20),
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
                          var ok = false;
                          if (employee.id.startsWith('local_')) {
                            final local = await _loadLocalStaff(employee.outletId);
                            final idx = local.indexWhere((e) => e.id == employee.id);
                            if (idx >= 0) {
                              local[idx] = local[idx].copyWith(role: currentRole);
                              await _saveLocalStaff(employee.outletId, local);
                              ok = true;
                            }
                          } else {
                            ok = await _supabaseService.updateEmployeeRole(
                              employee.id,
                              currentRole,
                              userId: employee.userId,
                              outletId: employee.outletId,
                            );
                          }
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
        return AppTheme.warningColor;
      case 'owner':
        return AppTheme.accentColor;
      default:
        return AppTheme.primaryColor;
    }
  }

  Widget _buildShiftChip(String label, String value) {
    final isSelected = _selectedShift == value;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : AppTheme.textSecondary,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      selectedColor: AppTheme.primaryColor,
      backgroundColor: AppTheme.surfaceColor,
      onSelected: (selected) {
        if (selected) setState(() => _selectedShift = value);
      },
    );
  }

  Widget _buildAttendanceTab() {
    final user = ref.watch(currentUserProvider);
    final todayStr = DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(DateTime.now());
    final activeAttendance = _getTodayActiveAttendance(user?.id);
    final isCheckedIn = activeAttendance != null;

    return RefreshIndicator(
      onRefresh: _loadAttendance,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header tanggal hari ini
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 18, color: AppTheme.accentColor),
                    const SizedBox(width: 8),
                    Text(
                      todayStr,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Halo, ${user?.name ?? 'Karyawan'}!',
                  style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Pilih Shift Kerja:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildShiftChip('Pagi', 'pagi'),
                    const SizedBox(width: 8),
                    _buildShiftChip('Siang', 'siang'),
                    const SizedBox(width: 8),
                    _buildShiftChip('Malam', 'malam'),
                  ],
                ),
                const SizedBox(height: 20),
                // Tombol besar Check-in / Check-out
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isCheckedIn ? AppTheme.errorColor : AppTheme.successColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 2,
                    ),
                    onPressed: _isChecking
                        ? null
                        : isCheckedIn
                            ? () => _handleCheckOut(activeAttendance['id'].toString())
                            : _handleCheckIn,
                    icon: _isChecking
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Icon(isCheckedIn ? Icons.logout : Icons.login, size: 24),
                    label: Text(
                      _isChecking
                          ? 'Memproses...'
                          : isCheckedIn
                              ? 'CHECK-OUT SEKARANG'
                              : 'CHECK-IN SEKARANG',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    ),
                  ),
                ),
                if (isCheckedIn) ...[
                  const SizedBox(height: 10),
                  Center(
                    child: Text(
                      'Check-in aktif: ${DateFormat('HH:mm').format(DateTime.parse(activeAttendance['check_in_time']))} WIB (Shift ${activeAttendance['shift']?.toString().toUpperCase()})',
                      style: const TextStyle(fontSize: 12, color: AppTheme.successColor),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Riwayat Absensi',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          if (_isLoadingAttendance)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_attendanceLogs.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text(
                  'Belum ada riwayat absensi',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
            )
          else
            ..._attendanceLogs.map((log) {
              final inTimeStr = log['check_in_time'] != null
                  ? DateFormat('HH:mm').format(DateTime.parse(log['check_in_time']))
                  : '-';
              final outTimeStr = log['check_out_time'] != null
                  ? DateFormat('HH:mm').format(DateTime.parse(log['check_out_time']))
                  : 'Aktif';
              final dateFormatted = log['date'] != null
                  ? DateFormat('dd MMM yyyy').format(DateTime.parse(log['date']))
                  : '-';
              final isCompleted = log['check_out_time'] != null;
              final shiftName = (log['shift'] ?? 'pagi').toString().toUpperCase();

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isCompleted
                        ? AppTheme.borderColor.withValues(alpha: 0.4)
                        : AppTheme.successColor.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: isCompleted
                          ? AppTheme.primaryColor.withValues(alpha: 0.15)
                          : AppTheme.successColor.withValues(alpha: 0.15),
                      child: Icon(
                        isCompleted ? Icons.check_circle_outline : Icons.timelapse,
                        color: isCompleted ? AppTheme.accentColor : AppTheme.successColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dateFormatted,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Shift: $shiftName • In: $inTimeStr • Out: $outTimeStr',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? AppTheme.borderColor.withValues(alpha: 0.2)
                            : AppTheme.successColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isCompleted ? 'SELESAI' : 'BEKERJA',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isCompleted ? AppTheme.textSecondary : AppTheme.successColor,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildStaffTab() {
    final filtered = _employees.where((e) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final matchName = e.name.toLowerCase().contains(q);
      final matchRole = e.role.toLowerCase().contains(q);
      final matchPhone = e.phone?.toLowerCase().contains(q) ?? false;
      return matchName || matchRole || matchPhone;
    }).toList();

    return RefreshIndicator(
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
            child: _isLoadingStaff
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
                              side: const BorderSide(
                                color: AppTheme.borderColor,
                              ),
                            ),
                            child: Container(
                              constraints: const BoxConstraints(minHeight: AppTheme.touchTargetLarge),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Karyawan & Absensi'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryColor,
          labelColor: Colors.white,
          unselectedLabelColor: AppTheme.textSecondary,
          tabs: const [
            Tab(icon: Icon(Icons.access_time), text: 'Absensi'),
            Tab(icon: Icon(Icons.badge), text: 'Daftar Staf'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_employee',
        backgroundColor: AppTheme.primaryColor,
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text('Karyawan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: _handleAddEmployee,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildAttendanceTab(),
              _buildStaffTab(),
            ],
          ),
        ),
      ),
    );
  }
}
