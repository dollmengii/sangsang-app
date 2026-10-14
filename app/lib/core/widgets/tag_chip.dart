import 'package:flutter/material.dart';

import '../theme.dart';

/// #강아지상 같은 태그. strong이면 장밋빛으로 채운다.
class TagChip extends StatelessWidget {
  const TagChip(this.label, {super.key, this.strong = false, this.onDark = false});

  final String label;
  final bool strong;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final fg = onDark ? Colors.white : (strong ? c.rose : c.muted);
    final bg = onDark
        ? Colors.white.withValues(alpha: strong ? 0.22 : 0.12)
        : (strong ? c.rose.withValues(alpha: 0.12) : Colors.transparent);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(99),
        border: strong || onDark ? null : Border.all(color: c.line),
      ),
      child: Text('#$label', style: TextStyle(color: fg, fontSize: 13, fontWeight: strong ? FontWeight.w500 : FontWeight.w400)),
    );
  }
}

/// 고를 수 있는 태그.
class SelectTag extends StatelessWidget {
  const SelectTag({super.key, required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? c.rose : c.surface,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: selected ? c.rose : c.line),
        ),
        child: Text(label,
            style: TextStyle(
              color: selected ? Theme.of(context).colorScheme.onPrimary : (onTap == null ? c.line : c.ink),
              fontSize: 14,
            )),
      ),
    );
  }
}
