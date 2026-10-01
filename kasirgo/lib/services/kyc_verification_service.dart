import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Status verifikasi KYC outlet.
/// Alur: unsubmitted -> draft -> pending_review -> verified / rejected.
enum KycStatus { unsubmitted, draft, pendingReview, verified, rejected }

extension KycStatusX on KycStatus {
  String get dbValue => switch (this) {
        KycStatus.unsubmitted => 'unsubmitted',
        KycStatus.draft => 'draft',
        KycStatus.pendingReview => 'pending_review',
        KycStatus.verified => 'verified',
        KycStatus.rejected => 'rejected',
      };

  String get label => switch (this) {
        KycStatus.unsubmitted => 'Belum diisi',
        KycStatus.draft => 'Draf tersimpan',
        KycStatus.pendingReview => 'Sedang ditinjau',
        KycStatus.verified => 'Terverifikasi',
        KycStatus.rejected => 'Ditolak',
      };

  bool get isVerified => this == KycStatus.verified;

  bool get isBlocked =>
      this == KycStatus.unsubmitted ||
      this == KycStatus.draft ||
      this == KycStatus.pendingReview ||
      this == KycStatus.rejected;
}

KycStatus kycStatusFromDb(String? value) {
  return switch (value) {
    'verified' => KycStatus.verified,
    'rejected' => KycStatus.rejected,
    'pending_review' || 'pending' => KycStatus.pendingReview,
    'draft' => KycStatus.draft,
    _ => KycStatus.unsubmitted,
  };
}

class KycRecord {
  final String outletId;
  final String? fullName;
  final String? phone;
  final String? email;
  final String? storeName;
  final String? storeAddress;
  final String? ktpImagePath;
  final String? selfieKtpImagePath;
  final KycStatus status;
  final bool autoVerified;
  final String? rejectReason;
  final DateTime? verifiedAt;

  const KycRecord({
    required this.outletId,
    this.fullName,
    this.phone,
    this.email,
    this.storeName,
    this.storeAddress,
    this.ktpImagePath,
    this.selfieKtpImagePath,
    required this.status,
    this.autoVerified = false,
    this.rejectReason,
    this.verifiedAt,
  });

