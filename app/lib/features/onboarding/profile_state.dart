import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supabase.dart';

/// 가입 단계 판단에 필요한 내 프로필 일부.
class MyProfileState {
  const MyProfileState({required this.geminiConsented, required this.onboarded});

  final bool geminiConsented;
  final bool onboarded;
}

final myProfileStateProvider = FutureProvider<MyProfileState?>((ref) async {
  final session = ref.watch(sessionProvider).value;
  if (session == null) return null;
  final row = await ref
      .watch(supabaseProvider)
      .from('profiles')
      .select('gemini_consent_at, onboarded_at')
      .eq('id', session.user.id)
      .single();
  return MyProfileState(
    geminiConsented: row['gemini_consent_at'] != null,
    onboarded: row['onboarded_at'] != null,
  );
});
