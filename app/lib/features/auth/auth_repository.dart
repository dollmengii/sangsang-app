import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/env.dart';
import '../../core/supabase.dart';

/// 초대 목록에 없는 구글 계정이면 서버가 가입을 막는다 (handle_new_user).
class NotInvitedException implements Exception {}

class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;
  bool _googleReady = false;

  Future<void> signInWithGoogle() async {
    final google = GoogleSignIn.instance;
    if (!_googleReady) {
      await google.initialize(serverClientId: Env.googleWebClientId);
      _googleReady = true;
    }
    final account = await google.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw const AuthException('구글에서 로그인 토큰을 받지 못했어요.');
    }
    try {
      await _client.auth.signInWithIdToken(provider: OAuthProvider.google, idToken: idToken);
    } on AuthException catch (e) {
      if (e.message.contains('not_invited') || e.message.contains('Database error saving new user')) {
        await google.signOut();
        throw NotInvitedException();
      }
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
    if (_googleReady) await GoogleSignIn.instance.signOut();
  }
}

final authRepositoryProvider =
    Provider<AuthRepository>((ref) => AuthRepository(ref.watch(supabaseProvider)));
