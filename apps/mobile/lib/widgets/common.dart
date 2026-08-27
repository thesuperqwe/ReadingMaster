import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.color = AppColors.surface,
    this.radius = 20,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Padding(padding: padding, child: child);
    final decoration = BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: AppColors.line),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: Ink(
          decoration: decoration,
          child: content,
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.trailing, this.subtitle});

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: const TextStyle(fontSize: 13, color: AppColors.inkSoft),
                ),
              ],
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

String levelLabel(String level) {
  switch (level) {
    case 'LEVEL_1':
      return 'Level 1';
    case 'LEVEL_2':
      return 'Level 2';
    case 'LEVEL_3':
      return 'Level 3';
    case 'LEVEL_4':
      return 'Level 4';
    default:
      return 'Level';
  }
}

Color levelColor(String level) {
  switch (level) {
    case 'LEVEL_1':
      return const Color(0xFF8FC98F);
    case 'LEVEL_2':
      return AppColors.primary;
    case 'LEVEL_3':
      return const Color(0xFF5BA8C9);
    case 'LEVEL_4':
      return const Color(0xFFE0A64C);
    default:
      return AppColors.primary;
  }
}

class LevelBadge extends StatelessWidget {
  const LevelBadge(this.level, {super.key, this.filled = false});

  final String level;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final color = levelColor(level);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: filled ? color : color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        levelLabel(level),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: filled ? Colors.white : color,
        ),
      ),
    );
  }
}

class StarRow extends StatelessWidget {
  const StarRow({super.key, this.count = 5, this.size = 14});

  final int count;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        count.clamp(0, 5),
        (index) => Icon(
          Icons.star_rounded,
          size: size,
          color: AppColors.gold,
        ),
      ),
    );
  }
}

String coverEmojiFor(String title, String? category, String? description) {
  final text = '$title ${category ?? ''} ${description ?? ''}'.toLowerCase();
  if (text.contains('dog') || text.contains('pup') || text.contains('小狗')) return '🐕';
  if (text.contains('cat') || text.contains('小猫')) return '🐈';
  if (text.contains('school') || text.contains('学校')) return '🏫';
  if (text.contains('park') || text.contains('tree') || text.contains('森林')) return '🌳';
  if (text.contains('family') || text.contains('家人')) return '👪';
  if (text.contains('farm') || text.contains('农场')) return '🐄';
  if (text.contains('sea') || text.contains('fish') || text.contains('海洋')) return '🐠';
  if (text.contains('space') || text.contains('太空')) return '🚀';
  return '📖';
}

class BookCover extends StatelessWidget {
  const BookCover({
    super.key,
    required this.title,
    this.category,
    this.description,
    this.level,
    this.height,
    this.width,
  });

  final String title;
  final String? category;
  final String? description;
  final String? level;
  final double? height;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final emoji = coverEmojiFor(title, category, description);
    final color = level == null ? AppColors.leaf : levelColor(level!);

    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withValues(alpha: 0.9), color.withValues(alpha: 0.72)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          Align(
            alignment: const Alignment(0, -0.25),
            child: Text(
              emoji,
              style: const TextStyle(fontSize: 46),
            ),
          ),
          Align(
            alignment: const Alignment(0, 0.72),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
            ),
          ),
          if (level != null)
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  levelLabel(level!),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: levelColor(level!),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class StatPill extends StatelessWidget {
  const StatPill({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.accent = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: accent ? AppColors.gold.withValues(alpha: 0.16) : AppColors.primarySoft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: accent ? AppColors.gold : AppColors.primaryDark),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: AppColors.inkSoft),
            ),
          ],
        ),
      ],
    );
  }
}

class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.light = false});

  final bool light;

  @override
  Widget build(BuildContext context) {
    final inkColor = light ? Colors.white : AppColors.ink;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: light ? Colors.white.withValues(alpha: 0.2) : AppColors.primary,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.menu_book_rounded, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '阅读王',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: inkColor,
                height: 1.1,
              ),
            ),
            Text(
              'ReadingMaster',
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 0.5,
                color: light ? Colors.white70 : AppColors.inkSoft,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
