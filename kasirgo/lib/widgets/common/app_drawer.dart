import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).valueOrNull;
    return Drawer(
      child: Container(
        decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
        child: SafeArea(
          child: Column(
            children: [
              DrawerHeader(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const CircleAvatar(radius: 30, backgroundColor: Colors.white24, child: Icon(Icons.person, size: 30, color: Colors.white)),
                    const SizedBox(height: 12),
                    Text(user?.email ?? '', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    Text(user?.businessName ?? '', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  ],
                ),
              ),
              ListTile(leading: const Icon(Icons.logout, color: Colors.white70), title: Text('Keluar', style: TextStyle(color: Colors.white)), onTap: () => ref.read(authStateProvider.notifier).signOut()),
            ],
          ),
        ),
      ),
    );
  }
}