// lib/screens/owner/staradmin_dashboard.dart - STARADMIN EDITION
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/widgets/staradmin_widgets.dart';

class StarAdminDashboard extends ConsumerStatefulWidget {
  const StarAdminDashboard({super.key});

  @override
  ConsumerState<StarAdminDashboard> createState() => _StarAdminDashboardState();
}

class _StarAdminDashboardState extends ConsumerState<StarAdminDashboard>
    with TickerProviderStateMixin {
  int _selectedNavIndex = 0;
  late TabController _tabController;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Mock data untuk testing
  final List<Map<String, dynamic>> _metrics = [
    {
      'title': 'TOTAL OMSET',
      'value': 'Rp 128.5M',
      'percentage': '+12.5%',
      'isPositive': true,
      'icon': Icons.show_chart_outlined,
      'color': const Color(0xFF059669),
    },
    {
      'title': 'TRANSAKSI',
      'value': '1,284',
      'percentage': '+8.2%',
      'isPositive': true,
      'icon': Icons.receipt_long_outlined,
      'color': const Color(0xFF0284C7),
    },
    {
      'title': 'TAMBAH BARANG',
      'value': '847',
      'percentage': '-3.4%',
      'isPositive': false,
      'icon': Icons.shopping_cart_outlined,
      'color': const Color(0xFFDC2626),
    },
    {
      'title': 'WARUNG AKTIF',
      'value': '58',
      'percentage': '+2',
      'isPositive': true,
      'icon': Icons.store_outlined,
      'color': const Color(0xFFF59E0B),
    },
  ];

  final List<Map<String, dynamic>> _outlets = [
    {
      'name': 'Warung Bakso Mbok Sum',
      'type': 'Kelontong',
      'location': 'Jakarta Selatan',
      'omset': 'Rp 45.2M',
      'transactions': '847',
      'progress': 0.75,
      'color': const Color(0xFFEFF6FF),
      'icon': Icons.restaurant,
    },
    {
      'name': 'Kopi Senja Cafe',
      'type': 'Cafe',
      'location': 'Bandung',
      'omset': 'Rp 32.8M',
      'transactions': '523',
      'progress': 0.62,
      'color': const Color(0xFFF0FDF4),
      'icon': Icons.coffee,
    },
    {
      'name': 'Tukang Bangunan Jaya',
      'type': 'Retail',
      'location': 'Surabaya',
      'omset': 'Rp 28.4M',
      'transactions': '1,156',
      'progress': 0.88,
      'color': const Color(0xFFFFFBE8),
      'icon': Icons.construction,
    },
    {
      'name': 'Minimarket Ceria',
      'type': 'Kelontong',
      'location': 'Yogyakarta',
      'omset': 'Rp 22.1M',
      'transactions': '2,234',
      'progress': 0.54,
      'color': const Color(0xFFF5F3FF),
      'icon': Icons.store,
    },
  ];

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 800;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Row(
          children: [
            // SIDEBAR (Desktop only)
            if (!isMobile) _buildSidebar(),
            
            // MAIN CONTENT
            Expanded(
              child: Column(
                children: [
                  // HEADER
                  _buildHeader(isMobile, screenWidth),
                  
                  // SCROLLABLE CONTENT
                  Expanded(
                    child: CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: isMobile ? 16 : 24,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 24),
                                _buildMarketOverview(),
                                const SizedBox(height: 32),
                                _buildQuickActions(),
                                const SizedBox(height: 32),
                                _buildRevenueChart(),
                                const SizedBox(height: 32),
                                _buildOutletGrid(),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 260,
      color: Colors.white,
      child: Column(
        children: [
          // LOGO AREA
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.point_of_sale, color: const Color(0xFF0284C7)),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'KasirGo',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    Text(
                      '3.0 Enterprise',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF9CA3AF),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Spacer(),

          // NAVIGATION ITEMS
          _buildNavItem(Icons.dashboard_outlined, 'Dashboard', 0),
          _buildNavItem(Icons.store_outlined, 'Outlet', 1),
          _buildNavItem(Icons.receipt_long_outlined, 'Transaksi', 2),
          _buildNavItem(Icons.inventory_2_outlined, 'Produk', 3),
          _buildNavItem(Icons.people_outline, 'Karyawan', 4),
          _buildNavItem(Icons.bar_chart_outlined, 'Laporan', 5),
          _buildNavItem(Icons.settings_outlined, 'Pengaturan', 6),

          Spacer(),

          // USER PROFILE
          Padding(
            padding: const EdgeInsets.all(20),
            child: _buildUserProfile(),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _selectedNavIndex == index;
    return InkWell(
      onTap: () {
        setState(() => _selectedNavIndex = index);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF0284C7) : const Color(0xFF9CA3AF),
              size: 22,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? const Color(0xFF111827) : const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isMobile, double screenWidth) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 24,
      ),
      height: 70,
      child: Row(
        children: [
          if (isMobile)
            IconButton(
              icon: const Icon(Icons.menu, color: Color(0xFF6B7280)),
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            ),
          
          Expanded(
            child: Text(
              'Dashboard Overview',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF111827),
              ),
            ),
          ),

          Row(
            children: [
              _buildIconButton(Icons.notifications_outlined),
              const SizedBox(width: 8),
              _buildIconButton(Icons.add_outlined),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton(IconData icon) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: const Color(0xFF6B7280)),
    );
  }

  Widget _buildMarketOverview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'MARKET OVERVIEW',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF6B7280),
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 16),
        
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: _metrics.map((m) => 
            Expanded(
              flex: 1,
              child: _buildMetricCard(m),
            )
          ).toList(),
        ),
      ],
    );
  }

  Widget _buildMetricCard(Map<String, dynamic> metric) {
    final icon = metric['icon'] as IconData;
    final iconColor = metric['color'] as Color;
    final percentage = metric['percentage'] as String;
    final isPositive = metric['isPositive'] as bool;

    return StarAdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: iconColor, size: 24),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isPositive 
                    ? const Color(0xFFF0FDF4).withOpacity(0.8) 
                    : const Color(0xFFFEE2E2).withOpacity(0.8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPositive ? Icons.trending_up : Icons.trending_down,
                      size: 12,
                      color: isPositive ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      percentage,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isPositive ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            metric['title'] as String,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF6B7280),
            ),
          ),
          const Spacer(),
          Text(
            metric['value'] as String,
            style: GoogleFonts.inter(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'QUICK ACTIONS',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            ActionButton(
              label: 'Tambah Outlet',
              icon: Icons.add_circle_outline,
              color: const Color(0xFF0284C7),
              onTap: () {},
            ),
            ActionButton(
              label: 'Scan Barcode',
              icon: Icons.qr_code_scanner,
              color: const Color(0xFF0EA5E9),
              onTap: () {},
            ),
            ActionButton(
              label: 'Input Transaksi',
              icon: Icons.receipt,
              color: const Color(0xFF10B981),
              onTap: () {},
            ),
            ActionButton(
              label: 'Export Laporan',
              icon: Icons.download_outlined,
              color: const Color(0xFF8B5CF6),
              onTap: () {},
            ),
            ActionButton(
              label: 'Manajemen Stok',
              icon: Icons.inventory_2_outlined,
              color: const Color(0xFFF59E0B),
              onTap: () {},
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRevenueChart() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'REVENUE ANALYTICS',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF111827),
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {},
              itemBuilder: (context) => [
                const PopupMenuItem(value: '7d', child: Text('7 Hari Terakhir')),
                const PopupMenuItem(value: '30d', child: Text('30 Hari Terakhir')),
                const PopupMenuItem(value: '90d', child: Text('90 Hari Terakhir')),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        StarAdminCard(
          child: Container(
            height: 280,
            child: Column(
              children: [
                // Chart area placeholder with revenue visualization
                Expanded(
                  child: CustomPaint(
                    painter: RevenueChartPainter(),
                  ),
                ),
                const SizedBox(height: 16),
                _buildMonthLabels(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMonthLabels() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildLabel('Jan'),
        _buildLabel('Feb'),
        _buildLabel('Mar'),
        _buildLabel('Apr'),
        _buildLabel('May'),
        _buildLabel('Jun'),
      ],
    );
  }

  Widget _buildLabel(String month) {
    return Text(
      month,
      style: GoogleFonts.inter(
        fontSize: 12,
        color: const Color(0xFF9CA3AF),
      ),
    );
  }

  Widget _buildOutletGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'OUTLET MANAGEMENT',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF111827),
              ),
            ),
            TextButton(
              onPressed: () {},
              child: Text(
                'Lihat Semua',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: const Color(0xFF0284C7),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.8,
          ),
          itemCount: _outlets.length,
          itemBuilder: (context, index) {
            return _buildOutletCard(_outlets[index]);
          },
        ),
      ],
    );
  }

  Widget _buildOutletCard(Map<String, dynamic> outlet) {
    return StarAdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: outlet['color'] as Color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  outlet['icon'] as IconData,
                  color: (outlet['color'] as Color).withOpacity(0.8),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      outlet['name'] as String,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${outlet['type']} • ${outlet['location']}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: const Color(0xFF9CA3AF),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: const Color(0xFF9CA3AF)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildStat('Omset', outlet['omset'] as String)),
              const SizedBox(width: 8),
              Expanded(child: _buildStat('Transaksi', outlet['transactions'] as String)),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: outlet['progress'] as double,
            backgroundColor: const Color(0xFFF3F4F6),
            valueColor: AlwaysStoppedAnimation<Color>(
              outlet['color']!.withOpacity(0.8),
            ),
            borderRadius: BorderRadius.circular(6),
            minHeight: 4,
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: const Color(0xFF9CA3AF),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF111827),
          ),
        ),
      ],
    );
  }

  Widget _buildUserProfile() {
    return StarAdminCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 16,
      showShadow: false,
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: const Color(0xFF0284C7),
            child: const Icon(Icons.person, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Budi Santoso',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF111827),
                  ),
                ),
                Text(
                  'budi@warung.com',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF9CA3AF),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// CHART PAINTER FOR REVENUE VISUALIZATION
class RevenueChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF0284C7)
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, size.height);

    final points = List.generate(7, (i) => i * (size.width / 6));
    final values = [45, 52, 48, 62, 58, 67, 72];
    
    for (int i = 0; i < points.length; i++) {
      final x = points[i];
      final y = size.height - (values[i] / 100 * size.height * 0.7);
      
      if (i == 0) {
        path.lineTo(x, y);
      } else {
        path.quadraticBezierTo(
          points[i-1] + (points[i] - points[i-1]) / 2,
          size.height,
          x,
          y,
        );
      }
    }

    path.lineTo(size.width, size.height);
    path.close();
    canvas.drawPath(path, paint);

    // Gradient overlay
    final gradientPaint = Paint()
      ..shader = LinearGradient(
        colors: [const Color(0xFF0284C7).withOpacity(0.3), const Color(0xFF0284C7).withOpacity(0)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(path, gradientPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
