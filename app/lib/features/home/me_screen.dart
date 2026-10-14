import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supabase.dart';
import '../auth/auth_repository.dart';

final myCreditBalanceProvider = FutureProvider<int>((ref) async {
  ref.watch(sessionProvider);
  final result = await ref.watch(supabaseProvider).rpc('my_credit_balance');
  return result as int;
});

class MeScreen extends ConsumerWidget {
  const MeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balance = ref.watch(myCreditBalanceProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('나')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.toll_outlined),
            title: const Text('크레딧'),
            subtitle: const Text('친구용 버전은 무료예요'),
            trailing: Text(balance.when(
              data: (v) => '$v',
              loading: () => '…',
              error: (_, _) => '-',
            )),
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('로그아웃'),
            onTap: () => ref.read(authRepositoryProvider).signOut(),
          ),
        ],
      ),
    );
  }
}
