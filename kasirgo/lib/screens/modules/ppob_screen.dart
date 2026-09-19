import 'package:flutter/material.dart';
import '../../config/app_theme.dart';

class PpobScreen extends StatelessWidget {
  const PpobScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PPOB & Pulsa'),
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
                  color: AppTheme.accentColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.phone_android, size: 48, color: AppTheme.accentColor),
              ),
              const SizedBox(height: 16),
              const Text(
                'Layanan Digital PPOB',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 8),
              const Text(
                'Jual pulsa, paket data, token PLN, dan top-up e-wallet langsung dari kasir warung.',
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
