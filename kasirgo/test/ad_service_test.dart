import 'package:flutter_test/flutter_test.dart';
import 'package:kasirgo/services/ad_service.dart';

void main() {
  group('SponsorAd.fromJson (Control Plane creatives)', () {
    test('membaca banner lokal base64 + mime jadi data URI', () {
      final ad = SponsorAd.fromJson({
        'id': 'ad_1',
        'title': 'Promo Kopi',
        'cta_label': 'Order',
        'target_url': 'https://wa.me/6281',
        'image_base64': 'AAAA',
        'image_mime': 'image/webp',
        'media_type': 'image',
      });
      expect(ad.title, 'Promo Kopi');
      expect(ad.ctaLabel, 'Order');
      expect(ad.url, 'https://wa.me/6281');
      expect(ad.hasImage, isTrue);
      expect(ad.imageSrc, 'data:image/webp;base64,AAAA');
    });

    test('URL gambar penuh dipakai apa adanya (tanpa data URI)', () {
      final ad = SponsorAd.fromJson({
        'title': 'Banner',
        'image_base64': 'https://cdn.example.com/banner.png',
      });
      expect(ad.imageSrc, 'https://cdn.example.com/banner.png');
    });

    test('default mime image/png bila tidak diisi', () {
      final ad = SponsorAd.fromJson({'title': 'x', 'banner': 'ZZZ'});
      expect(ad.imageSrc, 'data:image/png;base64,ZZZ');
    });

    test('membaca kode HTML/script embed', () {
      final ad = SponsorAd.fromJson({
        'title': 'Embed',
        'html_code': '<div></div>',
        'script_code': '<script></script>',
      });
      expect(ad.htmlCode, '<div></div>');
      expect(ad.scriptCode, '<script></script>');
      expect(ad.hasImage, isFalse);
    });
  });

  group('AdService.filterBlocked', () {
    test('membuang entri dengan kategori terblokir (hard + kustom)', () {
      final raw = <Map<String, dynamic>>[
        {'title': 'Minuman', 'category': 'makanan'},
        {'title': 'Slot', 'category': 'pinjol'},
        {'title': 'Konten', 'category': 'dewasa'},
      ];
      final out = AdService.filterBlocked(raw, ['dewasa']);
      expect(out.length, 1);
      expect(out.first['title'], 'Minuman');
    });
  });
}