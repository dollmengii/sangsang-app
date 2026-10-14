import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import 'chat_repository.dart';

/// 대화방 (기획서 7장). 글자만 주고받고, 첫 질문 카드와 공개까지 남은 정도를 보여준다.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.match});

  final MatchSummary match;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  static const revealMinMessages = 10; // 서버 app_config.reveal_min_messages 와 같은 값

  final _input = TextEditingController();
  bool _sending = false;
  int _lastMarked = 0;

  MatchSummary get m => widget.match;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final body = _input.text.trim();
    if (body.isEmpty) return;
    setState(() => _sending = true);
    try {
      await ref.read(chatRepositoryProvider).send(m.id, body);
      _input.clear();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('보내지 못했어요.')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _markRead(List<ChatMessage> messages) {
    if (messages.isEmpty) return;
    final last = messages.last.id;
    if (last <= _lastMarked) return;
    _lastMarked = last;
    ref.read(chatRepositoryProvider).markRead(m.id, last).then((_) => ref.invalidate(myMatchesProvider));
  }

  Future<void> _menu() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.flag_outlined), title: const Text('신고하기'), onTap: () => Navigator.pop(context, 'report')),
          ListTile(leading: const Icon(Icons.block), title: const Text('차단하기'), onTap: () => Navigator.pop(context, 'block')),
          ListTile(leading: const Icon(Icons.logout), title: const Text('대화방 나가기'), onTap: () => Navigator.pop(context, 'leave')),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (!mounted || action == null) return;
    final repo = ref.read(chatRepositoryProvider);
    switch (action) {
      case 'report':
        final result = await showModalBottomSheet<(String, String)>(
          context: context,
          isScrollControlled: true,
          builder: (_) => const _ReportSheet(),
        );
        if (result == null) return;
        await repo.report(m.otherId, m.id, result.$1, result.$2);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('신고를 받았어요. 하루 안에 확인할게요.')));
        }
      case 'block':
        if (!await _confirm('차단할까요?', '대화방이 닫히고, 서로의 카드에 다시 나오지 않아요.')) return;
        await repo.block(m.otherId);
        ref.invalidate(myMatchesProvider);
        if (mounted) context.pop();
      case 'leave':
        if (!await _confirm('대화방을 나갈까요?', '나가면 두 사람 모두 이 대화를 이어갈 수 없어요.')) return;
        await repo.leave(m.id);
        ref.invalidate(myMatchesProvider);
        if (mounted) context.pop();
    }
  }

  Future<bool> _confirm(String title, String body) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('확인')),
          ],
        ),
      ) ??
      false;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final t = Theme.of(context).textTheme;
    final repo = ref.read(chatRepositoryProvider);
    final messages = ref.watch(messagesProvider(m.id));
    final icebreaker = ref.watch(icebreakerProvider(m.id)).value;
    final comments = ref.watch(likeCommentsProvider(m.id)).value ?? const [];

    final list = messages.value ?? const <ChatMessage>[];
    if (messages.hasValue) WidgetsBinding.instance.addPostFrameCallback((_) => _markRead(list));
    final mine = list.where((x) => x.sender == repo.uid).length;
    final theirs = list.length - mine;

    return Scaffold(
      appBar: AppBar(
        title: Text(m.nickname),
        actions: [IconButton(onPressed: _menu, icon: const Icon(Icons.more_horiz))],
      ),
      body: Column(children: [
        _RevealProgress(mine: mine, theirs: theirs, min: revealMinMessages, revealed: m.revealed),
        Expanded(
          child: ListView(
            reverse: true,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            children: [
              for (final msg in list.reversed) _Bubble(msg: msg, mine: msg.sender == repo.uid, revealed: m.revealed),
              const SizedBox(height: 12),
              for (final (from, text) in comments)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '${from == repo.uid ? '내가' : '${m.nickname}님이'} 좋아요와 함께 남긴 말: "$text"',
                    textAlign: TextAlign.center,
                    style: t.bodySmall,
                  ),
                ),
              if (icebreaker != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: c.line),
                  ),
                  child: Column(children: [
                    Text('첫 질문', style: t.labelLarge?.copyWith(color: c.rose)),
                    const SizedBox(height: 6),
                    Text(icebreaker, textAlign: TextAlign.center, style: t.titleLarge?.copyWith(fontSize: 17, fontWeight: FontWeight.w400)),
                  ]),
                ),
            ],
          ),
        ),
        if (m.closed)
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text('대화가 끝난 방이에요.', style: t.bodyMedium?.copyWith(color: c.muted)),
          )
        else
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: c.line))),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: 1000,
                    textInputAction: TextInputAction.newline,
                    decoration: const InputDecoration(
                      hintText: '메시지',
                      counterText: '',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _sending ? null : _send,
                  icon: Icon(Icons.arrow_upward_rounded, color: c.rose),
                ),
              ]),
            ),
          ),
      ]),
    );
  }
}

