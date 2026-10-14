import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'auth_repository.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _signIn() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).signInWithGoogle();
    } on NotInvitedException {
      _error = '아직 초대받지 않은 계정이에요. 초대해 준 친구에게 이 구글 계정을 알려 주세요.';
    } on GoogleSignInException catch (e) {
      if (e.code != GoogleSignInExceptionCode.canceled) _error = '구글 로그인에 실패했어요.';
    } catch (_) {
      _error = '로그인에 실패했어요. 잠시 뒤 다시 해 주세요.';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Text('상상', style: theme.textTheme.displaySmall),
              const SizedBox(height: 12),
              Text('얼굴 말고 상(相)으로 먼저 만나는 소개팅.\n얼굴은 둘 다 원할 때만.',
                  style: theme.textTheme.titleMedium),
              const Spacer(),
              if (_error != null) ...[
                Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                const SizedBox(height: 12),
              ],
              FilledButton(
                onPressed: _busy ? null : _signIn,
                child: Text(_busy ? '로그인하는 중…' : '구글로 시작하기'),
              ),
              const SizedBox(height: 8),
              Text('친구용 테스트판이에요. 초대받은 계정만 들어올 수 있어요.',
                  style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
