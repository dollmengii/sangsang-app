import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabaseProvider = Provider<SupabaseClient>((ref) => Supabase.instance.client);

/// 로그인 상태가 바뀔 때마다 새 세션을 내보낸다.
final sessionProvider = StreamProvider<Session?>((ref) {
  final auth = ref.watch(supabaseProvider).auth;
  return auth.onAuthStateChange
      .map((event) => event.session)
      .startWithValue(auth.currentSession);
});

extension<T> on Stream<T> {
  Stream<T> startWithValue(T value) async* {
    yield value;
    yield* this;
  }
}
