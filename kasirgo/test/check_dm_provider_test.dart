import 'package:flutter_test/flutter_test.dart';
import 'package:kasirgo/config/supabase_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('CHECK: digital_marketing_llm provider_default (non-secret)', () async {
    SharedPreferences.setMockInitialValues({});
    final client = SupabaseClient(SupabaseConfig.url, SupabaseConfig.anonKey);
    await client.auth.signInWithPassword(
        email: 'superadmin@kasirgo.com', password: 'sabar2021');

    final res = await client
        .from('platform_configs')
        .select('value')
        .eq('key', 'digital_marketing_llm')
        .maybeSingle();
    final v = (res?['value'] as Map?)?.cast<String, dynamic>() ?? {};
    final pd = (v['provider_default'] as Map?)?.cast<String, dynamic>() ?? {};
    // ignore: avoid_print
    print('provider_default = {');
    // ignore: avoid_print
    print('  base_url: ${pd['base_url']}');
    // ignore: avoid_print
    print('  model: ${pd['model']}');
    // ignore: avoid_print
    print('  temperature: ${pd['temperature']}');
    // ignore: avoid_print
    print('  max_tokens: ${pd['max_tokens']}');
    // ignore: avoid_print
    print('  api_key present: ${pd['api_key'] != null && pd['api_key'].toString().isNotEmpty}');
    // ignore: avoid_print
    print('}');
    // ignore: avoid_print
    print('provider_default keys: ${pd.keys.toList()}');
    // ignore: avoid_print
    print('rate_limit: ${v['rate_limit']}');

    // Also check business_doctor provider for comparison
    final res2 = await client
        .from('platform_configs')
        .select('value')
        .eq('key', 'business_doctor')
        .maybeSingle();
    final v2 = (res2?['value'] as Map?)?.cast<String, dynamic>() ?? {};
    final pd2 = (v2['provider_default'] as Map?)?.cast<String, dynamic>() ?? {};
    // ignore: avoid_print
    print('business_doctor provider_default = {');
    // ignore: avoid_print
    print('  base_url: ${pd2['base_url']}');
    // ignore: avoid_print
    print('  model: ${pd2['model']}');
    // ignore: avoid_print
    print('  temperature: ${pd2['temperature']}');
    // ignore: avoid_print
    print('  max_tokens: ${pd2['max_tokens']}');
    // ignore: avoid_print
    print('}');

    await client.auth.signOut();
  });
}
