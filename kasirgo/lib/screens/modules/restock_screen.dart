import 'package:flutter/material.dart';
import '../../config/app_theme.dart';

class RestockScreen extends StatelessWidget {
  const RestockScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kulakan B2B (Restock)'),
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
                  color: AppTheme.successColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.local_shipping, size: 48, color: AppTheme.successColor),
              ),
              const SizedBox(height: 16),
              const Text(
                'Pasar Kulakan B2B Grosir',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 8),
              const Text(
                'Restock stok barang langsung dari distributor utama dengan harga grosir kompetitif.',
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
