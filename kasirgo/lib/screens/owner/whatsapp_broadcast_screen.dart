import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_theme.dart';
import '../../models/customer.dart';
import '../../providers/auth_provider.dart';
import '../../services/supabase_service.dart';
import '../../utils/wa_helper.dart';

class WhatsappBroadcastScreen extends ConsumerStatefulWidget {
  const WhatsappBroadcastScreen({super.key});

  @override
  ConsumerState<WhatsappBroadcastScreen> createState() => _WhatsappBroadcastScreenState();
}

class _WhatsappBroadcastScreenState extends ConsumerState<WhatsappBroadcastScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _service = SupabaseService();

  final _promoTitleController = TextEditingController();
  final _promoDescController = TextEditingController();
  final _promoCodeController = TextEditingController();
  final _validUntilController = TextEditingController();

  List<Customer> _customers = [];
  final Set<String> _selectedCustomerIds = {};
  final List<Map<String, String>> _sentHistory = [];
  bool _isLoading = true;

  final List<Map<String, String>> _templates = [
    {
      'title': 'Diskon Gajian 20%',
      'desc': 'Spesial gajian! Dapatkan diskon 20% untuk semua produk pilihan hari ini.',
      'code': 'GAJIAN20',
    },
    {
      'title': 'Beli 1 Gratis 1 Menu Favorit',
      'desc': 'Khusus pelanggan setia, nikmati promo beli 1 gratis 1 untuk item terlaris.',
      'code': 'BUY1GET1',
    },
    {
      'title': 'Flash Sale Akhir Pekan',
      'desc': 'Promo kilat cuma 2 hari! Belanja hemat dengan potongan harga langsung di kasir.',
      'code': 'WEEKENDHEMAT',
    },
  ];

  void _applyTemplate(Map<String, String> tpl) {
    setState(() {
      _promoTitleController.text = tpl['title'] ?? '';
      _promoDescController.text = tpl['desc'] ?? '';
      _promoCodeController.text = tpl['code'] ?? '';
      _validUntilController.text = 'Akhir Bulan Ini';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Template "${tpl['title']}" diterapkan'),
        backgroundColor: AppTheme.primaryColor,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadCustomers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _promoTitleController.dispose();
    _promoDescController.dispose();
    _promoCodeController.dispose();
    _validUntilController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomers() async {
    final user = ref.read(currentUserProvider);
    if (user?.outletId == null) return;
    setState(() => _isLoading = true);
    final data = await _service.getCustomers(user!.outletId!);
    setState(() {
      _customers = data;
      _isLoading = false;
    });
  }

  void _sendSinglePromo(Customer customer, String storeName) {
    if (customer.phone == null || customer.phone!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nomor WA ${customer.name} tidak tersedia')),
      );
      return;
    }

    final message = WaHelper.formatBroadcastPromo(
      storeName: storeName,
      promoTitle: _promoTitleController.text.trim().isNotEmpty
          ? _promoTitleController.text.trim()
          : 'Spesial Minggu Ini',
      promoDescription: _promoDescController.text.trim().isNotEmpty
          ? _promoDescController.text.trim()
          : 'Dapatkan potongan harga dan penawaran menarik di toko kami!',
      promoCode: _promoCodeController.text.trim().isNotEmpty ? _promoCodeController.text.trim() : null,
      validUntil: _validUntilController.text.trim().isNotEmpty ? _validUntilController.text.trim() : null,
    );

    WaHelper.sendWhatsAppMessage(phone: customer.phone!, message: message);
    setState(() {
      _sentHistory.insert(0, {
        'name': customer.name,
        'message': _promoTitleController.text.trim().isNotEmpty
            ? _promoTitleController.text.trim()
            : 'Spesial Minggu Ini',
        'time': _formatNow(),
      });
    });
  }

  void _sendRetention(Customer customer, String storeName, int daysInactive) {
    if (customer.phone == null || customer.phone!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nomor WA ${customer.name} tidak tersedia')),
      );
      return;
    }

    final message = WaHelper.formatRetentionMessage(
      storeName: storeName,
      customerName: customer.name,
      daysInactive: daysInactive,
    );

    WaHelper.sendWhatsAppMessage(phone: customer.phone!, message: message);
    setState(() {
      _sentHistory.insert(0, {
        'name': customer.name,
        'message': 'Sapaan retensi ($daysInactive hari tidak aktif)',
        'time': _formatNow(),
      });
    });
  }

  String _formatNow() {
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(now.day)}/${two(now.month)}/${now.year} ${two(now.hour)}:${two(now.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    const storeName = 'KasirGo Store';

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          'WhatsApp Marketing & CRM',
          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primaryColor,
          indicatorWeight: 2.5,
          tabs: const [
            Tab(icon: Icon(Icons.campaign_outlined), text: 'Broadcast Promo'),
            Tab(icon: Icon(Icons.autorenew_rounded), text: 'Auto-Retensi (30+ Hari)'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildBroadcastTab(storeName),
                _buildRetentionTab(storeName),
              ],
            ),
    );
  }

  Widget _buildBroadcastTab(String storeName) {
    final validCustomers = _customers.where((c) => c.phone != null && c.phone!.isNotEmpty).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF25D366).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                      ),
                      child: const Icon(Icons.campaign_outlined, color: Color(0xFF25D366), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Format Pesan Promosi',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15, color: AppTheme.textPrimary),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Template Cepat',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _templates.map((tpl) {
                    return ActionChip(
                      backgroundColor: AppTheme.backgroundColor,
                      side: const BorderSide(color: AppTheme.borderColor),
                      label: Text(
                        tpl['title'] ?? '',
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.primaryColor),
                      ),
                      onPressed: () => _applyTemplate(tpl),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _promoTitleController,
                  style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Judul Promo',
                    hintText: 'Misal: Diskon 20% Weekend Seru',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _promoDescController,
                  maxLines: 3,
                  style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Isi Deskripsi / Produk Promo',
                    hintText: 'Detail diskon produk atau paket hemat...',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _promoCodeController,
                        style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
                        decoration: const InputDecoration(
                          labelText: 'Kode Voucher (Opsional)',
                          hintText: 'HEMAT20',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _validUntilController,
                        style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
                        decoration: const InputDecoration(
                          labelText: 'Berlaku Hingga (Opsional)',
                          hintText: '30 September 2026',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Pilih Pelanggan (${validCustomers.length} Ada Nomor WA)',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    if (_selectedCustomerIds.length == validCustomers.length) {
                      _selectedCustomerIds.clear();
                    } else {
                      _selectedCustomerIds.addAll(validCustomers.map((c) => c.id));
                    }
                  });
                },
                child: Text(
                  _selectedCustomerIds.length == validCustomers.length ? 'Batal Semua' : 'Pilih Semua',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (validCustomers.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('Belum ada data pelanggan dengan nomor WA')),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: validCustomers.length,
              itemBuilder: (context, index) {
                final customer = validCustomers[index];
                final isSelected = _selectedCustomerIds.contains(customer.id);

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    border: Border.all(
                      color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: ListTile(
                    leading: Checkbox(
                      value: isSelected,
                      activeColor: AppTheme.primaryColor,
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _selectedCustomerIds.add(customer.id);
                          } else {
                            _selectedCustomerIds.remove(customer.id);
                          }
                        });
                      },
                    ),
                    title: Text(customer.name, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.textPrimary)),
                    subtitle: Text(
                      '${customer.phone} - ${customer.totalTransactions ?? 0} Transaksi',
                      style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.send_rounded, color: Color(0xFF25D366)),
                      onPressed: () => _sendSinglePromo(customer, storeName),
                      tooltip: 'Kirim WA ke pelanggan ini',
                    ),
                  ),
                );
              },
            ),
          const SizedBox(height: 16),
          if (_selectedCustomerIds.isNotEmpty)
            SizedBox(
              width: double.infinity,
              height: AppTheme.touchTargetLarge,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMedium)),
                ),
                icon: const Icon(Icons.mark_chat_unread_outlined),
                label: Text(
                  'Kirim ke ${_selectedCustomerIds.length} Pelanggan Terpilih',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                onPressed: () {
                  final target = validCustomers.where((c) => _selectedCustomerIds.contains(c.id)).toList();
                  if (target.isNotEmpty) {
                    _sendSinglePromo(target.first, storeName);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Membuka WA untuk ${target.first.name}')),
                    );
                  }
                },
              ),
            ),
          if (_sentHistory.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              'Riwayat Kirim (${_sentHistory.length})',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 10),
            ..._sentHistory.map((h) => _buildHistoryCard(h)),
          ],
        ],
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, String> h) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF25D366).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.check_circle_outline, color: Color(0xFF25D366), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(h['name'] ?? '', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.textPrimary)),
                const SizedBox(height: 2),
                Text(h['message'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary)),
                const SizedBox(height: 4),
                Text(h['time'] ?? '', style: GoogleFonts.inter(fontSize: 10, color: AppTheme.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRetentionTab(String storeName) {
    final now = DateTime.now();
    final inactiveCustomers = _customers.where((c) {
      if (c.phone == null || c.phone!.isEmpty) return false;
      if (c.lastVisit == null) return true;
      final days = now.difference(c.lastVisit!).inDays;
      return days >= 30;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: AppTheme.aiBadgeGradient,
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            ),
            child: Row(
              children: [
                const Icon(Icons.tips_and_updates_outlined, color: Colors.white, size: 26),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'AI CRM Retensi: Pelanggan yang tidak mampir > 30 hari memiliki risiko hilang 70%. Kirim sapaan hangat untuk mengajak kembali belanja.',
                    style: GoogleFonts.inter(fontSize: 12, height: 1.4, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Daftar Pelanggan Perlu Re-engagement (${inactiveCustomers.length})',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 12),
          if (inactiveCustomers.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Text(
                  'Hebat! Tidak ada pelanggan yang menghilang lebih dari 30 hari.',
                  style: GoogleFonts.inter(color: AppTheme.textSecondary),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: inactiveCustomers.length,
              itemBuilder: (context, index) {
                final customer = inactiveCustomers[index];
                final daysInactive = customer.lastVisit == null
                    ? 30
                    : now.difference(customer.lastVisit!).inDays;

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              customer.name,
                              style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.textPrimary),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.warningColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '$daysInactive hari',
                              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.warningColor),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'No WA: ${customer.phone}',
                        style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: AppTheme.touchTargetMedium,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMedium)),
                          ),
                          icon: const Icon(Icons.chat_outlined, size: 16),
                          label: Text('Sapa WA', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700)),
                          onPressed: () => _sendRetention(customer, storeName, daysInactive),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
