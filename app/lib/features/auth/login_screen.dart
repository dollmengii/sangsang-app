import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/theme.dart';
import '../../core/widgets/dusk_background.dart';
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
      _error = '아직 초대받지 않은 계정이에요.\n초대해 준 친구에게 이 구글 계정을 알려 주세요.';
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
    final t = Theme.of(context).textTheme;
    final c = AppColors.of(context);
    return Scaffold(
      body: DuskBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(flex: 3),
                Text('상상', style: t.displayLarge),
                const SizedBox(height: 18),
                Text('얼굴 말고, 상으로 먼저.', style: t.titleLarge?.copyWith(fontWeight: FontWeight.w400)),
                const SizedBox(height: 6),
                Text('얼굴은 둘 다 원할 때만 열려요.', style: t.bodyLarge?.copyWith(color: c.muted)),
                const Spacer(flex: 4),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _error == null
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Text(_error!,
                              textAlign: TextAlign.center,
                              style: t.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.error)),
                        ),
                ),
                FilledButton(
                  onPressed: _busy ? null : _signIn,
                  child: Text(_busy ? '들어가는 중…' : '구글로 시작하기'),
                ),
                const SizedBox(height: 14),
                Text('친구들끼리 써 보는 테스트판이에요.\n초대받은 계정만 들어올 수 있어요.',
                    style: t.bodySmall, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
