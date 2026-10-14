import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase.dart';

class TagOption {
  const TagOption({required this.id, required this.category, required this.nameMale, required this.nameFemale});

  final String id;
  final String category;
  final String nameMale;
  final String nameFemale;

  String nameFor(String? gender) => gender == 'female' ? nameFemale : nameMale;
}

/// 프로필 입력에서 고르는 값. 서버의 profiles 줄과 본인이 고른 태그(source = self)를 함께 다룬다.
class ProfileDraft {
  String nickname = '';
  int? birthYear;
  String? gender;
  String? seeking;
  String? sido;
  String? sigungu;
  int ageMin = 23;
  int ageMax = 35;
  String bio = '';
  String? qaQuestion;
  String qaAnswer = '';
  List<int?> quiz = List.filled(5, null); // 1 = 테토 쪽, -1 = 에겐 쪽
  Set<String> hobbies = {};
  String? dateStyle;
  String? pace;

  /// 속 에너지 (기획서 4.4): 5문항 합이 +2 이상이면 테토, -2 이하면 에겐, 그 사이는 테겐.
  String? get innerEnergy {
    if (quiz.contains(null)) return null;
    final sum = quiz.fold<int>(0, (a, b) => a + b!);
    return sum >= 2 ? 'teto' : (sum <= -2 ? 'egen' : 'tegen');
  }
}

const qaQuestions = [
  '주말에 제일 행복한 순간은?',
  '요즘 빠져 있는 것 하나는?',
  '나를 웃게 만드는 사소한 것은?',
  '첫 데이트로 가고 싶은 곳은?',
  '친구들이 말하는 나의 반전은?',
];

/// 속 에너지 퀴즈. 각 문항의 첫 번째 답이 테토 쪽, 두 번째가 에겐 쪽.
const energyQuiz = [
  ('약속 장소를 정할 때 나는', '내가 먼저 정해서 제안해요', '상대 취향을 먼저 물어봐요'),
  ('서운한 일이 생기면', '바로 말하고 풀어요', '시간을 두고 조심스럽게 꺼내요'),
  ('친구들 사이에서 나는', '분위기를 이끄는 편', '잘 들어 주는 편'),
  ('새로운 걸 시작할 때', '일단 해 보고 생각해요', '충분히 알아보고 시작해요'),
  ('누군가를 위로할 때', '해결책을 같이 찾아 줘요', '마음을 먼저 들어 줘요'),
];

class ProfileRepository {
  ProfileRepository(this._client);

  final SupabaseClient _client;

  String get _uid => _client.auth.currentUser!.id;

  Future<List<TagOption>> tags(List<String> categories) async {
    final rows = await _client
        .from('tags')
        .select('id, category, name_male, name_female')
        .inFilter('category', categories)
        .eq('enabled', true)
        .order('sort_order');
    return rows
        .map((r) => TagOption(
              id: r['id'] as String,
              category: r['category'] as String,
              nameMale: r['name_male'] as String,
              nameFemale: r['name_female'] as String,
            ))
        .toList();
  }

  Future<ProfileDraft> load() async {
    final p = await _client.from('profiles').select().eq('id', _uid).single();
    final tags = await _client.from('profile_tags').select('slot, tag_id').eq('profile_id', _uid).eq('source', 'self');
    final d = ProfileDraft()
      ..nickname = p['nickname'] as String? ?? ''
      ..birthYear = p['birth_year'] as int?
      ..gender = p['gender'] as String?
      ..seeking = p['seeking'] as String?
      ..sido = p['region_sido'] as String?
      ..sigungu = p['region_sigungu'] as String?
      ..ageMin = p['age_min'] as int? ?? 23
      ..ageMax = p['age_max'] as int? ?? 35
      ..bio = p['bio'] as String? ?? '';
    final qa = (p['qa'] as List?) ?? const [];
    if (qa.isNotEmpty) {
      d.qaQuestion = qa.first['q'] as String?;
      d.qaAnswer = qa.first['a'] as String? ?? '';
    }
    for (final t in tags) {
      final id = t['tag_id'] as String;
      switch (t['slot']) {
        case 'hobby':
          d.hobbies.add(id);
        case 'date_style':
          d.dateStyle = id;
        case 'pace':
          d.pace = id;
        case 'inner_energy':
          // 다시 고칠 때 퀴즈 답은 남아 있지 않으니, 결과에 맞게 채워 둔다.
          d.quiz = switch (id) {
            'teto' => [1, 1, 1, -1, -1],
            'egen' => [-1, -1, -1, 1, 1],
            _ => [1, -1, 1, -1, 1],
          };
      }
    }
    return d;
  }

  Future<void> save(ProfileDraft d) async {
    await _client.from('profiles').update({
      'nickname': d.nickname.trim(),
      'birth_year': d.birthYear,
      'gender': d.gender,
      'seeking': d.seeking,
      'region_sido': d.sido,
      'region_sigungu': d.sigungu,
      'age_min': d.ageMin,
      'age_max': d.ageMax,
      'bio': d.bio.trim(),
      'qa': [
        if (d.qaQuestion != null && d.qaAnswer.trim().isNotEmpty) {'q': d.qaQuestion, 'a': d.qaAnswer.trim()},
      ],
      'onboarded_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', _uid);

    const slots = ['hobby', 'date_style', 'pace', 'inner_energy'];
    await _client.from('profile_tags').delete().eq('profile_id', _uid).eq('source', 'self').inFilter('slot', slots);
    await _client.from('profile_tags').insert([
      for (final h in d.hobbies) {'profile_id': _uid, 'slot': 'hobby', 'tag_id': h, 'source': 'self'},
      if (d.dateStyle != null) {'profile_id': _uid, 'slot': 'date_style', 'tag_id': d.dateStyle, 'source': 'self'},
      if (d.pace != null) {'profile_id': _uid, 'slot': 'pace', 'tag_id': d.pace, 'source': 'self'},
      {'profile_id': _uid, 'slot': 'inner_energy', 'tag_id': d.innerEnergy, 'source': 'self'},
    ]);
  }
}

final profileRepositoryProvider =
    Provider<ProfileRepository>((ref) => ProfileRepository(ref.watch(supabaseProvider)));

final selectableTagsProvider = FutureProvider<List<TagOption>>((ref) {
  return ref.watch(profileRepositoryProvider).tags(['hobby', 'date_style', 'pace']);
});
