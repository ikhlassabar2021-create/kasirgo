import 'package:flutter_test/flutter_test.dart';
import 'package:kasirgo/config/supabase_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('CLEANUP: hapus aset dm hasil repro', () async {
    SharedPreferences.setMockInitialValues({});
    final client = SupabaseClient(SupabaseConfig.url, SupabaseConfig.anonKey);
    await client.auth.signInWithPassword(
        email: 'superadmin@kasirgo.com', password: 'sabar2021');
    const outlet = '229c94d7-ce6d-4be1-98f5-448f600528cc';
    final before = await client
        .from('dm_assets')
        .select('id, title')
        .eq('outlet_id', outlet);
    // ignore: avoid_print
    print('dm_assets sebelum cleanup: ${(before as List).length}');
    for (final a in before) {
      // ignore: avoid_print
      print('  hapus: ${a['title']}');
    }
    await client.from('dm_assets').delete().eq('outlet_id', outlet);
    final after = await client
        .from('dm_assets')
        .select('id')
        .eq('outlet_id', outlet);
    // ignore: avoid_print
    print('dm_assets sesudah cleanup: ${(after as List).length}');
    await client.auth.signOut();
  });
}
