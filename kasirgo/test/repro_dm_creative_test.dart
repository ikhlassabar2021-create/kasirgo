import 'package:flutter_test/flutter_test.dart';
import 'package:kasirgo/config/supabase_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('REPRO: dm_creative response for copy + video', () async {
    SharedPreferences.setMockInitialValues({});
    final client = SupabaseClient(SupabaseConfig.url, SupabaseConfig.anonKey);
    await client.auth.signInWithPassword(
        email: 'ikhlassabar2021@gmail.com', password: 'sabar2021');
    const outlet = '229c94d7-ce6d-4be1-98f5-448f600528cc';

    // 1. Copy
    try {
      final res = await client.functions.invoke('dm_creative', body: {
        'mode': 'generate',
        'outlet_id': outlet,
        'brief': 'promo akhir bulan diskon kopi susu 20 persen',
        'tone': 'ramah',
        'goal': 'meningkatkan penjualan',
      });
      // ignore: avoid_print
      print('=== COPY RESPONSE ===');
      // ignore: avoid_print
      print(res.data);
    } catch (e) {
      // ignore: avoid_print
      print('=== COPY ERROR === $e');
    }

    // 2. Video
    try {
      final res = await client.functions.invoke('dm_creative', body: {
        'mode': 'generate',
        'kind': 'video',
        'outlet_id': outlet,
        'brief': 'promo akhir bulan diskon kopi susu 20 persen',
        'tone': 'ramah',
        'duration': 20,
      });
      // ignore: avoid_print
      print('=== VIDEO RESPONSE ===');
      // ignore: avoid_print
      print(res.data);
    } catch (e) {
      // ignore: avoid_print
      print('=== VIDEO ERROR === $e');
    }

    await client.auth.signOut();
  });
}
