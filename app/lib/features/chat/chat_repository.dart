import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase.dart';

class MatchSummary {
  const MatchSummary({
    required this.id,
    required this.otherId,
    required this.nickname,
    required this.moodPath,
    required this.closed,
    required this.lastBody,
    required this.lastAt,
    required this.unread,
    required this.myCount,
    required this.theirCount,
    required this.revealed,
  });

  factory MatchSummary.fromRow(Map<String, dynamic> r) => MatchSummary(
        id: r['match_id'] as String,
        otherId: r['other_id'] as String,
        nickname: r['nickname'] as String? ?? '',
        moodPath: r['mood_path'] as String?,
        closed: r['closed'] as bool,
        lastBody: r['last_body'] as String?,
        lastAt: DateTime.tryParse(r['last_at'] as String? ?? r['created_at'] as String)?.toLocal(),
        unread: r['unread'] as int,
        myCount: r['my_count'] as int,
        theirCount: r['their_count'] as int,
        revealed: r['revealed'] as bool,
      );

  final String id;
  final String otherId;
  final String nickname;
  final String? moodPath;
  final bool closed;
  final String? lastBody;
  final DateTime? lastAt;
  final int unread;
  final int myCount;
  final int theirCount;
  final bool revealed;
}

class ChatMessage {
  const ChatMessage({required this.id, required this.sender, required this.body, required this.createdAt});

  factory ChatMessage.fromRow(Map<String, dynamic> r) => ChatMessage(
        id: r['id'] as int,
        sender: r['sender'] as String,
        body: r['body'] as String,
        createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
      );

  final int id;
  final String sender;
  final String body;
  final DateTime createdAt;
}

const reportKinds = {
  'sexual': '불쾌하거나 성적인 메시지',
  'pressure_reveal': '얼굴 공개를 강요해요',
  'money': '돈을 요구하거나 투자를 권해요',
  'married': '기혼자 같아요',
  'minor': '미성년자 같아요',
  'other': '기타',
};

class ChatRepository {
  ChatRepository(this._client);

  final SupabaseClient _client;

  String get uid => _client.auth.currentUser!.id;

  Future<List<MatchSummary>> matches() async {
    final rows = await _client.rpc('my_matches') as List;
    return rows.map((r) => MatchSummary.fromRow(r as Map<String, dynamic>)).toList();
  }

  /// 대화방 메시지를 실시간으로 받는다.
  Stream<List<ChatMessage>> messages(String matchId) => _client
      .from('messages')
      .stream(primaryKey: ['id'])
      .eq('match_id', matchId)
      .order('id')
      .map((rows) => rows.map(ChatMessage.fromRow).toList());

  Future<void> send(String matchId, String body) =>
      _client.from('messages').insert({'match_id': matchId, 'sender': uid, 'body': body});

  Future<void> markRead(String matchId, int lastId) => _client
      .from('match_reads')
      .upsert({'match_id': matchId, 'user_id': uid, 'last_read_id': lastId});

  Future<String?> icebreaker(String matchId) async =>
      await _client.rpc('match_icebreaker', params: {'p_match': matchId}) as String?;

  Future<List<(String, String)>> likeComments(String matchId) async {
    final rows = await _client.rpc('match_like_comments', params: {'p_match': matchId}) as List;
    return [for (final r in rows) (r['from_id'] as String, r['comment'] as String)];
  }

  Future<void> report(String target, String matchId, String kind, String? detail) =>
      _client.from('reports').insert({
        'reporter': uid,
        'target': target,
        'match_id': matchId,
        'kind': kind,
        if (detail != null && detail.trim().isNotEmpty) 'detail': detail.trim(),
      });

  Future<void> block(String target) => _client.from('blocks').insert({'blocker': uid, 'blocked': target});

  Future<void> leave(String matchId) => _client.rpc('leave_match', params: {'p_match': matchId});
}

final chatRepositoryProvider = Provider<ChatRepository>((ref) => ChatRepository(ref.watch(supabaseProvider)));

final myMatchesProvider = FutureProvider<List<MatchSummary>>((ref) {
  ref.watch(sessionProvider);
  return ref.watch(chatRepositoryProvider).matches();
});

final messagesProvider = StreamProvider.family<List<ChatMessage>, String>((ref, matchId) {
  return ref.watch(chatRepositoryProvider).messages(matchId);
});

final icebreakerProvider = FutureProvider.family<String?, String>((ref, matchId) {
  return ref.watch(chatRepositoryProvider).icebreaker(matchId);
});

final likeCommentsProvider = FutureProvider.family<List<(String, String)>, String>((ref, matchId) {
  return ref.watch(chatRepositoryProvider).likeComments(matchId);
});

/// 연락처처럼 보이는 글 (기획서 7장: 막지 않고 안내만)
final contactPattern = RegExp(
  r'(01[016789][-\s.]?\d{3,4}[-\s.]?\d{4})|(카톡|카카오톡|kakao|인스타|insta|아이디|id)\s*[:：]?\s*[A-Za-z0-9_.]{3,}',
  caseSensitive: false,
);

/// 돈 이야기 (로맨스 스캠 주의)
final moneyPattern = RegExp(r'(코인|투자|송금|입금|계좌|텔레그램|telegram|리딩방|수익률|비트코인|USDT)', caseSensitive: false);
