import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

class KyCVerificationService {
  final SupabaseClient _supabase;
  static const String edgeFunctionUrl = 
      'https://your-project-id.supabase.co/functions/v1/verify_kyc_flutter';

  KyCVerificationService() : _supabase = Supabase.instance.client;

  Future<KYCVerificationResult> verifyKYC({
    required XFile ktpImage,
    required XFile selfieImage,
    required int outletId,
    required String nik,
  }) async {
    try {
      // Upload KTP image
      final ktpPath = await _uploadImage(ktpImage, 'ktp_');
      
      // Upload selfie image
      final selfiePath = await _uploadImage(selfieImage, 'selfie_');

      // Call Edge Function for verification
      final response = await http.post(
        Uri.parse(edgeFunctionUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'ktpPath': ktpPath,
          'selfiePath': selfiePath,
          'outletId': outletId,
          'userId': _supabase.auth.currentUser?.id,
          'nik': nik,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Verification failed: ${response.body}');
      }

      final result = jsonDecode(response.body);
      return KYCVerificationResult(
        verificationStatus: result['verification_status'],
        faceMatchScore: result['face_match_score'],
        message: result['message'],
        isAutoApproved: result['verification_status'] == 'verified',
      );

    } catch (e) {
      throw Exception('KYC verification error: $e');
    }
  }

  Future<String> _uploadImage(XFile image, String prefix) async {
    final userId = _supabase.auth.currentUser?.id ?? 'anonymous';
    final fileName = '${prefix}${DateTime.now().millisecondsSinceEpoch}.jpg';
    final filePath = 'kyc/$userId/$fileName';

    final bytes = await image.readAsBytes();
    
    try {
      await _supabase.storage
          .from('kyc-documents')
          .upload(filePath, bytes);
    } catch (e) {
      throw Exception('Failed to upload document: $e');
    }

    return filePath;
  }

  Future<List<KYCRecord>> getPendingKYCs() async {
    final result = await _supabase
        .from('outlet_kyc')
        .select('*')
        .eq('kyc_status', 'pending')
        .limit(50);

    return (result as List).map((data) => KYCRecord.fromMap(data)).toList();
  }

  Future<KYCVerificationStatus> checkKYCStatus(int outletId) async {
    final result = await _supabase
        .from('outlet_kyc')
        .select('kyc_status, verification_status, notes')
        .eq('outlet_id', outletId)
        .single();

    return KYCVerificationStatus(
      status: result['kyc_status'],
      verificationStatus: result['verification_status'],
      notes: result['notes'],
    );
  }
}

class KYCVerificationResult {
  final String verificationStatus;
  final int faceMatchScore;
  final String message;
  final bool isAutoApproved;

  KYCVerificationResult({
    required this.verificationStatus,
    required this.faceMatchScore,
    required this.message,
    required this.isAutoApproved,
  });

  bool get isVerified => verificationStatus == 'verified';
  bool get needsManualReview => verificationStatus == 'manual_review';
}

class KYCRecord {
  final int id;
  final String outletId;
  final String ownerNik;
  final String ownerFullName;
  final String ownerPhone;
  final String kycStatus;
  final String? ktpPath;
  final String? selfiePath;
  final int? faceMatchScore;
  final String verificationStatus;
  final DateTime? verifiedAt;
  final String? verifiedBy;
  final String? notes;

  KYCRecord({
    required this.id,
    required this.outletId,
    required this.ownerNik,
    required this.ownerFullName,
    required this.ownerPhone,
    required this.kycStatus,
    this.ktpPath,
    this.selfiePath,
    this.faceMatchScore,
    required this.verificationStatus,
    this.verifiedAt,
    this.verifiedBy,
    this.notes,
  });

  factory KYCRecord.fromMap(Map<dynamic, dynamic> data) {
    return KYCRecord(
      id: data['id'] as int,
      outletId: data['outlet_id'],
      ownerNik: data['owner_nik'],
      ownerFullName: data['owner_full_name'],
      ownerPhone: data['owner_phone'],
      kycStatus: data['kyc_status'],
      ktpPath: data['ktp_path'],
      selfiePath: data['selfie_path'],
      faceMatchScore: data['face_match_score'] as int?,
      verificationStatus: data['verification_status'],
      verifiedAt: data['verified_at'] != null 
          ? DateTime.parse(data['verified_at']) 
          : null,
      verifiedBy: data['verified_by'],
      notes: data['notes'],
    );
  }
}

class KYCVerificationStatus {
  final String status;
  final String verificationStatus;
  final String? notes;

  KYCVerificationStatus({
    required this.status,
    required this.verificationStatus,
    this.notes,
  });
}
