import 'package:flutter/material.dart';
import '../../config/app_theme.dart';

class SupporterScreen extends StatelessWidget {
  const SupporterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Program Pendukung KasirGo'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.favorite, size: 48, color: Colors.amber),
              ),
              const SizedBox(height: 16),
              const Text(
                'Dukung Ekosistem KasirGo',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 8),
              const Text(
                'KasirGo gratis selamanya tanpa batasan fitur. Kontribusi sukarela membantu kelangsungan server dan kemajuan UMKM.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
