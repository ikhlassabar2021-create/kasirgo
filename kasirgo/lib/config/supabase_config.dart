import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String url = 'https://lmvjecdvfzsmrowwwpck.supabase.co';
  static const String anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxtdmplY2R2ZnpzbXJvd3d3cGNrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODkxMjk3MjgsImV4cCI6MjEwNDcwNTcyOH0.6waUmz-Kj32gGuxBs4DutgBDQtsSljazTuJQw_qZstI';

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
    );
  }
}