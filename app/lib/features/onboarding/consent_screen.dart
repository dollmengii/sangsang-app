import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supabase.dart';
import '../../core/theme.dart';
import '../../core/widgets/section_title.dart';
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
    final t = Theme.of(context).textTheme;
    final c = AppColors.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
                children: [
                  const SectionTitle(title: '시작하기 전에', caption: '세 가지만 알고 시작해요.'),
                  const SizedBox(height: 28),
                  _Point(
                    number: '하나',
                    title: '원본 사진은 아무도 못 봐요',
                    body: '다른 사람에게는 아주 작게 줄여 흐리게 만든 무드 이미지만 보여요.',
                  ),
                  _Point(
                    number: '둘',
                    title: '얼굴은 둘 다 원할 때만',
                    body: '대화를 충분히 나눈 뒤, 두 사람이 모두 동의하면 같은 순간에 열려요.',
                  ),
                  _Point(
                    number: '셋',
                    title: 'AI가 사진 속 첫인상을 읽어요',
                    body: _notice,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 24, 16),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: c.line))),
              child: Column(
                children: [
                  CheckboxListTile(
                    value: _agreed,
                    onChanged: (v) => setState(() => _agreed = v ?? false),
                    title: Text('읽었고, 동의해요', style: t.bodyLarge),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: FilledButton(
                      onPressed: _agreed && !_busy ? _submit : null,
                      child: const Text('계속'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Point extends StatelessWidget {
  const _Point({required this.number, required this.title, required this.body});

  final String number;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(number, style: t.labelLarge?.copyWith(color: c.rose)),
          const SizedBox(height: 4),
          Text(title, style: t.titleLarge),
          const SizedBox(height: 6),
          Text(body, style: t.bodyMedium?.copyWith(color: c.muted)),
        ],
      ),
    );
  }
}
