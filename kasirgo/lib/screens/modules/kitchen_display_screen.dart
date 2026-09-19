import 'package:flutter/material.dart';
import '../../config/app_theme.dart';

class KitchenDisplayScreen extends StatelessWidget {
  const KitchenDisplayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kitchen Display System (KDS)'),
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
                  color: AppTheme.secondaryColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.kitchen, size: 48, color: AppTheme.secondaryColor),
              ),
              const SizedBox(height: 16),
              const Text(
                'Layar Pesanan Dapur',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 8),
              const Text(
                'Monitor tiket antrean pesanan masak dan update status siap saji secara real-time.',
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