class _RevealProgress extends StatelessWidget {
  const _RevealProgress({required this.mine, required this.theirs, required this.min, required this.revealed});

  final int mine;
  final int theirs;
  final int min;
  final bool revealed;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final t = Theme.of(context).textTheme;
    final ready = mine >= min && theirs >= min;
    final progress = ((mine.clamp(0, min) + theirs.clamp(0, min)) / (min * 2));
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          revealed
              ? '서로 얼굴을 공개했어요'
              : ready
                  ? '이제 얼굴 공개를 요청할 수 있어요 (곧 열려요)'
                  : '얼굴 공개까지  나 ${mine.clamp(0, min)}/$min · 상대 ${theirs.clamp(0, min)}/$min',
          style: t.bodySmall?.copyWith(color: ready || revealed ? c.rose : c.muted),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: revealed ? 1 : progress,
            minHeight: 3,
            backgroundColor: c.line,
            color: c.rose,
          ),
        ),
      ]),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.msg, required this.mine, required this.revealed});

  final ChatMessage msg;
  final bool mine;
  final bool revealed;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final t = Theme.of(context).textTheme;
    final onRose = Theme.of(context).colorScheme.onPrimary;
    // 연락처는 공개 전이면 양쪽에, 돈 이야기는 받는 사람에게만 안내를 붙인다 (기획서 7장).
    final hint = !revealed && contactPattern.hasMatch(msg.body)
        ? '아직 서로 얼굴도 안 봤어요. 연락처는 천천히 주고받아도 괜찮아요.'
        : (!mine && moneyPattern.hasMatch(msg.body)
            ? '돈, 투자, 송금 이야기가 나오면 로맨스 스캠일 수 있어요. 절대 돈을 보내지 마세요.'
            : null);
    return Column(
      crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.72),
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: mine ? c.rose : c.surface,
            border: mine ? null : Border.all(color: c.line),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(mine ? 18 : 4),
              bottomRight: Radius.circular(mine ? 4 : 18),
            ),
          ),
          child: Text(msg.body, style: t.bodyLarge?.copyWith(color: mine ? onRose : c.ink, height: 1.45)),
        ),
        if (hint != null)
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 6),
            child: Text(hint, style: t.bodySmall?.copyWith(color: c.dusk)),
          ),
      ],
    );
  }
}

class _ReportSheet extends StatefulWidget {
  const _ReportSheet();

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  String? _kind;
  final _detail = TextEditingController();

  @override
  void dispose() {
    _detail.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('무슨 일이 있었나요?', style: t.titleLarge),
          const SizedBox(height: 8),
          RadioGroup<String>(
            groupValue: _kind,
            onChanged: (v) => setState(() => _kind = v),
            child: Column(children: [
              for (final e in reportKinds.entries)
                RadioListTile<String>(value: e.key, title: Text(e.value), contentPadding: EdgeInsets.zero),
            ]),
          ),
          TextField(controller: _detail, maxLength: 500, maxLines: 3, decoration: const InputDecoration(hintText: '더 알려 줄 내용 (선택)')),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _kind == null ? null : () => Navigator.pop(context, (_kind!, _detail.text)),
            child: const Text('신고하기'),
          ),
        ],
      ),
    );
  }
}
