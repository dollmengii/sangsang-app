import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 하단 탭: 오늘의 카드, 대화, 내 프로필.
class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.style_outlined), label: '오늘의 카드'),
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline), label: '대화'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: '나'),
        ],
      ),
    );
  }
}

/// 아직 만들지 않은 화면 자리.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key, required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(message, textAlign: TextAlign.center),
        ),
      ),
    );
  }
}
