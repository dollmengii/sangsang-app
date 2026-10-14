import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme.dart';
import '../../core/widgets/section_title.dart';
import '../chat/chat_repository.dart';
import '../home/me_screen.dart';
import 'cards_repository.dart';
import 'profile_card_view.dart';

/// 오늘의 카드 (기획서 3장, 6장). 매일 밤 10시에 8장. 태그로 거르기는 넣지 않는다.
class CardsScreen extends ConsumerWidget {
  const CardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cards = ref.watch(todayCardsProvider);
    final t = Theme.of(context).textTheme;
    final c = AppColors.of(context);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.refresh(todayCardsProvider.future),
          child: cards.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => ListView(children: [
              const SizedBox(height: 200),
              Center(
                child: TextButton(
                  onPressed: () => ref.invalidate(todayCardsProvider),
                  child: const Text('카드를 불러오지 못했어요. 눌러서 다시 시도'),
                ),
              ),
            ]),
            data: (list) {
              final waiting = list.where((x) => x.liked == null).toList();
              final done = list.length - waiting.length;
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 32, 20, 40),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: SectionTitle(
                      title: '오늘의 카드',
                      caption: list.isEmpty
                          ? null
                          : '${list.length}장 중 $done장을 봤어요. 태그와 글만 보고 골라요.',
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (list.isEmpty)
                    _Empty(text: '오늘 밤 10시,\n첫 카드가 도착해요.')
                  else if (waiting.isEmpty)
                    _Empty(text: '오늘 카드는 다 봤어요.\n내일 밤 10시에 새 카드가 와요.')
                  else
                    for (final card in waiting) ...[
                      ProfileCardView(card: card, footer: _Actions(card: card)),
                      const SizedBox(height: 20),
                    ],
                  if (list.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      icon: Icon(Icons.add, color: c.rose),
                      label: const Text('크레딧 3개로 4장 더 보기'),
                      onPressed: () => _buyExtra(context, ref),
                    ),
                    const SizedBox(height: 8),
                    Text('얼굴로 순위를 매기지 않아요. 모두 비슷한 횟수로 카드에 나와요.',
                        textAlign: TextAlign.center, style: t.bodySmall),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _buyExtra(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(cardsRepositoryProvider).buyExtra();
      ref.invalidate(todayCardsProvider);
      ref.invalidate(myCreditBalanceProvider);
    } on PostgrestException catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text(switch (e.message) {
          'no_more_cards' => '지금은 더 보여줄 사람이 없어요. 크레딧은 그대로예요.',
          'insufficient_credits' => '크레딧이 모자라요.',
          _ => '카드를 더 받지 못했어요.',
        }),
      ));
    }
  }
}

class _Actions extends ConsumerStatefulWidget {
  const _Actions({required this.card});

  final ProfileCard card;

  @override
  ConsumerState<_Actions> createState() => _ActionsState();
}

class _ActionsState extends ConsumerState<_Actions> {
  bool _busy = false;

  Future<void> _respond(bool like) async {
    String? comment;
    if (like && widget.card.qa.isNotEmpty) {
      comment = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        builder: (_) => _CommentSheet(question: widget.card.qa.first.$1),
      );
      if (comment == null) return; // 닫으면 취소
    }
    setState(() => _busy = true);
    try {
      await ref.read(cardsRepositoryProvider).respond(widget.card.id, like: like, comment: comment);
      ref.invalidate(todayCardsProvider);
      ref.invalidate(myMatchesProvider);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
        child: OutlinedButton(onPressed: _busy ? null : () => _respond(false), child: const Text('넘기기')),
      ),
      const SizedBox(width: 12),
      Expanded(
        flex: 2,
        child: FilledButton.icon(
          onPressed: _busy ? null : () => _respond(true),
          icon: const Icon(Icons.favorite_border, size: 20),
          label: const Text('좋아요'),
        ),
      ),
    ]);
  }
}

class _CommentSheet extends StatefulWidget {
  const _CommentSheet({required this.question});

  final String question;

  @override
  State<_CommentSheet> createState() => _CommentSheetState();
}

class _CommentSheetState extends State<_CommentSheet> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('한 줄 남길까요?', style: t.titleLarge),
          const SizedBox(height: 4),
          Text('"${widget.question}" 답에 코멘트를 붙일 수 있어요. 서로 좋아요를 누르면 보여요.', style: t.bodySmall),
          const SizedBox(height: 16),
          TextField(controller: _text, maxLength: 60, autofocus: true),
          const SizedBox(height: 8),
          FilledButton(onPressed: () => Navigator.pop(context, _text.text), child: const Text('좋아요 보내기')),
          TextButton(onPressed: () => Navigator.pop(context, ''), child: const Text('코멘트 없이 보내기')),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 120),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppColors.of(context).muted,
              fontWeight: FontWeight.w400,
            ),
      ),
    );
  }
}
