import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/widgets/mood_image.dart';
import '../../core/widgets/section_title.dart';
import 'chat_repository.dart';

class ChatsScreen extends ConsumerWidget {
  const ChatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matches = ref.watch(myMatchesProvider);
    final c = AppColors.of(context);
    final t = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.refresh(myMatchesProvider.future),
          child: ListView(
            padding: const EdgeInsets.only(top: 32, bottom: 24),
            children: [
              const Padding(padding: EdgeInsets.symmetric(horizontal: 24), child: SectionTitle(title: '대화')),
              const SizedBox(height: 16),
              ...matches.when(
                loading: () => [const Padding(padding: EdgeInsets.all(80), child: Center(child: CircularProgressIndicator()))],
                error: (_, _) => [
                  Center(
                    child: TextButton(
                      onPressed: () => ref.invalidate(myMatchesProvider),
                      child: const Text('불러오지 못했어요. 눌러서 다시 시도'),
                    ),
                  ),
                ],
                data: (list) => list.isEmpty
                    ? [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 140),
                          child: Text('서로 마음이 닿으면\n여기에 대화가 열려요.',
                              textAlign: TextAlign.center,
                              style: t.titleLarge?.copyWith(color: c.muted, fontWeight: FontWeight.w400)),
                        ),
                      ]
                    : [for (final m in list) _MatchTile(m: m)],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MatchTile extends StatelessWidget {
  const _MatchTile({required this.m});

  final MatchSummary m;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final t = Theme.of(context).textTheme;
    final subtitle = m.closed
        ? '대화가 끝났어요'
        : (m.lastBody ?? '새로 열린 대화방이에요. 먼저 말을 걸어 볼까요?');
    return InkWell(
      onTap: () => context.push('/chats/${m.id}', extra: m),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Row(children: [
          SizedBox(width: 56, height: 56, child: MoodImage(path: m.moodPath, borderRadius: 18)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(m.nickname, style: t.titleLarge?.copyWith(fontSize: 17)),
              const SizedBox(height: 2),
              Text(subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.bodyMedium?.copyWith(color: m.unread > 0 ? c.ink : c.muted)),
            ]),
          ),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            if (m.lastAt != null) Text(_when(m.lastAt!), style: t.bodySmall),
            const SizedBox(height: 6),
            if (m.unread > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                decoration: BoxDecoration(color: c.rose, borderRadius: BorderRadius.circular(99)),
                child: Text('${m.unread}', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontSize: 12)),
              ),
          ]),
        ]),
      ),
    );
  }

  static String _when(DateTime at) {
    final now = DateTime.now();
    if (at.year == now.year && at.month == now.month && at.day == now.day) {
      final h = at.hour;
      return '${h < 12 ? '오전' : '오후'} ${h % 12 == 0 ? 12 : h % 12}:${at.minute.toString().padLeft(2, '0')}';
    }
    return '${at.month}월 ${at.day}일';
  }
}
