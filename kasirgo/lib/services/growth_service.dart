import 'package:supabase_flutter/supabase_flutter.dart';

/// ST15-3 (13.25.4/13.25.5/13.25.6): layanan Bos Virtual Growth.
/// Menangani bundling, referral, dan peluang cross-sell.
class GrowthService {
  GrowthService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Ekspos client untuk query ad-hoc (mis. muat produk di layar bundling).
  SupabaseClient get productsClient => _client;

  // ---------------------------------------------------------------------------
  // BUNDLING (13.25.5)
  // ---------------------------------------------------------------------------

  /// Daftar paket bundling outlet (opsional hanya yang aktif).
  Future<List<Map<String, dynamic>>> listBundles(
    String outletId, {
    bool onlyActive = false,
  }) async {
    var query = _client
        .from('product_bundles')
        .select('*, product_bundle_items(id, product_id, quantity, products(name, base_price, stock))')
        .eq('outlet_id', outletId);
    if (onlyActive) query = query.eq('is_active', true);
    final res = await query.order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(res as List);
  }

  /// Simpan / perbarui paket bundling beserta isinya.
  Future<Map<String, dynamic>?> saveBundle({
    String? bundleId,
    required String outletId,
    required String name,
    String description = '',
    required double bundlePrice,
    required double originalPrice,
    bool isActive = true,
    required List<Map<String, dynamic>> items,
  }) async {
    final payload = {
      'outlet_id': outletId,
      'name': name,
      'description': description,
      'bundle_price': bundlePrice,
      'original_price': originalPrice,
      'is_active': isActive,
      'updated_at': DateTime.now().toIso8601String(),
    };

    final Map<String, dynamic> bundle;
    if (bundleId == null) {
      final res = await _client.from('product_bundles').insert(payload).select().single();
      bundle = Map<String, dynamic>.from(res);
    } else {
      final res = await _client
          .from('product_bundles')
          .update(payload)
          .eq('id', bundleId)
          .select()
          .single();
      bundle = Map<String, dynamic>.from(res);
      await _client.from('product_bundle_items').delete().eq('bundle_id', bundleId);
    }

    if (items.isNotEmpty) {
      final rows = items
          .map((it) => {
                'bundle_id': bundle['id'],
                'product_id': it['product_id'],
                'quantity': it['quantity'] ?? 1,
              })
          .toList();
      await _client.from('product_bundle_items').insert(rows);
    }
    return bundle;
  }

  /// Aktif/nonaktifkan paket bundling.
  Future<void> toggleBundle(String bundleId, bool isActive) async {
    await _client.from('product_bundles').update({
      'is_active': isActive,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', bundleId);
  }

  Future<void> deleteBundle(String bundleId) async {
    await _client.from('product_bundles').delete().eq('id', bundleId);
  }

  // ---------------------------------------------------------------------------
  // REFERRAL (13.25.6)
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> listReferralCodes(String outletId) async {
    final res = await _client
        .from('referral_codes')
        .select('*')
        .eq('outlet_id', outletId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(res as List);
  }

  Future<Map<String, dynamic>?> saveReferralCode({
    required String outletId,
    required String code,
    String title = '',
    double rewardAmount = 0,
    double rewardPercent = 0,
    double friendRewardAmount = 0,
    double minSpend = 0,
    int maxRedemptions = 0,
    String? expiresAt,
  }) async {
    final res = await _client.from('referral_codes').upsert({
      'outlet_id': outletId,
      'code': code.toUpperCase(),
      'title': title,
      'reward_amount': rewardAmount,
      'reward_percent': rewardPercent,
      'friend_reward_amount': friendRewardAmount,
      'min_spend': minSpend,
      'max_redemptions': maxRedemptions,
      if (expiresAt != null) 'expires_at': expiresAt,
      'is_active': true,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'code').select().maybeSingle();
    return res == null ? null : Map<String, dynamic>.from(res);
  }

  Future<void> toggleReferralCode(String codeId, bool isActive) async {
    await _client.from('referral_codes').update({
      'is_active': isActive,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', codeId);
  }

  /// Catat penggunaan kode referral oleh pelanggan baru (diajak).
  Future<void> recordReferralUse({
    required String outletId,
    required String referralCodeId,
    String? customerName,
    String? customerPhone,
    double spendAmount = 0,
  }) async {
    await _client.from('customer_referrals').insert({
      'outlet_id': outletId,
      'referral_code_id': referralCodeId,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'spend_amount': spendAmount,
      'status': spendAmount > 0 ? 'converted' : 'pending',
      if (spendAmount > 0) 'converted_at': DateTime.now().toIso8601String(),
    });
    // Increment redeemed_count.
    try {
      await _client.rpc('increment_referral_redeemed', params: {'p_code_id': referralCodeId});
    } catch (_) {}
  }

  /// Statistik konversi referral per kode.
  Future<List<Map<String, dynamic>>> referralStats(String outletId) async {
    final res = await _client
        .from('customer_referrals')
        .select('referral_code_id, status, spend_amount, referral_codes(code, title)')
        .eq('outlet_id', outletId);
    final rows = List<Map<String, dynamic>>.from(res as List);

    final map = <String, Map<String, dynamic>>{};
    for (final r in rows) {
      final codeId = r['referral_code_id']?.toString() ?? '';
      final rc = r['referral_codes'];
      final entry = map.putIfAbsent(codeId, () => {
            'referral_code_id': codeId,
            'code': rc is Map ? rc['code'] : '',
            'title': rc is Map ? rc['title'] : '',
            'total': 0,
            'converted': 0,
            'spend': 0.0,
          });
      entry['total'] = (entry['total'] as int) + 1;
      if (r['status'] == 'converted' || r['status'] == 'rewarded') {
        entry['converted'] = (entry['converted'] as int) + 1;
      }
      entry['spend'] = (entry['spend'] as double) + ((r['spend_amount'] as num?)?.toDouble() ?? 0.0);
    }
    return map.values.toList();
  }
}
