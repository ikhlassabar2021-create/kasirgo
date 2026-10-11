import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/outlet_location.dart';

/// ST17-1 (Phase 17 - Ekosistem Hyper-Local): layanan lokasi live & antrean.
/// nearby_outlets (peta Rp0), broadcast lokasi gerobak, antrean jasa.
class LocationService {
  LocationService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  // ---------------------------------------------------------------------------
  // PETA / NEARBY
  // ---------------------------------------------------------------------------

  /// Outlet terdekat dari koordinat pembeli (RPC publik, anon boleh).
  Future<List<NearbyOutlet>> nearbyOutlets({
    required double lat,
    required double lng,
    double? radiusKm,
  }) async {
    try {
      final res = await _client.rpc('nearby_outlets', params: {
        'p_lat': lat,
        'p_lng': lng,
        'p_radius_km': radiusKm,
      });
      return (res as List)
          .map((e) => NearbyOutlet.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      debugPrint('LocationService.nearbyOutlets error: $e');
      return [];
    }
  }

  /// Config hyperlocal (radius default/max, tile URL, iklan pembeli).
  Future<Map<String, dynamic>> loadConfig() async {
    try {
      final res = await _client
          .from('platform_configs')
          .select('value')
          .eq('key', 'hyperlocal')
          .eq('scope', 'global')
          .order('version', ascending: false)
          .limit(1)
          .maybeSingle();
      if (res != null && res['value'] is Map) {
        return Map<String, dynamic>.from(res['value'] as Map);
      }
    } catch (e) {
      debugPrint('LocationService.loadConfig error: $e');
    }
    return const {};
  }

  // ---------------------------------------------------------------------------
  // BROADCAST LOKASI (gerobak / ojol) - owner
  // ---------------------------------------------------------------------------

  /// Simpan/perbarui lokasi live outlet (upsert by outlet_id).
  Future<bool> updateOutletLocation({
    required String outletId,
    required double lat,
    required double lng,
  }) async {
    try {
      await _client.from('outlet_locations').upsert({
        'outlet_id': outletId,
        'latitude': lat,
        'longitude': lng,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'outlet_id');
      return true;
    } catch (e) {
      debugPrint('LocationService.updateOutletLocation error: $e');
      return false;
    }
  }

  /// Lokasi live outlet (publik bila outlet buka).
  Future<OutletLocation?> getOutletLocation(String outletId) async {
    try {
      final res = await _client
          .from('outlet_locations')
          .select()
          .eq('outlet_id', outletId)
          .maybeSingle();
      if (res == null) return null;
      return OutletLocation.fromJson(Map<String, dynamic>.from(res));
    } catch (e) {
      debugPrint('LocationService.getOutletLocation error: $e');
      return null;
    }
  }

  /// Pantau perubahan lokasi satu outlet via Realtime.
  Stream<OutletLocation> watchOutletLocation(String outletId) {
    return _client
        .from('outlet_locations')
        .stream(primaryKey: ['id'])
        .eq('outlet_id', outletId)
        .map((rows) {
      if (rows.isEmpty) {
        return OutletLocation(id: '', outletId: outletId, latitude: 0, longitude: 0);
      }
      return OutletLocation.fromJson(Map<String, dynamic>.from(rows.first));
    });
  }

  // ---------------------------------------------------------------------------
  // ANTREAN JASA (bengkel/cukur)
  // ---------------------------------------------------------------------------

  /// Daftar antrean outlet, opsional hanya status tertentu.
  Future<List<ServiceQueueEntry>> listQueue(
    String outletId, {
    String? status,
  }) async {
    try {
      var query = _client.from('service_queue').select().eq('outlet_id', outletId);
      if (status != null) query = query.eq('status', status);
      final res = await query.order('number', ascending: true);
      return (res as List)
          .map((e) =>
              ServiceQueueEntry.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      debugPrint('LocationService.listQueue error: $e');
      return [];
    }
  }

  /// Ambil nomor antrean berikutnya (pembeli).
  ///
  /// Memakai RPC atomik `take_queue_number` (SECURITY DEFINER) agar nomor unik
  /// walau banyak pembeli memanggil bersamaan; fallback ke insert langsung.
  Future<ServiceQueueEntry?> takeQueueNumber(String outletId) async {
    try {
      final res = await _client
          .rpc('take_queue_number', params: {'p_outlet': outletId});
      if (res is Map && res['success'] == true) {
        return ServiceQueueEntry(
          id: res['id']?.toString() ?? '',
          outletId: outletId,
          number: (res['number'] as num?)?.toInt() ?? 0,
          status: 'menunggu',
        );
      }
      if (res is Map && res['error'] != null) {
        debugPrint('LocationService.takeQueueNumber: ${res['error']}');
        return null;
      }
    } catch (e) {
      debugPrint('LocationService.takeQueueNumber RPC error: $e');
    }

    try {
      final existing = await listQueue(outletId);
      final nextNumber = existing.isEmpty
          ? 1
          : existing
                  .map((e) => e.number)
                  .reduce((a, b) => a > b ? a : b) +
              1;
      final res = await _client
          .from('service_queue')
          .insert({
            'outlet_id': outletId,
            'number': nextNumber,
            'status': 'menunggu',
          })
          .select()
          .single();
      return ServiceQueueEntry.fromJson(Map<String, dynamic>.from(res));
    } catch (e) {
      debugPrint('LocationService.takeQueueNumber error: $e');
      return null;
    }
  }

  /// Ubah status entri antrean (owner).
  Future<bool> setQueueStatus(String entryId, String status) async {
    try {
      await _client
          .from('service_queue')
          .update({'status': status})
          .eq('id', entryId);
      return true;
    } catch (e) {
      debugPrint('LocationService.setQueueStatus error: $e');
      return false;
    }
  }

  /// Pantau antrean outlet via Realtime.
  Stream<List<ServiceQueueEntry>> watchQueue(String outletId) {
    return _client
        .from('service_queue')
        .stream(primaryKey: ['id'])
        .eq('outlet_id', outletId)
        .map((rows) => rows
            .map((e) => ServiceQueueEntry.fromJson(Map<String, dynamic>.from(e)))
            .toList());
  }
}
