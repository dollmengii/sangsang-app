import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../core/widgets/mood_image.dart';
import '../../core/widgets/section_title.dart';
import 'photo_repository.dart';

class MyPhotosScreen extends ConsumerStatefulWidget {
  const MyPhotosScreen({super.key});

  @override
  ConsumerState<MyPhotosScreen> createState() => _MyPhotosScreenState();
}

class _MyPhotosScreenState extends ConsumerState<MyPhotosScreen> {
  bool _uploading = false;

  void _toast(String message) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _add() async {
    final isFace = await showModalBottomSheet<bool>(
      context: context,
      builder: (context) => const _PhotoKindSheet(),
    );
    if (isFace == null) return;
    final repo = ref.read(photoRepositoryProvider);
    final bytes = await repo.pick();
    if (bytes == null) return;
    setState(() => _uploading = true);
    try {
      await repo.upload(bytes, isFace: isFace);
      ref.invalidate(myPhotosProvider);
    } on PhotoUploadException catch (e) {
      _toast(e.message);
    } catch (_) {
      _toast('사진을 올리지 못했어요. 연결을 확인하고 다시 해 주세요.');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _actions(MyPhoto photo) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!photo.isPrimary)
              ListTile(
                leading: const Icon(Icons.star_outline),
                title: const Text('대표 사진으로'),
                subtitle: const Text('무드 이미지가 이 사진으로 바뀌어요'),
                onTap: () => Navigator.pop(context, 'primary'),
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('지우기'),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (action == null) return;
    final repo = ref.read(photoRepositoryProvider);
    try {
      if (action == 'primary') await repo.setPrimary(photo.id);
      if (action == 'delete') await repo.delete(photo.id);
      ref.invalidate(myPhotosProvider);
    } catch (_) {
      _toast('바꾸지 못했어요. 잠시 뒤 다시 해 주세요.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final photos = ref.watch(myPhotosProvider);
    final c = AppColors.of(context);
    final t = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(),
      body: photos.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(myPhotosProvider),
            child: const Text('불러오지 못했어요. 눌러서 다시 시도'),
          ),
        ),
        data: (list) {
          final primary = list.where((p) => p.isPrimary).firstOrNull;
          return ListView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
            children: [
              const SectionTitle(
                title: '내 사진',
                caption: '얼굴이 나온 사진 1장 이상, 모두 3장까지.\n원본은 나와, 서로 공개에 동의한 사람만 볼 수 있어요.',
              ),
              const SizedBox(height: 28),
              Text('다른 사람에게는 이렇게 보여요', style: t.labelLarge?.copyWith(color: c.muted)),
              const SizedBox(height: 12),
              AspectRatio(
                aspectRatio: 4 / 5,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    MoodImage(path: primary?.moodPath, borderRadius: 28),
                    if (primary == null)
                      Center(
                        child: Text('아직 사진이 없어요',
                            style: t.titleLarge?.copyWith(color: c.muted)),
                      )
                    else
                      Positioned(
                        left: 20,
                        bottom: 18,
                        right: 20,
                        child: Text('색감과 분위기만 남겨요',
                            style: t.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.9))),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  for (var i = 0; i < maxPhotos; i++) ...[
                    if (i > 0) const SizedBox(width: 12),
                    Expanded(
                      child: AspectRatio(
                        aspectRatio: 3 / 4,
                        child: i < list.length
                            ? _PhotoSlot(photo: list[i], onTap: () => _actions(list[i]))
                            : _EmptySlot(
                                busy: _uploading && i == list.length,
                                enabled: !_uploading && i == list.length,
                                onTap: _add,
                              ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 20),
              Text(
                '사진을 올리면 촬영 위치 같은 숨은 정보는 지우고, 긴 쪽을 1080픽셀로 줄여서 보관해요.',
                style: t.bodySmall,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PhotoSlot extends ConsumerWidget {
  const _PhotoSlot({required this.photo, required this.onTap});

  final MyPhoto photo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final bytes = ref.watch(myOriginalProvider(photo.originalPath)).value;
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: c.line),
            if (bytes != null) Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true),
            Positioned(
              left: 8,
              top: 8,
              child: Wrap(spacing: 4, children: [
                if (photo.isPrimary) const _Badge('대표'),
                if (!photo.isFace) const _Badge('취미'),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11)),
    );
  }
}

class _EmptySlot extends StatelessWidget {
  const _EmptySlot({required this.busy, required this.enabled, required this.onTap});

  final bool busy;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Material(
      color: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: c.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Center(
          child: busy
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(Icons.add, color: enabled ? c.rose : c.line, size: 28),
        ),
      ),
    );
  }
}

class _PhotoKindSheet extends StatelessWidget {
  const _PhotoKindSheet();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('어떤 사진인가요?', style: t.titleLarge),
            const SizedBox(height: 6),
            Text('본인 사진만 올려 주세요. 다른 사람이 함께 나온 사진은 쓸 수 없어요.', style: t.bodySmall),
            const SizedBox(height: 20),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('얼굴이 나온 사진')),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취미 사진 (얼굴 없음)'),
            ),
          ],
        ),
      ),
    );
  }
}
