import 'package:flutter_test/flutter_test.dart';
import 'package:kasirgo/config/supabase_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('FIX: clamp max_tokens in platform_configs LLM providers', () async {
    SharedPreferences.setMockInitialValues({});
    final client = SupabaseClient(SupabaseConfig.url, SupabaseConfig.anonKey);
    await client.auth.signInWithPassword(
        email: 'superadmin@kasirgo.com', password: 'sabar2021');

    for (final key in ['digital_marketing_llm', 'business_doctor']) {
      final res = await client
          .from('platform_configs')
          .select('value')
          .eq('key', key)
          .maybeSingle();
      final v = (res?['value'] as Map?)?.cast<String, dynamic>() ?? {};
      final pd = (v['provider_default'] as Map?)?.cast<String, dynamic>() ?? {};
      final old = pd['max_tokens'];
      // Clamp ke 4000: cukup untuk copy/naskah video, aman untuk semua model.
      pd['max_tokens'] = 4000;
      v['provider_default'] = pd;
      await client
          .from('platform_configs')
          .update({'value': v}).eq('key', key);
      // ignore: avoid_print
      print('$key: max_tokens $old -> 4000 (base_url=${pd['base_url']}, model=${pd['model']})');
    }

    // Verifikasi ulang
    for (final key in ['digital_marketing_llm', 'business_doctor']) {
      final res = await client
          .from('platform_configs')
          .select('value')
          .eq('key', key)
          .maybeSingle();
      final pd = ((res?['value'] as Map?)?.cast<String, dynamic>() ?? {})['provider_default'];
      // ignore: avoid_print
      print('VERIFY $key max_tokens = ${(pd as Map)['max_tokens']}');
    }

    await client.auth.signOut();
  });
}
