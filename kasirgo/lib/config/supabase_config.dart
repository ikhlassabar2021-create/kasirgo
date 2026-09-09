import 'package:supabase_flutter/supabase_flutter.dart';

const _supabaseUrl = 'https://gtwcrsqsbykttggflkzz.supabase.co';
const _supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd0d2Nyc3FzYnlrdHRnZ2Zsa3p6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODg4OTE0MTEsImV4cCI6MjEwNDQ2NzQxMX0._k8V3ca8CzogPa8zJipUCnhBysq-yK76qd1a1HwrK9k';

Future<Supabase> initializeSupabase() async {
  return Supabase.initialize(
    url: _supabaseUrl,
    anonKey: _supabaseAnonKey,
  );
}

SupabaseClient get supabase => Supabase.instance.client;