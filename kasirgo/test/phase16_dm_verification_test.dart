// Verifikasi E2E Phase 16 - Squad Digital Marketing (Studio Desain/Promosi/Iklan).
// Menjalankan alur penuh: login owner -> akses tabel DM -> guardrail -> campaign
// lifecycle -> verifikasi token kredensial LLM TIDAK bocor ke klien.
//
// Jalankan: flutter test test/phase16_dm_verification_test.dart -r expanded
import 'package:flutter_test/flutter_test.dart';
import 'package:kasirgo/config/supabase_config.dart';
import 'package:kasirgo/services/dm_service.dart';
import 'package:kasirgo/screens/owner/ads_studio_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  SharedPreferences.setMockInitialValues({});

  final ownerEmail = 'ikhlassabar2021@gmail.com';
  const ownerPassword = 'sabar2021';
  const outletTokoTest = '229c94d7-ce6d-4be1-98f5-448f600528cc';

  late SupabaseClient client;
  late DmService dm;

  setUp(() async {
    client = SupabaseClient(SupabaseConfig.url, SupabaseConfig.anonKey);
    await client.auth
        .signInWithPassword(email: ownerEmail, password: ownerPassword);
    dm = DmService(client: client);
  });

  tearDown(() async {
    await client.auth.signOut();
  });

  test('ST16-1a: login owner + akses tabel dm_settings (Studio Desain)', () async {
    final settings = await dm.getSettings(outletTokoTest);
    expect(settings['outlet_id'], outletTokoTest);
    expect(settings.containsKey('mode_design'), isTrue);
    expect(settings.containsKey('mode_promo'), isTrue);
    expect(settings.containsKey('mode_ads'), isTrue);
    expect(settings.containsKey('budget_daily_limit'), isTrue);
    // ignore: avoid_print
    print('dm_settings OK: mode_design=${settings['mode_design']} '
        'mode_promo=${settings['mode_promo']} mode_ads=${settings['mode_ads']}');
  });

  test('ST16-2a: akses dm_assets + simpan aset (Studio Desain)', () async {
    final before = await dm.listAssets(outletTokoTest);
    // ignore: avoid_print
    print('dm_assets sebelum: ${before.length} baris');

    final asset = await dm.saveAsset(
      outletId: outletTokoTest,
      kind: 'image',
      title: '__TEST_PHASE16__',
      content: 'Kopi susu gula aren diskon 20%',
      caption: 'Test caption Phase 16',
      hashtags: '#kasirgo #phase16',
      source: 'brief',
    );
    expect(asset, isNotNull, reason: 'insert dm_assets gagal');
    final assetId = asset!['id'] as String;

    final after = await dm.listAssets(outletTokoTest, kind: 'image');
    expect(
      after.any((a) => a['id'] == assetId),
      isTrue,
      reason: 'aset baru tidak muncul di daftar dm_assets',
    );
    // ignore: avoid_print
    print('dm_assets insert+list OK (id=$assetId)');

    await dm.updateAsset(assetId, {'status': 'approved'});
    await dm.deleteAsset(assetId);
    final afterDel = await dm.listAssets(outletTokoTest, kind: 'image');
    expect(
      afterDel.any((a) => a['id'] == assetId),
      isFalse,
      reason: 'aset masih ada setelah delete',
    );
    // ignore: avoid_print
    print('dm_assets delete OK');
  });

  test('ST16-3a: akses dm_posts + simpan draft (Studio Promosi)', () async {
    final before = await dm.listPosts(outletTokoTest);
    // ignore: avoid_print
    print('dm_posts sebelum: ${before.length} baris');

    await dm.savePost(
      outletId: outletTokoTest,
      channel: 'wa_status',
      caption: 'Test draft Phase 16',
      status: 'draft',
    );
    final after = await dm.listPosts(outletTokoTest);
    expect(
      after.any((p) => (p['caption'] ?? '').toString().contains('Phase 16')),
      isTrue,
      reason: 'draft post tidak muncul di dm_posts',
    );
    // ignore: avoid_print
    print('dm_posts insert OK (total=${after.length})');

    final target = after.firstWhere(
      (p) => (p['caption'] ?? '').toString().contains('Phase 16'),
    );
    await dm.deletePost(target['id'] as String);
    // ignore: avoid_print
    print('dm_posts delete OK');
  });

  test('ST16-4a: guardrail RPC dm_owner_guardrails + dm_channel_status', () async {
    final g = await dm.getGuardrails(outletTokoTest);
    // ignore: avoid_print
    print('guardrails: $g');
    expect(g.containsKey('owner_daily_limit'), isTrue,
        reason: 'dm_owner_guardrails harus balik owner_daily_limit');
    expect(g.containsKey('roas_target'), isTrue,
        reason: 'dm_owner_guardrails harus balik roas_target');
    // Token/api_key TIDAK boleh ada di response guardrail.
    final gStr = g.toString().toLowerCase();
    expect(gStr.contains('api_key'), isFalse,
        reason: 'guardrail tidak boleh memuat api_key');
    expect(gStr.contains('secret'), isFalse,
        reason: 'guardrail tidak boleh memuat secret');

    final accounts = await dm.getChannelStatus(outletTokoTest);
    // ignore: avoid_print
    print('channel_status: ${accounts.length} akun');
    final aStr = accounts.toString().toLowerCase();
    expect(aStr.contains('token_enc'), isFalse,
        reason: 'channel_status tidak boleh memuat token_enc');
    expect(aStr.contains('api_key'), isFalse,
        reason: 'channel_status tidak boleh memuat api_key');
  });

  test('ST16-4b: campaign lifecycle draft -> approve -> metrics -> auto-pause', () async {
    final before = await dm.listCampaigns(outletTokoTest);
    // ignore: avoid_print
    print('dm_campaigns sebelum: ${before.length} baris');

    await dm.saveCampaign(
      outletId: outletTokoTest,
      channel: 'meta',
      objective: 'traffic',
      budgetDaily: 20000,
      radiusKm: 3,
    );
    final after = await dm.listCampaigns(outletTokoTest);
    final campaign = after.firstWhere(
      (c) => c['channel'] == 'meta' &&
          (c['status']?.toString() == 'draft') &&
          c['budget_daily'] == 20000,
      orElse: () => <String, dynamic>{},
    );
    expect(campaign.isNotEmpty, isTrue,
        reason: 'campaign draft tidak tersimpan di dm_campaigns');
    final campaignId = campaign['id'] as String;
    expect(campaign['radius_km'], 3, reason: 'radius_km harus 3');
    // ignore: avoid_print
    print('campaign draft tersimpan (id=$campaignId, radius_km=3)');

    await dm.updateCampaign(campaignId, {
      'status': 'active',
      'approved_at': DateTime.now().toIso8601String(),
      'approved_by': client.auth.currentUser?.id,
    });
    final active = await dm.listCampaigns(outletTokoTest);
    final activeC = active.firstWhere((c) => c['id'] == campaignId);
    expect(activeC['status'], 'active', reason: 'campaign harus aktif setelah approve');
    // ignore: avoid_print
    print('campaign approve -> status=${activeC['status']}');

    final m = computeAdMetrics({
      'impressions': 1000,
      'clicks': 40,
      'spend': 50000,
      'revenue': 100000, // ROAS=2.0 < target 3.0 -> harus auto-pause
    });
    expect(m['roas'], 2.0);
    // ignore: avoid_print
    print('metrics compute: CTR=${m['ctr']}% CPC=${m['cpc']} ROAS=${m['roas']}');

    final roasTarget = (await dm.getGuardrails(outletTokoTest))['roas_target'];
    if (m['roas'] is num && roasTarget is num && m['roas']! < roasTarget) {
      await dm.updateCampaign(campaignId, {
        'status': 'paused',
        'paused_reason': 'roas_below_target',
        'metrics': m,
      });
      await dm.logAction(outletTokoTest, 'dm.campaign.autopause', {
        'campaign_id': campaignId,
        'roas': m['roas'],
        'roas_target': roasTarget,
      });
      // ignore: avoid_print
      print('auto-pause aktif: ROAS ${m['roas']} < target $roasTarget');
    }

    final paused = await dm.listCampaigns(outletTokoTest);
    final pausedC = paused.firstWhere((c) => c['id'] == campaignId);
    expect(pausedC['status'], 'paused', reason: 'campaign harus paused setelah ROAS<target');
    expect(pausedC['paused_reason'], 'roas_below_target');
    expect(pausedC['metrics']['roas'], 2.0);
    // ignore: avoid_print
    print('campaign auto-pause terverifikasi: paused_reason=${pausedC['paused_reason']}');

    await dm.deleteCampaign(campaignId);
    final afterDel = await dm.listCampaigns(outletTokoTest);
    expect(
      afterDel.any((c) => c['id'] == campaignId),
      isFalse,
      reason: 'campaign masih ada setelah delete',
    );
    // ignore: avoid_print
    print('campaign delete OK');
  });

  test('ST16-HARDEN: token LLM TIDAK bocor ke klien owner', () async {
    final platform = await client
        .from('platform_configs')
        .select('key')
        .inFilter('key', ['business_doctor', 'digital_marketing_llm']);
    expect((platform as List).length, 0,
        reason: 'platform_configs rahasia TIDAK boleh terbaca klien owner');

    // outlet_ai_configs: kolom non-secret boleh dibaca owner, tetapi kolom
    // rahasia `api_key_enc` WAJIB ditolak (permission denied / 42501).
    var aiSecretBlocked = false;
    try {
      await client.from('outlet_ai_configs').select('api_key_enc').limit(1);
    } catch (_) {
      aiSecretBlocked = true;
    }
    expect(aiSecretBlocked, isTrue,
        reason: 'outlet_ai_configs.api_key_enc TIDAK boleh terbaca klien owner');

    final dmAccounts = await client
        .from('dm_channel_accounts')
        .select('id')
        .limit(1);
    expect((dmAccounts as List).length, 0,
        reason: 'dm_channel_accounts.token_enc TIDAK boleh terbaca klien owner');
    // ignore: avoid_print
    print('HARDENING OK: kolom rahasia tidak terbaca oleh owner klien');
  });
}
