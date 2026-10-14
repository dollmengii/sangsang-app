import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme.dart';

/// 해 질 녘 하늘처럼 번진 색 덩어리. 로그인처럼 비어 있는 화면의 배경.
class DuskBackground extends StatelessWidget {
  const DuskBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: c.paper),
        ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60, tileMode: TileMode.decal),
          child: Stack(
            children: [
              _blob(const Alignment(-1.1, -0.9), 320, c.glow.withValues(alpha: 0.75)),
              _blob(const Alignment(1.2, -0.3), 280, c.dusk.withValues(alpha: 0.35)),
              _blob(const Alignment(-0.4, 0.5), 240, c.rose.withValues(alpha: 0.28)),
            ],
          ),
        ),
        child,
      ],
    );
  }

  Widget _blob(Alignment at, double size, Color color) => Align(
        alignment: at,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      );
}
