import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/ai_engine.dart';
import 'supabase_service.dart';

class DmService {
  DmService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<Map<String, dynamic>> _invoke(Map<String, dynamic> body) async {
    try {
      final res = await _client.functions.invoke('dm_creative', body: body);
      if (res.data is Map) return (res.data as Map).cast<String, dynamic>();
      return <String, dynamic>{};
    } on FunctionException catch (e) {
      throw Exception(_message(e.details) ?? 'Gagal menghubungi Squad Digital Marketing.');
    }
  }

  String? _message(dynamic details) {
    if (details is Map) {
      final m = details['message'] ?? details['error'];
      if (m != null) return m.toString();
    }
    return details?.toString();
  }

  Future<Map<String, dynamic>> generateCopy({
    required String outletId,
    required String brief,
    String tone = 'ramah',
    String goal = '',
    List<String> channels = const [],
    List<String> productIds = const [],
  }) {
    return _invoke({
      'mode': 'generate',
      'outlet_id': outletId,
      'brief': brief,
      'tone': tone,
      'goal': goal,
      'channels': channels,
      'product_ids': productIds,
    });
  }

  Future<Map<String, dynamic>> generateVideo({
    required String outletId,
    required String brief,
    String tone = 'ramah',
    String goal = '',
    int duration = 20,
    List<String> productIds = const [],
  }) {
    return _invoke({
      'mode': 'generate',
      'kind': 'video',
      'outlet_id': outletId,
      'brief': brief,
      'tone': tone,
      'goal': goal,
      'duration': duration,
      'product_ids': productIds,
    });
  }

  Future<List<Map<String, dynamic>>> listAssets(
    String outletId, {
    String? kind,
    int limit = 40,
  }) async {
    var query = _client
        .from('dm_assets')
        .select('id, kind, title, file_path, content, caption, hashtags, source, status, meta, created_at')
        .eq('outlet_id', outletId);
    if (kind != null) query = query.eq('kind', kind);
    final res = await query.order('created_at', ascending: false).limit(limit);
    return (res as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>?> saveAsset({
    required String outletId,
    required String kind,
    required String title,
    String? filePath,
    String? content,
    String? caption,
    String? hashtags,
    String source = 'brief',
    Map<String, dynamic>? meta,
  }) async {
    final res = await _client.from('dm_assets').insert({
      'outlet_id': outletId,
      'kind': kind,
      'title': title,
      'file_path': filePath,
      'content': content,
      'caption': caption,
      'hashtags': hashtags,
      'source': source,
      'status': 'draft',
      'meta': meta ?? <String, dynamic>{},
    }).select('id, kind, title, file_path, content, caption, hashtags, status, meta, created_at').maybeSingle();
    return res;
  }

  Future<void> updateAsset(String id, Map<String, dynamic> patch) async {
    await _client.from('dm_assets').update({
      ...patch,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  Future<void> deleteAsset(String id) async {
    await _client.from('dm_assets').delete().eq('id', id);
  }

  Future<Map<String, dynamic>> getSettings(String outletId) async {
    final res = await _client
        .from('dm_settings')
        .select('outlet_id, mode_design, mode_promo, mode_ads, budget_daily_limit, quiet_hours, watermark, last_sync')
        .eq('outlet_id', outletId)
        .maybeSingle();
    if (res == null) {
      return {
        'outlet_id': outletId,
        'mode_design': 'manual',
        'mode_promo': 'manual',
        'mode_ads': 'manual',
        'budget_daily_limit': 0,
        'quiet_hours': {'start': '22:00', 'end': '06:00'},
        'watermark': null,
      };
    }
    return res;
  }

  Future<void> saveSettings(String outletId, Map<String, dynamic> data) async {
    await _client.from('dm_settings').upsert({
      'outlet_id': outletId,
      ...data,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'outlet_id');
  }

  Future<List<Map<String, dynamic>>> getProducts(String outletId) async {
    final res = await _client
        .from('products')
        .select('id, name, base_price, stock, image_local_path')
        .eq('outlet_id', outletId)
        .order('name', ascending: true)
        .limit(200);
    return (res as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> listPosts(
    String outletId, {
    DateTime? start,
    DateTime? end,
    int limit = 150,
  }) async {
    var query = _client
        .from('dm_posts')
        .select(
            'id, outlet_id, asset_id, channel, status, caption, scheduled_at, posted_at, post_url, error, created_at, dm_assets(title, kind, file_path)')
        .eq('outlet_id', outletId);
    if (start != null) {
      query = query.gte('scheduled_at', start.toIso8601String());
    }
    if (end != null) {
      query = query.lte('scheduled_at', end.toIso8601String());
    }
    final res = await query.order('scheduled_at', ascending: true).limit(limit);
    return (res as List).cast<Map<String, dynamic>>();
  }

  Future<void> savePost({
    required String outletId,
    required String channel,
    String? assetId,
    String? caption,
    DateTime? scheduledAt,
    String status = 'draft',
  }) async {
    await _client.from('dm_posts').insert({
      'outlet_id': outletId,
      'asset_id': assetId,
      'channel': channel,
      'caption': caption,
      'status': status,
      'scheduled_at': scheduledAt?.toIso8601String(),
    });
  }

  Future<void> updatePost(String id, Map<String, dynamic> patch) async {
    await _client.from('dm_posts').update(patch).eq('id', id);
  }

  Future<void> deletePost(String id) async {
    await _client.from('dm_posts').delete().eq('id', id);
  }

  Future<List<int>> suggestBestHours(String outletId) async {
    try {
      final txs = await SupabaseService().getTransactions(outletId, limit: 200);
      if (txs.isEmpty) return const [];
      final res = AIEngine().bestTimeToSell(txs);
      return ((res['bestHours'] as List?) ?? const []).cast<int>();
    } catch (_) {
      return const [];
    }
  }
}
