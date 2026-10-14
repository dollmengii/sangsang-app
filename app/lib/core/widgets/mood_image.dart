import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../supabase.dart';
import '../theme.dart';

/// moods 버킷의 아주 작은(가로 20px) 무드 이미지를 받아 온다. 한 번 받으면 기억한다.
final moodBytesProvider = FutureProvider.family<Uint8List, String>((ref, path) async {
  ref.keepAlive();
  return ref.watch(supabaseProvider).storage.from('moods').download(path);
});

/// 무드 이미지를 크게 늘리고 한 번 더 흐리게 해서 색감과 분위기만 남긴다 (기획서 5장).
class MoodImage extends ConsumerWidget {
  const MoodImage({super.key, required this.path, this.borderRadius = 20});

  final String? path;
  final double borderRadius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final p = path;
    final bytes = p == null ? null : ref.watch(moodBytesProvider(p)).value;
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: c.line),
          if (bytes != null)
            ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 22, sigmaY: 22, tileMode: TileMode.mirror),
              child: Image.memory(bytes, fit: BoxFit.cover, filterQuality: FilterQuality.medium, gaplessPlayback: true),
            ),
          // 아래쪽을 살짝 어둡게 해서 위에 얹는 글자가 읽히게 한다.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withValues(alpha: 0.22)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
