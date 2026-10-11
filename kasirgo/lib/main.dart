import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'config/supabase_config.dart';
import 'services/app_mode_service.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeDateFormatting('id_ID', null);
  await SupabaseConfig.initialize();
  await AppModeService().loadMode();

  runApp(
    const ProviderScope(
      child: KasirGoApp(),
    ),
  );
}
