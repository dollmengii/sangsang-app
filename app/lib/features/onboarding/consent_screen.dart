import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supabase.dart';
import 'profile_state.dart';

/// 친구용 버전의 짧은 개인정보 안내와 Gemini 무료 등급 동의 (기획서 "Gemini 무료 등급과 친구들에게 보낼 안내").
class ConsentScreen extends ConsumerStatefulWidget {
  const ConsentScreen({super.key});

  @override
  ConsumerState<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends ConsumerState<ConsentScreen> {
  bool _agreed = false;
  bool _busy = false;

  static const _notice =
      '이 버전은 친구들끼리 써 보는 테스트판이에요. 사진 분석에 구글 Gemini 무료 버전을 쓰는데, '
      '무료 버전에서는 보낸 사진과 결과가 구글의 서비스 개선에 쓰일 수 있고 구글 쪽 사람이 볼 수도 있어요. '
      '괜찮을 때만 올려 주세요. 테스트가 끝나면 앱에 올린 사진과 대화는 모두 지울게요.';

  Future<void> _submit() async {
    setState(() => _busy = true);
    final client = ref.read(supabaseProvider);
    try {
      await client
          .from('profiles')
          .update({'gemini_consent_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', client.auth.currentUser!.id);
      ref.invalidate(myProfileStateProvider);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('시작하기 전에')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('AI가 사진을 보고 첫인상 태그를 만들어요.', style: theme.textTheme.titleMedium),
          const SizedBox(height: 16),
          Text(_notice, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 16),
          Text('원본 사진은 다른 사람이 볼 수 없어요. 다른 사람에게는 아주 작게 줄인 흐린 무드 이미지만 보여요. '
              '얼굴은 두 사람이 모두 원할 때만 열려요.',
              style: theme.textTheme.bodyMedium),
          const SizedBox(height: 24),
          CheckboxListTile(
            value: _agreed,
            onChanged: (v) => setState(() => _agreed = v ?? false),
            title: const Text('위 내용을 읽었고 동의해요'),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _agreed && !_busy ? _submit : null,
            child: const Text('동의하고 계속'),
          ),
        ],
      ),
    );
  }
}
