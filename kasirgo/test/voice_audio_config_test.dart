import 'package:flutter_test/flutter_test.dart';
import 'package:kasirgo/services/voice_service.dart';

void main() {
  group('VoiceAudioConfig', () {
    test('default semua sub-opsi aktif', () {
      const c = VoiceAudioConfig();
      expect(c.aktif, isTrue);
      expect(c.sapaanAwal, isTrue);
      expect(c.fullVoiceLoop, isTrue);
      expect(c.apelPagi, isTrue);
      expect(c.teguranResep, isTrue);
      expect(c.soundboxPos, isTrue);
      expect(c.shopFloor, isTrue);
    });

    test('membaca enam sub-opsi dari map', () {
      final c = VoiceAudioConfig.fromMap({
        'aktif': false,
        'sapaan_awal': false,
        'full_voice_loop': false,
        'apel_pagi': false,
        'teguran_resep': false,
        'soundbox_pos': false,
        'shop_floor': false,
      });
      expect(c.aktif, isFalse);
      expect(c.sapaanAwal, isFalse);
      expect(c.fullVoiceLoop, isFalse);
      expect(c.apelPagi, isFalse);
      expect(c.teguranResep, isFalse);
      expect(c.soundboxPos, isFalse);
      expect(c.shopFloor, isFalse);
    });

    test('kunci lama teguran tetap terbaca sebagai teguran_resep', () {
      final c = VoiceAudioConfig.fromMap({'teguran': false});
      expect(c.teguranResep, isFalse);
    });

    test('preferensi outlet menimpa global per field', () {
      const global = VoiceAudioConfig(soundboxPos: true, shopFloor: true);
      final merged = global.overrideWith({
        'aktif': false,
        'soundbox_pos': false,
      });
      expect(merged.aktif, isFalse);
      expect(merged.soundboxPos, isFalse);
      expect(merged.shopFloor, isTrue);
    });
  });
}
