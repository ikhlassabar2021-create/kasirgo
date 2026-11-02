import 'device_abi_stub.dart'
    if (dart.library.io) 'device_abi_io.dart' as impl;

/// Deteksi ABI perangkat Android: 'arm64', 'armeabi_v7a', 'x86_64', atau null.
/// Di web / platform non-Android mengembalikan null.
Future<String?> deviceAbi() => impl.deviceAbi();