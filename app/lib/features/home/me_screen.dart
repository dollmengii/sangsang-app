import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/supabase.dart';
import '../../core/theme.dart';
import '../../core/widgets/mood_image.dart';
import '../../core/widgets/section_title.dart';
import '../auth/auth_repository.dart';
import '../photos/photo_repository.dart';

final myCreditBalanceProvider = FutureProvider<int>((ref) async {
  ref.watch(sessionProvider);
  final result = await ref.watch(supabaseProvider).rpc('my_credit_balance');
  return result as int;
});

class MeScreen extends ConsumerWidget {
  const MeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final c = AppColors.of(context);
    final balance = ref.watch(myCreditBalanceProvider);
    final photos = ref.watch(myPhotosProvider).value ?? const <MyPhoto>[];
    final primary = photos.where((p) => p.isPrimary).firstOrNull;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(top: 32, bottom: 24),
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: SectionTitle(title: '나'),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: () => context.push('/me/photos'),
                child: SizedBox(
                  height: 168,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      MoodImage(path: primary?.moodPath, borderRadius: 24),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(primary == null ? '사진을 올려 주세요' : '내 무드',
                                style: t.titleLarge?.copyWith(color: primary == null ? c.ink : Colors.white)),
                            const SizedBox(height: 2),
                            Text(
                              primary == null ? '얼굴이 나온 사진이 1장 이상 필요해요' : '사진 ${photos.length}장 · 눌러서 바꾸기',
                              style: t.bodySmall?.copyWith(
                                  color: primary == null ? c.muted : Colors.white.withValues(alpha: 0.85)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('프로필 고치기'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/me/profile'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('내 사진'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/me/photos'),
            ),
            ListTile(
              leading: const Icon(Icons.toll_outlined),
              title: const Text('크레딧'),
              subtitle: const Text('친구용 버전은 무료예요'),
              trailing: Text(
                balance.when(data: (v) => '$v', loading: () => '…', error: (_, _) => '-'),
                style: t.titleLarge?.copyWith(color: c.rose),
              ),
            ),
            const Divider(indent: 24, endIndent: 24),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('로그아웃'),
              onTap: () => ref.read(authRepositoryProvider).signOut(),
            ),
          ],
        ),
      ),
    );
  }
}
