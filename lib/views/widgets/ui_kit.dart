import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// 有標題的區塊卡片 —— 全 App 的基本排版單位
class SectionCard extends StatelessWidget {
  final String title;
  final IconData? icon;
  final Widget? trailing;
  final String? subtitle;
  final Widget child;
  final EdgeInsets padding;

  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.icon,
    this.trailing,
    this.subtitle,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 15, color: AppColors.textSecondary),
                const SizedBox(width: AppSpacing.sm),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppText.sectionTitle),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!, style: AppText.caption),
                    ],
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

/// 單一指標磚。數字是主角，標籤與變化量是配角。
class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final String? delta;
  final Color? deltaColor;
  final IconData? icon;
  final Color? accent;
  final String? hint;

  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.delta,
    this.deltaColor,
    this.icon,
    this.accent,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 13, color: accent ?? AppColors.textMuted),
                const SizedBox(width: AppSpacing.xs),
              ],
              Expanded(
                child: Text(label, style: AppText.label, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: accent ?? AppColors.textPrimary,
                height: 1.1,
              ),
            ),
          ),
          if (delta != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              delta!,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: deltaColor ?? AppColors.textMuted,
              ),
            ),
          ],
          if (hint != null) ...[
            const SizedBox(height: 2),
            Flexible(
              child: Text(hint!,
                  style: AppText.caption,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ],
      ),
    );
  }
}

/// 小標籤
class Pill extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;
  final bool filled;

  const Pill(this.text, {super.key, this.color = AppColors.textMuted, this.icon, this.filled = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: filled ? color.withValues(alpha: 0.18) : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: filled ? 0.35 : 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}

/// 進度條（含標籤與數值）
class LabeledProgress extends StatelessWidget {
  final String label;
  final String value;
  final double progress; // 0..1
  final Color color;
  final String? note;

  const LabeledProgress({
    super.key,
    required this.label,
    required this.value,
    required this.progress,
    this.color = AppColors.accent,
    this.note,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label,
                  style: AppText.body.copyWith(color: AppColors.textPrimary),
                  overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(value, style: AppText.tabular.copyWith(fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: AppColors.surfaceHigh,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
        if (note != null) ...[
          const SizedBox(height: 4),
          Text(note!, style: AppText.caption),
        ],
      ],
    );
  }
}

/// 警示橫幅。狀態色一律搭配圖示與文字，不靠顏色單獨傳達。
class AlertBanner extends StatelessWidget {
  final String title;
  final String message;
  final Color color;
  final IconData icon;
  final Widget? action;

  const AlertBanner({
    super.key,
    required this.title,
    required this.message,
    required this.color,
    required this.icon,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700, color: color)),
                const SizedBox(height: 3),
                Text(message, style: AppText.body),
              ],
            ),
          ),
          if (action != null) ...[
            const SizedBox(width: AppSpacing.md),
            action!,
          ],
        ],
      ),
    );
  }
}

/// 圖例項目（>= 2 序列時一律出現）
class LegendDot extends StatelessWidget {
  final String label;
  final Color color;
  const LegendDot(this.label, this.color, {super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 6),
        // 文字用文字色，不用序列色 —— 身分由旁邊的色塊承載
        Text(label, style: AppText.caption.copyWith(color: AppColors.textSecondary)),
      ],
    );
  }
}

/// 空狀態
class EmptyHint extends StatelessWidget {
  final IconData icon;
  final String message;
  const EmptyHint({super.key, required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: Column(
        children: [
          Icon(icon, size: 28, color: AppColors.textMuted),
          const SizedBox(height: AppSpacing.sm),
          Text(message, style: AppText.caption, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

/// 一列鍵值
class KeyValueRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool emphasize;

  const KeyValueRow(this.label, this.value,
      {super.key, this.valueColor, this.emphasize = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: emphasize
                    ? AppText.body.copyWith(
                        color: AppColors.textPrimary, fontWeight: FontWeight.w700)
                    : AppText.body),
          ),
          Text(
            value,
            style: AppText.tabular.copyWith(
              fontSize: emphasize ? 14 : 12,
              fontWeight: emphasize ? FontWeight.w700 : FontWeight.w600,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