  factory KycRecord.fromMap(Map<String, dynamic> map) {
    return KycRecord(
      outletId: map['outlet_id']?.toString() ?? '',
      fullName: map['full_name'] as String?,
      phone: map['phone'] as String?,
      email: map['email'] as String?,
      storeName: map['store_name'] as String?,
      storeAddress: map['store_address'] as String?,
      ktpImagePath: map['ktp_image_path'] as String?,
      selfieKtpImagePath: map['selfie_ktp_image_path'] as String?,
      status: kycStatusFromDb(map['status'] as String?),
      autoVerified: map['auto_verified'] == true,
      rejectReason: map['reject_reason'] as String?,
      verifiedAt:
          map['verified_at'] != null ? DateTime.tryParse(map['verified_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toDraftJson() => {
        'outlet_id': outletId,
        'full_name': fullName,
        'phone': phone,
        'email': email,
        'store_name': storeName,
        'store_address': storeAddress,
        'ktp_image_path': ktpImagePath,
        'selfie_ktp_image_path': selfieKtpImagePath,
      };

  factory KycRecord.fromDraftJson(Map<String, dynamic> map) => KycRecord(
        outletId: map['outlet_id']?.toString() ?? '',
        fullName: map['full_name'] as String?,
        phone: map['phone'] as String?,
        email: map['email'] as String?,
        storeName: map['store_name'] as String?,
        storeAddress: map['store_address'] as String?,
        ktpImagePath: map['ktp_image_path'] as String?,
        selfieKtpImagePath: map['selfie_ktp_image_path'] as String?,
        status: KycStatus.draft,
      );
}

class KycSubmitResult {
  final KycStatus status;
  final bool autoVerified;
  final String message;
  final bool savedOffline;
  final String? errorCode;

  const KycSubmitResult({
    required this.status,
    required this.autoVerified,
    required this.message,
    this.savedOffline = false,
    this.errorCode,
  });

  bool get isVerified => status == KycStatus.verified;
  bool get duplicate => errorCode == 'duplicate_nik' || errorCode == 'duplicate_phone';
}

/// Servis KYC (foto LOKAL, server hanya menyimpan status + field teks).
///
/// Auto-verify + anti-duplikat dijalankan di server via RPC `submit_kyc`.
/// Bila offline, data disimpan sebagai draf lokal dan dikirim saat online.
class KycService {
  final SupabaseClient _supabase;
  KycService({SupabaseClient? client}) : _supabase = client ?? Supabase.instance.client;

  static const Duration _freshWindow = Duration(minutes: 5);

  String _statusKey(String outletId) => 'kyc_status_$outletId';
  String _checkedKey(String outletId) => 'kyc_checked_$outletId';
  String _draftKey(String outletId) => 'kyc_draft_$outletId';

  Future<bool> _online() async {
    try {
      final r = await Connectivity().checkConnectivity();
      return r.isNotEmpty && !r.contains(ConnectivityResult.none);
    } catch (_) {
      return true;
    }
  }

  /// Status KYC dari cache (sinkron, offline-safe). Default unsubmitted.
  Future<KycStatus> cachedStatus(String outletId) async {
    if (outletId.isEmpty) return KycStatus.unsubmitted;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_draftKey(outletId)) != null) {
      final s = prefs.getString(_statusKey(outletId));
      if (s == null || kycStatusFromDb(s) == KycStatus.unsubmitted) {
        return KycStatus.draft;
      }
    }
    return kycStatusFromDb(prefs.getString(_statusKey(outletId)));
  }

  Future<bool> isVerified(String outletId) async {
    final cached = await cachedStatus(outletId);
    if (cached.isVerified) return true;
    final record = await fetchRecord(outletId);
    return record?.status.isVerified ?? false;
  }

  /// Ambil record dari server; perbarui cache. null bila belum ada / offline.
  Future<KycRecord?> fetchRecord(String outletId) async {
    if (outletId.isEmpty) return null;
    try {
      final data = await _supabase
          .from('outlet_kyc')
          .select()
          .eq('outlet_id', outletId)
          .maybeSingle();
      if (data == null) {
        // RLS `outlet_kyc` hanya membuka baris penuh ke owner. Staf (admin/kasir)
        // mendapat 0 baris walau outlet sudah verified. Ambil status lewat RPC
        // khusus (tanpa PII) agar gate tidak salah memblokir.
        final status = await _fetchStatusViaRpc(outletId);
        await _setCache(outletId, status);
        if (status == KycStatus.verified) {
          return KycRecord(outletId: outletId, status: status);
        }
        return null;
      }
      final record = KycRecord.fromMap(data);
      await _setCache(outletId, record.status);
      if (record.status.isVerified ||
          record.status == KycStatus.rejected ||
          record.status == KycStatus.pendingReview) {
        await clearDraft(outletId);
      }
      return record;
    } catch (_) {
      return null;
    }
  }

  /// Status KYC via RPC aman (tanpa PII) untuk staf. Default unsubmitted.
  Future<KycStatus> _fetchStatusViaRpc(String outletId) async {
    try {
      final res = await _supabase
          .rpc('get_outlet_kyc_status', params: {'p_outlet': outletId});
      return kycStatusFromDb(res as String?);
    } catch (_) {
      return KycStatus.unsubmitted;
    }
  }

  /// Refresh cache bila sudah kedaluwarsa.
  Future<bool> refreshIfStale(String outletId) async {
    if (outletId.isEmpty) return false;
    final prefs = await SharedPreferences.getInstance();
    final checked = int.tryParse(prefs.getString(_checkedKey(outletId)) ?? '') ?? 0;
    final age = DateTime.now().millisecondsSinceEpoch - checked;
    if (checked != 0 && age < _freshWindow.inMilliseconds) {
      return (await cachedStatus(outletId)).isVerified;
    }
    final record = await fetchRecord(outletId);
    return record?.status.isVerified ?? (await cachedStatus(outletId)).isVerified;
  }

  Future<void> _setCache(String outletId, KycStatus status) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_statusKey(outletId), status.dbValue);
    await prefs.setString(
        _checkedKey(outletId), DateTime.now().millisecondsSinceEpoch.toString());
  }

  // ---------------------------------------------------------------------------
  // DRAF lokal
  // ---------------------------------------------------------------------------
  Future<void> saveDraft(KycRecord record) async {
    if (record.outletId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_draftKey(record.outletId), jsonEncode(record.toDraftJson()));
    await prefs.setString(_statusKey(record.outletId), KycStatus.draft.dbValue);
  }

  Future<KycRecord?> loadDraft(String outletId) async {
    if (outletId.isEmpty) return null;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_draftKey(outletId));
    if (raw == null) return null;
    try {
      return KycRecord.fromDraftJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearDraft(String outletId) async {
    if (outletId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_draftKey(outletId));
  }

  // ---------------------------------------------------------------------------
  // Kirim verifikasi
  // ---------------------------------------------------------------------------
  Future<KycSubmitResult> submit({
    required String outletId,
    required String fullName,
    required String phone,
    required String email,
    required String storeName,
    required String storeAddress,
    required String? ktpImagePath,
    required String? selfieKtpImagePath,
    String? nik,
    bool consent = false,
  }) async {
    final draft = KycRecord(
      outletId: outletId,
      fullName: fullName,
      phone: phone,
      email: email,
      storeName: storeName,
      storeAddress: storeAddress,
      ktpImagePath: ktpImagePath,
      selfieKtpImagePath: selfieKtpImagePath,
      status: KycStatus.draft,
    );

    if (!await _online()) {
      await saveDraft(draft);
      return const KycSubmitResult(
        status: KycStatus.draft,
        autoVerified: false,
        message: 'Tidak ada internet. Data disimpan sebagai draf dan akan dikirim saat online.',
        savedOffline: true,
      );
    }

    try {
      final res = await _supabase.rpc('submit_kyc', params: {
        'p_outlet': outletId,
        'p_full_name': fullName,
        'p_phone': phone,
        'p_email': email,
        'p_store_name': storeName,
        'p_store_address': storeAddress,
        'p_ktp_path': ktpImagePath,
        'p_selfie_path': selfieKtpImagePath,
        'p_nik': nik,
        'p_consent': consent,
      });

      final map = (res as Map).cast<String, dynamic>();
      final status = kycStatusFromDb(map['status'] as String?);
      await _setCache(outletId, status);
      if (status.isVerified || status == KycStatus.pendingReview) {
        await clearDraft(outletId);
      }
      return KycSubmitResult(
        status: status,
        autoVerified: map['auto_verified'] == true,
        message: map['message'] as String? ?? 'Selesai',
      );
    } on PostgrestException catch (e) {
      final code = _mapError(e.message);
      switch (code) {
        case 'duplicate_nik':
          return const KycSubmitResult(
            status: KycStatus.unsubmitted,
            autoVerified: false,
            message: 'NIK ini sudah terdaftar pada outlet lain.',
            errorCode: 'duplicate_nik',
          );
        case 'duplicate_phone':
          return const KycSubmitResult(
            status: KycStatus.unsubmitted,
            autoVerified: false,
            message: 'Nomor HP ini sudah terdaftar pada outlet lain.',
            errorCode: 'duplicate_phone',
          );
        case 'email_unverified':
          return const KycSubmitResult(
            status: KycStatus.draft,
            autoVerified: false,
            message:
                'Email Anda belum terverifikasi. Buka email dan klik tautan verifikasi dari KasirGo, lalu kirim ulang KYC.',
            errorCode: 'email_unverified',
          );
        case 'invalid_nik':
          return const KycSubmitResult(
            status: KycStatus.draft,
            autoVerified: false,
            message:
                'NIK tidak valid. Harus 16 digit dengan kode provinsi dan tanggal lahir yang benar.',
            errorCode: 'invalid_nik',
          );
        case 'invalid_phone':
          return const KycSubmitResult(
            status: KycStatus.draft,
            autoVerified: false,
            message: 'Nomor HP tidak valid. Contoh: 081234567890.',
            errorCode: 'invalid_phone',
          );
        case 'not_owner':
          return const KycSubmitResult(
            status: KycStatus.draft,
            autoVerified: false,
            message: 'Hanya pemilik outlet yang boleh mengirim KYC.',
            errorCode: 'not_owner',
          );
      }
      return KycSubmitResult(
        status: KycStatus.draft,
        autoVerified: false,
        message: 'Gagal mengirim verifikasi: ${e.message}',
        errorCode: 'submit_failed',
      );
    } catch (e) {
      await saveDraft(draft);
      return KycSubmitResult(
        status: KycStatus.draft,
        autoVerified: false,
        message: 'Gagal terhubung. Data disimpan sebagai draf: $e',
        savedOffline: true,
        errorCode: 'network',
      );
    }
  }

  String? _mapError(String message) {
    for (final code in [
      'duplicate_nik',
      'duplicate_phone',
      'email_unverified',
      'invalid_nik',
      'invalid_phone',
      'not_owner',
    ]) {
      if (message.contains(code)) return code;
    }
    return null;
  }
}
