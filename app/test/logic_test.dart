import 'package:flutter_test/flutter_test.dart';
import 'package:sangsang/features/cards/cards_repository.dart';
import 'package:sangsang/features/chat/chat_repository.dart';
import 'package:sangsang/features/profile/profile_repository.dart';

ProfileCard card(List<Map<String, String>> tags) => ProfileCard.fromRow({
      'profile_id': 'x',
      'nickname': 'n',
      'age': 28,
      'region': '서울 마포구',
      'bio': 'b',
      'qa': [],
      'mood_path': null,
      'tags': tags,
      'liked': null,
    });

void main() {
  group('속 에너지 퀴즈', () {
    test('다 답하지 않으면 결과가 없다', () {
      final d = ProfileDraft()..quiz = [1, 1, 1, 1, null];
      expect(d.innerEnergy, isNull);
    });
    test('합이 +2 이상이면 테토, -2 이하면 에겐, 그 사이는 테겐', () {
      expect((ProfileDraft()..quiz = [1, 1, 1, -1, 1]).innerEnergy, 'teto');
      expect((ProfileDraft()..quiz = [-1, -1, 1, -1, 1]).innerEnergy, 'tegen');
      expect((ProfileDraft()..quiz = [-1, -1, -1, 1, -1]).innerEnergy, 'egen');
    });
  });

  group('카드의 겉·속 에너지 표시', () {
    test('겉과 속이 다르면 "겉 속"', () {
      final c = card([
        {'slot': 'outer_energy', 'name': '테토남', 'category': 'energy'},
        {'slot': 'inner_energy', 'name': '에겐남', 'category': 'energy'},
      ]);
      expect(c.energy, '겉테토남 속에겐남');
    });
    test('같으면 "찐"', () {
      final c = card([
        {'slot': 'outer_energy', 'name': '에겐녀', 'category': 'energy'},
        {'slot': 'inner_energy', 'name': '에겐녀', 'category': 'energy'},
      ]);
      expect(c.energy, '찐에겐녀');
    });
    test('AI 분석 전에는 속만', () {
      final c = card([{'slot': 'inner_energy', 'name': '테겐', 'category': 'energy'}]);
      expect(c.energy, '속테겐');
    });
  });

  group('대화 안내', () {
    test('전화번호와 카톡 아이디처럼 보이는 글', () {
      expect(contactPattern.hasMatch('제 번호 010-1234-5678 이에요'), isTrue);
      expect(contactPattern.hasMatch('카톡 아이디: sangsang_99'), isTrue);
      expect(contactPattern.hasMatch('오늘 날씨 좋네요'), isFalse);
    });
    test('돈 이야기', () {
      expect(moneyPattern.hasMatch('코인 리딩방 들어올래요?'), isTrue);
      expect(moneyPattern.hasMatch('텔레그램으로 얘기해요'), isTrue);
      expect(moneyPattern.hasMatch('주말에 뭐 해요?'), isFalse);
    });
  });
}
