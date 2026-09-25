import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_theme.dart';
import '../../models/customer.dart';
import '../../models/debt.dart';
import '../../providers/auth_provider.dart';
import '../../services/supabase_service.dart';
import '../../utils/formatters.dart';
import '../../widgets/common/centennial_background.dart';
import '../../widgets/common/glass_card.dart';

class DebtScreen extends ConsumerStatefulWidget {
  const DebtScreen({super.key});

  @override
  ConsumerState<DebtScreen> createState() => _DebtScreenState();
}

class _DebtScreenState extends ConsumerState<DebtScreen> {
  final _supabaseService = SupabaseService();
  bool _isLoading = true;
  List<Debt> _debts = [];
  Map<String, Customer> _customersMap = {};
  String _selectedFilter = 'all'; // all, unpaid, partial, paid

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final user = ref.read(currentUserProvider);
    final outletId = user?.outletId;
    if (outletId == null || outletId.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final fetchedDebts = await _supabaseService.getDebts(outletId);
      final fetchedCustomers = await _supabaseService.getCustomers(outletId);
      final cMap = {for (var c in fetchedCustomers) c.id: c};

      if (mounted) {
        setState(() {
          _debts = fetchedDebts;
          _customersMap = cMap;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Debt> get _filteredDebts {
    if (_selectedFilter == 'all') return _debts;
    return _debts.where((d) => d.status.toLowerCase() == _selectedFilter).toList();
  }

  double get _totalRemaining {
    return _debts
        .where((d) => d.status.toLowerCase() != 'paid')
        .fold(0.0, (sum, d) => sum + d.remainingAmount);
  }

  Future<void> _openWhatsApp(String phone, String name, double remaining, DateTime? dueDate) async {
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nomor WhatsApp pelanggan tidak tersedia')),
      );
      return;
    }

    String formattedPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (formattedPhone.startsWith('0')) {
      formattedPhone = '62${formattedPhone.substring(1)}';
    } else if (!formattedPhone.startsWith('62')) {
      formattedPhone = '62$formattedPhone';
    }

    final dueStr = dueDate != null ? '\nJatuh tempo: ${Formatters.date(dueDate)}' : '';
    final message =
        'Halo Kak $name, ini pengingat kasbon di toko kami sebesar ${Formatters.currency(remaining)}.$dueStr Mohon konfirmasinya ya kak. Terima kasih!';

    final uri = Uri.parse('https://wa.me/$formattedPhone?text=${Uri.encodeComponent(message)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal membuka WhatsApp')),
        );
      }
    }
  }

  void _showPayDialog(Debt debt) {
    final payController = TextEditingController(text: debt.remainingAmount.toStringAsFixed(0));
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Bayar Kasbon', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sisa kasbon: ${Formatters.currency(debt.remainingAmount)}',
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: payController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Nominal Bayar (Rp)',
                  prefixIcon: Icon(Icons.payments_outlined),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Nominal wajib diisi';
                  final numVal = double.tryParse(val.trim());
                  if (numVal == null || numVal <= 0) return 'Nominal tidak valid';
                  if (numVal > debt.remainingAmount) {
                    return 'Melebihi sisa (${Formatters.currency(debt.remainingAmount)})';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final amountPaid = double.tryParse(payController.text.trim()) ?? 0;
              Navigator.pop(ctx);

              final newPaid = debt.paidAmount + amountPaid;
              final newStatus = newPaid >= debt.amount ? 'paid' : 'partial';

              await _supabaseService.recordDebtPayment(
                DebtPayment(
                  id: '',
                  debtId: debt.id,
                  amount: amountPaid,
                  paidAt: DateTime.now(),
                ),
              );

              await _supabaseService.updateDebt(debt.id, {
                'paid_amount': newPaid,
                'status': newStatus,
              });

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Pembayaran ${Formatters.currency(amountPaid)} berhasil dicatat'),
                    backgroundColor: AppTheme.successColor,
                  ),
                );
                _loadData();
              }
            },
            child: const Text('Simpan Pembayaran', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Buku Kasbon / Piutang',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
          ),
        ),
      ),
      body: CentennialBackground(
        child: RefreshIndicator(
          onRefresh: _loadData,
          child: Column(
            children: [
            GlassCard(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.warningColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.account_balance_wallet, color: AppTheme.warningColor, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Total Piutang Berjalan',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        MoneyText(
                          value: Formatters.currency(_totalRemaining),
                          size: 22,
                          color: AppTheme.warningColor,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _FilterChip(
                    label: 'Semua',
                    selected: _selectedFilter == 'all',
                    onSelected: () => setState(() => _selectedFilter = 'all'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Belum Lunas',
                    selected: _selectedFilter == 'unpaid',
                    onSelected: () => setState(() => _selectedFilter = 'unpaid'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Sebagian',
                    selected: _selectedFilter == 'partial',
                    onSelected: () => setState(() => _selectedFilter = 'partial'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Lunas',
                    selected: _selectedFilter == 'paid',
                    onSelected: () => setState(() => _selectedFilter = 'paid'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _isLoading
                  ? ListView(
                      padding: const EdgeInsets.all(16),
                      children: const [
                        CentennialSkeleton(
                          height: 96,
                          borderRadius: BorderRadius.all(Radius.circular(16)),
                        ),
                        SizedBox(height: 12),
                        CentennialSkeleton(
                          height: 132,
                          borderRadius: BorderRadius.all(Radius.circular(14)),
                        ),
                        SizedBox(height: 12),
                        CentennialSkeleton(
                          height: 132,
                          borderRadius: BorderRadius.all(Radius.circular(14)),
                        ),
                      ],
                    )
                  : _filteredDebts.isEmpty
                      ? ListView(
                          children: [
                            SizedBox(height: MediaQuery.of(context).size.height * 0.15),
                            const Center(
                              child: Column(
                                children: [
                                  Icon(Icons.menu_book, size: 56, color: AppTheme.textSecondary),
                                  SizedBox(height: 12),
                                  Text(
                                    'Tidak ada data kasbon',
                                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: _filteredDebts.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (ctx, index) {
                            final debt = _filteredDebts[index];
                            final customer = debt.customerId != null
                                ? _customersMap[debt.customerId]
                                : null;
                            final customerName = customer?.name ?? 'Pelanggan Umum';
                            final customerPhone = customer?.phone ?? '';

                            Color statusColor;
                            String statusLabel;
                            switch (debt.status.toLowerCase()) {
                              case 'paid':
                                statusColor = AppTheme.successColor;
                                statusLabel = 'LUNAS';
                                break;
                              case 'partial':
                                statusColor = AppTheme.warningColor;
                                statusLabel = 'SEBAGIAN';
                                break;
                              case 'unpaid':
                              default:
                                statusColor = AppTheme.errorColor;
                                statusLabel = 'BELUM LUNAS';
                                break;
                            }

                            return GlassCard(
                              padding: const EdgeInsets.all(14),
                              borderRadius: 14,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          customerName,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.textPrimary,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: statusColor.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(
                                              color: statusColor.withValues(alpha: 0.4)),
                                        ),
                                        child: Text(
                                          statusLabel,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: statusColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Sisa Piutang',
                                            style: TextStyle(
                                                fontSize: 11, color: AppTheme.textSecondary),
                                          ),
                                          const SizedBox(height: 2),
                                          MoneyText(
                                            value: Formatters.currency(debt.remainingAmount),
                                            size: 15,
                                            color: debt.remainingAmount > 0
                                                ? AppTheme.warningColor
                                                : AppTheme.textPrimary,
                                          ),
                                        ],
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          const Text(
                                            'Total Kasbon',
                                            style: TextStyle(
                                                fontSize: 11, color: AppTheme.textSecondary),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            Formatters.currency(debt.amount),
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: AppTheme.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  if (debt.dueDate != null) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      'Jatuh tempo: ${Formatters.date(debt.dueDate!)}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: debt.dueDate!.isBefore(DateTime.now()) &&
                                                debt.status.toLowerCase() != 'paid'
                                            ? AppTheme.errorColor
                                            : AppTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      if (debt.remainingAmount > 0) ...[
                                        OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 6),
                                            side: BorderSide(
                                              color: AppTheme.successColor.withValues(alpha: 0.6),
                                            ),
                                          ),
                                          icon: const Icon(Icons.chat,
                                              size: 14, color: AppTheme.successColor),
                                          label: const Text(
                                            'Tagih via WA',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: AppTheme.successColor,
                                            ),
                                          ),
                                          onPressed: () => _openWhatsApp(
                                            customerPhone,
                                            customerName,
                                            debt.remainingAmount,
                                            debt.dueDate,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppTheme.primaryColor,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 6),
                                          ),
                                          icon: const Icon(Icons.payments,
                                              size: 14, color: Colors.white),
                                          label: const Text(
                                            'Bayar',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          onPressed: () => _showPayDialog(debt),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: AppTheme.primaryColor,
      backgroundColor: AppTheme.surfaceColor,
      labelStyle: TextStyle(
        fontSize: 12,
        color: selected ? Colors.white : AppTheme.textSecondary,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
}
