// Conditional import: native sqlite3 on mobile, no-op stub on web.
export 'local_db_service_stub.dart'
    if (dart.library.ffi) 'local_db_service_native.dart';
