import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/supabase.dart';
import 'core/theme.dart';
import 'features/auth/login_screen.dart';
import 'features/home/home_shell.dart';
import 'features/home/me_screen.dart';
import 'features/onboarding/consent_screen.dart';
import 'features/onboarding/profile_state.dart';
import 'features/photos/my_photos_screen.dart';

/// 로그인과 가입 단계가 바뀌면 라우터가 redirect를 다시 계산하게 한다.
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(Ref ref) {
    ref.listen(sessionProvider, (_, _) => notifyListeners());
    ref.listen(myProfileStateProvider, (_, _) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/cards',
    refreshListenable: refresh,
    redirect: (context, state) {
      final session = ref.read(sessionProvider);
      if (session.isLoading) return '/splash';
      final loggedIn = session.value != null;
      final at = state.matchedLocation;
      if (!loggedIn) return at == '/login' ? null : '/login';

      final profile = ref.read(myProfileStateProvider);
      if (profile.isLoading && !profile.hasValue) return '/splash';
      final p = profile.value;
      if (p != null && !p.geminiConsented) return at == '/consent' ? null : '/consent';

      if (at == '/login' || at == '/consent' || at == '/splash') return '/cards';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const Scaffold(body: Center(child: CircularProgressIndicator()))),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/consent', builder: (_, _) => const ConsentScreen()),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => HomeShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/cards',
              builder: (_, _) => const PlaceholderScreen(
                title: '오늘의 카드',
                message: '오늘 밤 10시,\n첫 카드 여덟 장이 도착해요.',
              ),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/chats',
              builder: (_, _) => const PlaceholderScreen(
                title: '대화',
                message: '서로 마음이 닿으면\n여기에 대화가 열려요.',
              ),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/me',
              builder: (_, _) => const MeScreen(),
              routes: [GoRoute(path: 'photos', builder: (_, _) => const MyPhotosScreen())],
            ),
          ]),
        ],
      ),
    ],
  );
});

class SangsangApp extends ConsumerWidget {
  const SangsangApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: '상상',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
