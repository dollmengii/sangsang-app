import 'package:flutter/material.dart';

/// 화면 위쪽의 큰 세리프 제목과 한두 줄 설명.
class SectionTitle extends StatelessWidget {
  const SectionTitle({super.key, required this.title, this.caption});

  final String title;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: t.headlineMedium),
        if (caption != null) ...[
          const SizedBox(height: 6),
          Text(caption!, style: t.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ],
    );
  }
}
