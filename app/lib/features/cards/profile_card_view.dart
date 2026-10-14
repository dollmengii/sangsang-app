import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/widgets/mood_image.dart';
import '../../core/widgets/tag_chip.dart';
import 'cards_repository.dart';

/// 카드 한 장 (기획서 6장: 흐린 무드 이미지, 나이, 지역, 대표 동물상, 겉·속 에너지, 무드, 취미, 소개, 질문 답변).
class ProfileCardView extends StatelessWidget {
  const ProfileCardView({super.key, required this.card, this.footer});

  final ProfileCard card;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final t = Theme.of(context).textTheme;
    final white = Colors.white;
    final heroTags = [
      if (card.animal != null) card.animal!,
      if (card.energy != null) card.energy!,
      ...card.moods,
    ];
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 4 / 4.2,
            child: Stack(
              fit: StackFit.expand,
              children: [
                MoodImage(path: card.moodPath, borderRadius: 0),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(card.nickname, style: t.headlineMedium?.copyWith(color: white)),
                      Text('${card.age} · ${card.region}',
                          style: t.bodyMedium?.copyWith(color: white.withValues(alpha: 0.85))),
                      if (heroTags.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Wrap(spacing: 6, runSpacing: 6, children: [
                          for (var i = 0; i < heroTags.length; i++) TagChip(heroTags[i], strong: i < 2, onDark: true),
                        ]),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(card.bio, style: t.titleLarge?.copyWith(fontWeight: FontWeight.w400, fontSize: 18)),
                const SizedBox(height: 14),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  if (card.character != null) TagChip(card.character!),
                  for (final h in card.hobbies) TagChip(h),
                  for (final s in card.styles) TagChip(s),
                ]),
                for (final (q, a) in card.qa) ...[
                  const SizedBox(height: 18),
                  Text(q, style: t.bodySmall?.copyWith(color: c.rose)),
                  const SizedBox(height: 2),
                  Text(a, style: t.bodyLarge),
                ],
                if (footer != null) ...[const SizedBox(height: 20), footer!],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
