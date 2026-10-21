import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/dynamic_pricing_service.dart';
import '../../utils/dynamic_pricing.dart';
import '../../utils/formatters.dart';

/// Layar Dynamic Pricing: saran diskon & koreksi harga dari Dokter Bisnis.
///
/// Semua perhitungan lokal ([DynamicPricing]); tombol "Terapkan" menulis ke
/// `product_discounts` / `products.base_price` lalu dicatat ke jejak aksi.
class DynamicPricingScreen extends ConsumerStatefulWidget {
  final DynamicPricingService? service;
  const DynamicPricingScreen({super.key, this.service});

  @override
  ConsumerState<DynamicPricingScreen> createState() =>
      _DynamicPricingScreenState();
}

class _DynamicPricingScreenState extends ConsumerState<DynamicPricingScreen> {
  late final DynamicPricingService _service;
  DynamicPricingPlan? _plan;
  bool _loading = true;
  final Set<String> _applying = {};
  int _appliedCount = 0;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? DynamicPricingService();
    _load();
  }

  String? get _outletId => ref.read(currentUserProvider)?.outletId;

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final outletId = _outletId;
      if (outletId != null && outletId.isNotEmpty) {
        final plan = await _service.loadPlan(outletId);
        if (mounted) setState(() => _plan = plan);
      }
    } catch (_) {
      // Biarkan layar menampilkan keadaan kosong bila data gagal dimuat.
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _applyDiscount(PriceRecommendation rec) async {
    final outletId = _outletId;
    if (outletId == null || outletId.isEmpty) return;
    setState(() => _applying.add(rec.product.id));
    try {
      await _service.applyDiscount(rec);
      await _service.logAction(
        outletId: outletId,
        description:
            'Diskon ${rec.discountPercent}% untuk ${rec.product.name} '
            '(${rec.daysInactive} hari tidak laku)',
        result: {
          'product_id': rec.product.id,
          'product_name': rec.product.name,
          'kind': 'diskon',
          'discount_percent': rec.discountPercent,
          'price_before': rec.currentPrice,
          'price_after': rec.suggestedPrice,
          'days_inactive': rec.daysInactive,
        },
        outcome: 'diskon_dipasang',
        channel: 'offline',
      );
      _appliedCount++;
      if (mounted) {
        _snack('Diskon ${rec.discountPercent}% untuk ${rec.product.name} aktif.');
      }
    } catch (_) {
      if (mounted) _snack('Gagal memasang diskon. Coba lagi.');
    }
    if (mounted) setState(() => _applying.remove(rec.product.id));
    await _load();
  }

  Future<void> _applyPrice(MarginAlert alert) async {
    final outletId = _outletId;
    if (outletId == null || outletId.isEmpty) return;
    setState(() => _applying.add(alert.product.id));
    try {
      await _service.applyPrice(alert);
      await _service.logAction(
        outletId: outletId,
        description:
            'Naikkan harga ${alert.product.name} dari '
            '${Formatters.currency(alert.currentPrice)} ke '
            '${Formatters.currency(alert.suggestedPrice)}',
        result: {
          'product_id': alert.product.id,
          'product_name': alert.product.name,
          'kind': 'harga',
          'price_before': alert.currentPrice,
          'price_after': alert.suggestedPrice,
          'margin_percent': alert.marginPercent,
        },
        outcome: 'harga_naik',
        channel: 'offline',
      );
      _appliedCount++;
      if (mounted) {
        _snack('Harga ${alert.product.name} diperbarui.');
      }
    } catch (_) {
      if (mounted) _snack('Gagal mengubah harga. Coba lagi.');
    }
    if (mounted) setState(() => _applying.remove(alert.product.id));
    await _load();
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final plan = _plan;
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Atur Harga & Diskon'),
        backgroundColor: AppTheme.surfaceColor,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loading ? null : _load,
            tooltip: 'Segarkan',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : plan == null
              ? _buildErrorState()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    children: [
                      _buildIntroCard(),
                      const SizedBox(height: 16),
                      _buildSummaryRow(plan),
                      const SizedBox(height: 20),
                      if (plan.isEmpty) _buildEmptyState(),
                      if (plan.discounts.isNotEmpty) ...[
                        _buildSectionTitle(
                          'Produk Lambat Laku',
                          '${plan.discounts.length} saran diskon',
                        ),
                        const SizedBox(height: 10),
                        ...plan.discounts.map(_buildDiscountCard),
                        const SizedBox(height: 20),
                      ],
                      if (plan.lowMargins.isNotEmpty) ...[
                        _buildSectionTitle(
                          'Margin Terlalu Tipis',
                          '${plan.lowMargins.length} saran kenaikan harga',
                        ),
                        const SizedBox(height: 10),
                        ...plan.lowMargins.map(_buildMarginCard),
                      ],
                      if (plan.isEmpty) const SizedBox(height: 8),
                      _buildFooterNote(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildIntroCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.price_change_rounded,
                  color: Colors.white, size: 22),
              const SizedBox(width: 8),
              const Text(
                'Atur Harga & Diskon',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Dokter Bisnis menghitung dari riwayat penjualan Anda: produk mana '
            'yang perlu didiskon agar cepat laku, dan mana yang harganya perlu '
            'dinaikkan agar tidak rugi.',
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: Colors.white.withValues(alpha: 0.92),
            ),
          ),
          if (_appliedCount > 0) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
              child: Text(
                '$_appliedCount saran sudah diterapkan',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryRow(DynamicPricingPlan plan) {
    return Row(
      children: [
        Expanded(
          child: _buildSummaryTile(
            icon: Icons.local_offer_rounded,
            label: 'Perlu diskon',
            value: '${plan.discounts.length}',
            color: AppTheme.warningTextColor,
            background: AppTheme.warningSoftColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryTile(
            icon: Icons.trending_down_rounded,
            label: 'Margin tipis',
            value: '${plan.lowMargins.length}',
            color: AppTheme.errorColor,
            background: AppTheme.errorSoftColor,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryTile({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required Color background,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                label,
                style: TextStyle(fontSize: 11, color: color),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
        ),
      ],
    );
  }

  Widget _buildDiscountCard(PriceRecommendation rec) {
    final busy = _applying.contains(rec.product.id);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
                  rec.product.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              _buildRankBadge(rec.rank),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${rec.daysInactive} hari tanpa penjualan · sisa stok '
            '${Formatters.number(rec.product.stock)} ${rec.product.unit}',
            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                Formatters.currency(rec.currentPrice),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                Formatters.currency(rec.suggestedPrice),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.successTextColor,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.successChipColor,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
                child: Text(
                  '-${rec.discountPercent}%',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.successTextColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: AppTheme.touchTargetMedium,
            child: FilledButton(
              onPressed: busy ? null : () => _applyDiscount(rec),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
              ),
              child: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Terapkan Diskon'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarginCard(MarginAlert alert) {
    final busy = _applying.contains(alert.product.id);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppTheme.errorSoftBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  alert.product.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              _buildRankBadge(alert.rank),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Modal ${Formatters.currency(alert.costPrice)} · jual '
            '${Formatters.currency(alert.currentPrice)}',
            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            alert.message,
            style: const TextStyle(
              fontSize: 12,
              height: 1.35,
              color: AppTheme.errorColor,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: AppTheme.touchTargetMedium,
            child: OutlinedButton(
              onPressed: busy ? null : () => _applyPrice(alert),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryColor,
                side: const BorderSide(color: AppTheme.primaryColor),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
              ),
              child: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text('Naikkan ke ${Formatters.currency(alert.suggestedPrice)}'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRankBadge(String rank) {
    final color = switch (rank) {
      'A' => AppTheme.successTextColor,
      'B' => AppTheme.warningTextColor,
      _ => AppTheme.textSecondary,
    };
    final background = switch (rank) {
      'A' => AppTheme.successChipColor,
      'B' => AppTheme.warningSoftColor,
      _ => AppTheme.surfaceMutedColor,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      child: Text(
        'Kelas $rank',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.successChipColor,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.verified_rounded,
                color: AppTheme.successTextColor, size: 26),
          ),
          const SizedBox(height: 12),
          const Text(
            'Harga Anda sudah sehat',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Belum ada produk yang perlu didiskon atau dinaikkan harganya. '
            'Cek lagi setelah beberapa hari berjualan.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: 40, color: AppTheme.textSecondary),
            const SizedBox(height: 12),
            const Text(
              'Data produk belum bisa dimuat',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Coba lagi'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooterNote() {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded,
              size: 16, color: AppTheme.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Saran dihitung dari riwayat transaksi dan harga modal produk. '
              'Diskon otomatis berlaku 7 hari dan langsung terpakai di kasir.',
              style: TextStyle(
                fontSize: 11,
                height: 1.4,
                color: AppTheme.textSecondary.withValues(alpha: 0.9),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
