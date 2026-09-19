import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  bool _isLoading = true;

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
  }

  @override
  Widget build(BuildContext context) {
    const storeName = 'KasirGo Store';

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('WhatsApp Marketing & CRM'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.accentColor,
          tabs: const [
            Tab(icon: Icon(Icons.campaign), text: 'Broadcast Promo'),
            Tab(icon: Icon(Icons.autorenew), text: 'Auto-Retensi (30+ Hari)'),
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
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Format Pesan Promosi',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _promoTitleController,
                  decoration: const InputDecoration(
                    labelText: 'Judul Promo',
                    hintText: 'Misal: Diskon 20% Weekend Seru',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _promoDescController,
                  maxLines: 3,
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

                return Card(
                  color: AppTheme.surfaceColor,
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Checkbox(
                      value: isSelected,
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
                    title: Text(customer.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${customer.phone} - ${customer.totalTransactions ?? 0} Transaksi'),
                    trailing: IconButton(
                      icon: const Icon(Icons.send, color: Colors.green),
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
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.mark_chat_unread),
                label: Text('Kirim ke ${_selectedCustomerIds.length} Pelanggan Terpilih (Satu per Satu)'),
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
              color: AppTheme.accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.accentColor.withValues(alpha: 0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.tips_and_updates, color: AppTheme.accentColor, size: 30),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'AI CRM Retensi: Pelanggan yang tidak mampir > 30 hari memiliki risiko hilang 70%. Kirim sapaan hangat untuk mengajak kembali belanja.',
                    style: TextStyle(fontSize: 13, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Daftar Pelanggan Perlu Re-engagement (${inactiveCustomers.length})',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          const SizedBox(height: 12),
          if (inactiveCustomers.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Text('Hebat! Tidak ada pelanggan yang menghilang lebih dari 30 hari.'),
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

                return Card(
                  color: AppTheme.surfaceColor,
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    title: Text(customer.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('No WA: ${customer.phone}'),
                        Text(
                          'Terakhir belanja: $daysInactive hari lalu',
                          style: const TextStyle(color: Colors.amber, fontSize: 12),
                        ),
                      ],
                    ),
                    trailing: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      icon: const Icon(Icons.chat, size: 16),
                      label: const Text('Sapa WA'),
                      onPressed: () => _sendRetention(customer, storeName, daysInactive),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
