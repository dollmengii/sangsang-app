import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/regions.dart';
import '../../core/theme.dart';
import '../../core/widgets/section_title.dart';
import '../../core/widgets/tag_chip.dart';
import '../onboarding/profile_state.dart';
import '../photos/photo_repository.dart';
import 'profile_repository.dart';

/// 프로필 입력 (기획서 5장, 4.7, 4.4의 속 에너지 퀴즈). 처음 가입할 때와 나중에 고칠 때 함께 쓴다.
class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key, this.editing = false});

  final bool editing;

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  ProfileDraft? _d;
  bool _saving = false;
  final _nickname = TextEditingController();
  final _bio = TextEditingController();
  final _qa = TextEditingController();

  @override
  void initState() {
    super.initState();
    ref.read(profileRepositoryProvider).load().then((d) {
      if (!mounted) return;
      _nickname.text = d.nickname;
      _bio.text = d.bio;
      _qa.text = d.qaAnswer;
      setState(() => _d = d);
    });
  }

  @override
  void dispose() {
    _nickname.dispose();
    _bio.dispose();
    _qa.dispose();
    super.dispose();
  }

  int get _thisYear => DateTime.now().year;

  /// 저장 전에 빠진 것. 없으면 null.
  String? _missing(ProfileDraft d, List<MyPhoto> photos) {
    if (_nickname.text.trim().isEmpty) return '닉네임을 적어 주세요';
    if (d.birthYear == null) return '태어난 해를 골라 주세요';
    if (d.gender == null || d.seeking == null) return '성별과 만나고 싶은 사람을 골라 주세요';
    if (d.sido == null || ((regions[d.sido] ?? const []).isNotEmpty && d.sigungu == null)) {
      return '활동 지역을 골라 주세요';
    }
    if (!photos.any((p) => p.isFace)) return '얼굴이 나온 사진을 1장 이상 올려 주세요';
    if (d.innerEnergy == null) return '속 에너지 질문 다섯 개에 답해 주세요';
    if (d.hobbies.length < 2) return '취미를 2개 이상 골라 주세요';
    if (_bio.text.trim().isEmpty) return '한 줄 소개를 적어 주세요';
    return null;
  }

  Future<void> _save() async {
    final d = _d!;
    d
      ..nickname = _nickname.text
      ..bio = _bio.text
      ..qaAnswer = _qa.text;
    setState(() => _saving = true);
    try {
      await ref.read(profileRepositoryProvider).save(d);
      ref.invalidate(myProfileStateProvider);
      if (mounted && widget.editing) context.pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('저장하지 못했어요. 잠시 뒤 다시 해 주세요.')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    final c = AppColors.of(context);
    final t = Theme.of(context).textTheme;
    if (d == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final tags = ref.watch(selectableTagsProvider).value ?? const <TagOption>[];
    final photos = ref.watch(myPhotosProvider).value ?? const <MyPhoto>[];
    final missing = _missing(d, photos);

    return Scaffold(
      appBar: widget.editing ? AppBar() : null,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(24, widget.editing ? 0 : 40, 24, 32),
                children: [
                  SectionTitle(
                    title: widget.editing ? '프로필 고치기' : '나를 소개해요',
                    caption: widget.editing ? null : '얼굴 대신 이 이야기들이 먼저 닿아요.',
                  ),
                  _Section('기본'),
                  TextField(
                    controller: _nickname,
                    maxLength: 12,
                    decoration: const InputDecoration(labelText: '닉네임'),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    initialValue: d.birthYear,
                    decoration: const InputDecoration(labelText: '태어난 해'),
                    items: [
                      for (var y = _thisYear - 19; y >= _thisYear - 60; y--)
                        DropdownMenuItem(value: y, child: Text('$y년 (${_thisYear - y}세)')),
                    ],
                    onChanged: (v) => setState(() => d.birthYear = v),
                  ),
                  const SizedBox(height: 20),
                  Text('나는', style: t.labelLarge?.copyWith(color: c.muted)),
                  const SizedBox(height: 8),
                  _Choice(
                    options: const {'male': '남성', 'female': '여성'},
                    value: d.gender,
                    onChanged: (v) => setState(() {
                      d.gender = v;
                      d.seeking ??= v == 'male' ? 'female' : 'male';
                    }),
                  ),
                  const SizedBox(height: 16),
                  Text('만나고 싶은 사람', style: t.labelLarge?.copyWith(color: c.muted)),
                  const SizedBox(height: 8),
                  _Choice(
                    options: const {'male': '남성', 'female': '여성'},
                    value: d.seeking,
                    onChanged: (v) => setState(() => d.seeking = v),
                  ),

                  _Section('어디서, 몇 살쯤'),
                  Row(children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: d.sido,
                        decoration: const InputDecoration(labelText: '시·도'),
                        items: [for (final s in regions.keys) DropdownMenuItem(value: s, child: Text(s))],
                        onChanged: (v) => setState(() {
                          d.sido = v;
                          d.sigungu = null;
                        }),
                      ),
                    ),
                    if ((regions[d.sido] ?? const []).isNotEmpty) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          key: ValueKey(d.sido),
                          initialValue: d.sigungu,
                          decoration: const InputDecoration(labelText: '구·시'),
                          items: [for (final s in regions[d.sido]!) DropdownMenuItem(value: s, child: Text(s))],
                          onChanged: (v) => setState(() => d.sigungu = v),
                        ),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 20),
                  Text('만나고 싶은 나이  ${d.ageMin}~${d.ageMax}세', style: t.labelLarge?.copyWith(color: c.muted)),
                  RangeSlider(
                    values: RangeValues(d.ageMin.toDouble(), d.ageMax.toDouble()),
                    min: 19,
                    max: 60,
                    divisions: 41,
                    onChanged: (r) => setState(() {
                      d.ageMin = r.start.round();
                      d.ageMax = r.end.round();
                    }),
                  ),

                  _Section('사진'),
                  Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                      leading: Icon(Icons.photo_library_outlined, color: c.rose),
                      title: Text(photos.isEmpty ? '사진 올리기' : '사진 ${photos.length}장'),
                      subtitle: const Text('다른 사람에게는 흐린 무드 이미지만 보여요'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push(widget.editing ? '/me/photos' : '/setup/photos'),
                    ),
                  ),

                  _Section('속 에너지', caption: '사진이 말하는 겉모습과 다를 수도 있어요. 그게 더 재밌어요.'),
                  for (var i = 0; i < energyQuiz.length; i++) ...[
                    Text(energyQuiz[i].$1, style: t.bodyLarge),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      SelectTag(
                        label: energyQuiz[i].$2,
                        selected: d.quiz[i] == 1,
                        onTap: () => setState(() => d.quiz[i] = 1),
                      ),
                      SelectTag(
                        label: energyQuiz[i].$3,
                        selected: d.quiz[i] == -1,
                        onTap: () => setState(() => d.quiz[i] = -1),
                      ),
                    ]),
                    const SizedBox(height: 18),
                  ],
                  if (d.innerEnergy != null)
                    Text(
                      '속은 ${switch (d.innerEnergy) { 'teto' => '테토', 'egen' => '에겐', _ => '테겐' }}이에요.',
                      style: t.titleLarge?.copyWith(color: c.rose),
                    ),

                  _Section('취미', caption: '2~3개'),
                  _TagPicker(
                    options: tags.where((x) => x.category == 'hobby').toList(),
                    gender: d.gender,
                    isSelected: d.hobbies.contains,
                    canAdd: d.hobbies.length < 3,
                    onTap: (id) => setState(() => d.hobbies.contains(id) ? d.hobbies.remove(id) : d.hobbies.add(id)),
                  ),
                  _Section('데이트 스타일'),
                  _TagPicker(
                    options: tags.where((x) => x.category == 'date_style').toList(),
                    gender: d.gender,
                    isSelected: (id) => d.dateStyle == id,
                    onTap: (id) => setState(() => d.dateStyle = d.dateStyle == id ? null : id),
                  ),
                  _Section('만남 속도', caption: '얼굴 공개를 언제쯤 원하는지 미리 알려 줘요.'),
                  _TagPicker(
                    options: tags.where((x) => x.category == 'pace').toList(),
                    gender: d.gender,
                    isSelected: (id) => d.pace == id,
                    onTap: (id) => setState(() => d.pace = d.pace == id ? null : id),
                  ),

                  _Section('한 줄 소개'),
                  TextField(
                    controller: _bio,
                    maxLength: 40,
                    decoration: const InputDecoration(hintText: '주말엔 한강 러닝하고 빵집 가는 게 낙이에요.'),
                    onChanged: (_) => setState(() {}),
                  ),
                  _Section('질문 하나', caption: '골라서 답하면 카드에 함께 보여요. 건너뛰어도 돼요.'),
                  DropdownButtonFormField<String>(
                    initialValue: d.qaQuestion,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: '질문'),
                    items: [for (final q in qaQuestions) DropdownMenuItem(value: q, child: Text(q))],
                    onChanged: (v) => setState(() => d.qaQuestion = v),
                  ),
                  if (d.qaQuestion != null)
                    TextField(controller: _qa, maxLength: 60, decoration: const InputDecoration(labelText: '내 답')),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: c.line))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (missing != null) ...[
                    Text(missing, textAlign: TextAlign.center, style: t.bodySmall),
                    const SizedBox(height: 8),
                  ],
                  FilledButton(
                    onPressed: missing == null && !_saving ? _save : null,
                    child: Text(_saving ? '저장하는 중…' : (widget.editing ? '저장' : '다 됐어요')),
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

class _Section extends StatelessWidget {
  const _Section(this.title, {this.caption});

  final String title;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 36, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: t.titleLarge),
          if (caption != null) Text(caption!, style: t.bodySmall),
        ],
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({required this.options, required this.value, required this.onChanged});

  final Map<String, String> options;
  final String? value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 8, children: [
      for (final e in options.entries)
        SelectTag(label: e.value, selected: value == e.key, onTap: () => onChanged(e.key)),
    ]);
  }
}

class _TagPicker extends StatelessWidget {
  const _TagPicker({
    required this.options,
    required this.gender,
    required this.isSelected,
    required this.onTap,
    this.canAdd = true,
  });

  final List<TagOption> options;
  final String? gender;
  final bool Function(String id) isSelected;
  final ValueChanged<String> onTap;
  final bool canAdd;

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 8, runSpacing: 8, children: [
      for (final o in options)
        SelectTag(
          label: o.nameFor(gender),
          selected: isSelected(o.id),
          onTap: isSelected(o.id) || canAdd ? () => onTap(o.id) : null,
        ),
    ]);
  }
}
