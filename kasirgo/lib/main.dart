import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'config/supabase_config.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await initializeSupabase();
  } catch (e) {
    runApp(MaterialApp(
      home: Scaffold(
        backgroundColor: const Color(0xFF0F0B1E),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off, color: Colors.redAccent, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Gagal terhubung ke server',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  '${e.toString().substring(0, e.toString().length > 200 ? 200 : e.toString().length)}',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    ));
    return;
  }

  runApp(const ProviderScope(child: KasirGoApp()));
}