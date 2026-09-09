import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user.dart';
import '../services/auth_service.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final authStateProvider = StateNotifierProvider<AuthStateNotifier, AsyncValue<AppUser?>>((ref) {
  return AuthStateNotifier(ref.read(authServiceProvider));
});

class AuthStateNotifier extends StateNotifier<AsyncValue<AppUser?>> {
  final AuthService _authService;

  AuthStateNotifier(this._authService) : super(const AsyncValue.loading()) {
    _init();
  }

  void _init() {
    final user = _authService.currentUser;
    state = AsyncValue.data(user);

    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      if (session != null) {
        state = AsyncValue.data(AppUser.fromJson(session.user.toJson()));
      } else {
        state = const AsyncValue.data(null);
      }
    });
  }

  Future<void> signIn(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final user = await _authService.signIn(email, password);
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> signUp(String email, String password, String businessName, String businessType) async {
    state = const AsyncValue.loading();
    try {
      final user = await _authService.signUp(email, password, businessName, businessType);
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
    state = const AsyncValue.data(null);
  }
}

final userRoleProvider = FutureProvider<String?>((ref) async {
  final authService = ref.read(authServiceProvider);
  return authService.getUserRole();
});

final userOutletIdProvider = FutureProvider<String?>((ref) async {
  final authService = ref.read(authServiceProvider);
  return authService.getUserOutletId();
});