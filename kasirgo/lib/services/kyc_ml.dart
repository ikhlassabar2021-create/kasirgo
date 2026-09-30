/// Facade OCR & face detection untuk KYC.
/// Native (Android/iOS) memakai Google ML Kit (GRATIS, on-device);
/// web memakai stub (kembalikan kosong -> fallback input manual).
library;

export 'kyc_ml_stub.dart' if (dart.library.io) 'kyc_ml_io.dart';
