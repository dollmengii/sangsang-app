import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase.dart';

class CardTag {
  const CardTag({required this.slot, required this.name, required this.category});

  final String slot;
  final String name;
  final String category;
}

class ProfileCard {
  const ProfileCard({
    required this.id,
    required this.nickname,
    required this.age,
    required this.region,
    required this.bio,
    required this.qa,
    required this.moodPath,
    required this.tags,
    required this.liked,
  });

  factory ProfileCard.fromRow(Map<String, dynamic> r) => ProfileCard(
        id: r['profile_id'] as String,
        nickname: r['nickname'] as String? ?? '',
        age: r['age'] as int? ?? 0,
        region: r['region'] as String? ?? '',
        bio: r['bio'] as String? ?? '',
        qa: [
          for (final q in (r['qa'] as List? ?? const []))
            (q['q'] as String, q['a'] as String),
        ],
        moodPath: r['mood_path'] as String?,
        tags: [
          for (final t in (r['tags'] as List? ?? const []))
            CardTag(slot: t['slot'] as String, name: t['name'] as String, category: t['category'] as String),
        ],
        liked: r['liked'] as bool?,
      );

  final String id;
  final String nickname;
  final int age;
  final String region;
  final String bio;
  final List<(String, String)> qa;
  final String? moodPath;
  final List<CardTag> tags;
  final bool? liked; // null = 아직, true = 좋아요, false = 넘김

  String? _tag(String slot) => tags.where((t) => t.slot == slot).map((t) => t.name).firstOrNull;

  /// "겉테토 속에겐", 같으면 "찐테토" (기획서 4.4)
  String? get energy {
    final outer = _tag('outer_energy');
    final inner = _tag('inner_energy');
    if (inner == null) return null;
    if (outer == null) return '속$inner';
    return outer == inner ? '찐$inner' : '겉$outer 속$inner';
  }

  String? get animal => _tag('animal');
  List<String> get moods => tags.where((t) => t.slot == 'mood').map((t) => t.name).toList();
  String? get character => _tag('character');
  List<String> get hobbies => tags.where((t) => t.slot == 'hobby').map((t) => t.name).toList();
  List<String> get styles =>
      tags.where((t) => t.slot == 'date_style' || t.slot == 'pace').map((t) => t.name).toList();
}

class CardsRepository {
  CardsRepository(this._client);

  final SupabaseClient _client;

  Future<List<ProfileCard>> today() async {
    final rows = await _client.rpc('today_cards') as List;
    return rows.map((r) => ProfileCard.fromRow(r as Map<String, dynamic>)).toList();
  }

  Future<void> respond(String to, {required bool like, String? comment}) {
    return _client.from('likes').insert({
      'from_id': _client.auth.currentUser!.id,
      'to_id': to,
      'liked': like,
      if (comment != null && comment.trim().isNotEmpty) 'comment': comment.trim(),
    });
  }

  /// 크레딧 3개로 4장 더. 더 보여줄 사람이 없으면 'no_more_cards'.
  Future<int> buyExtra() async => await _client.rpc('buy_extra_cards') as int;
}

final cardsRepositoryProvider = Provider<CardsRepository>((ref) => CardsRepository(ref.watch(supabaseProvider)));

final todayCardsProvider = FutureProvider<List<ProfileCard>>((ref) {
  ref.watch(sessionProvider);
  return ref.watch(cardsRepositoryProvider).today();
});
