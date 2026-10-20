import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/voice_service.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final authStateProvider = StreamProvider<User?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges.map((state) async {
    if (state.session != null) {
      return await authService.getCurrentUser();
    }
    return null;
  }).asyncMap((user) async => await user);
});

final currentUserProvider = StateNotifierProvider<CurrentUserNotifier, User?>((ref) {
  return CurrentUserNotifier(ref.watch(authServiceProvider));
});

class CurrentUserNotifier extends StateNotifier<User?> {
  final AuthService _authService;

  CurrentUserNotifier(this._authService) : super(null);

  Future<void> loadUser() async {
    final user = await _authService.getCurrentUser();
    state = user;
    _primeVoice(user);
  }

  void setUserDirectly(User user) {
    state = user;
    _primeVoice(user);
  }

  /// Siapkan suara interaktif (master switch + soundbox) untuk outlet aktif.
  void _primeVoice(User? user) {
    final outletId = user?.outletId;
    if (outletId == null || outletId.isEmpty) return;
    VoiceService().init(outletId: outletId);
  }

  Future<void> signOut() async {
    await _authService.signOut();
    state = null;
  }
}