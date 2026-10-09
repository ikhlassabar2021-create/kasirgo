import 'package:flutter_test/flutter_test.dart';
import 'package:kasirgo/screens/owner/ads_studio_screen.dart';

void main() {
  group('computeAdMetrics', () {
    test('menghitung CTR/CPC/ROAS dengan benar', () {
      final m = computeAdMetrics({
        'impressions': 1000,
        'clicks': 40,
        'spend': 50000,
        'revenue': 150000,
      });
      expect(m['ctr'], 4.0);
      expect(m['cpc'], 1250.0);
      expect(m['roas'], 3.0);
    });

    test('aman saat pembagi nol', () {
      final m = computeAdMetrics({
        'impressions': 0,
        'clicks': 0,
        'spend': 0,
        'revenue': 0,
      });
      expect(m['ctr'], 0);
      expect(m['cpc'], 0);
      expect(m['roas'], 0);
    });

    test('membulatkan dua desimal', () {
      final m = computeAdMetrics({
        'impressions': 300,
        'clicks': 10,
        'spend': 7500,
        'revenue': 10000,
      });
      expect(m['ctr'], 3.33);
      expect(m['cpc'], 750.0);
      expect(m['roas'], 1.33);
    });
  });
}
