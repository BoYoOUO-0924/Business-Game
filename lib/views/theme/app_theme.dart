import 'package:flutter/material.dart';

/// 全 App 共用的設計語彙（溫暖復古街角超商 Tycoon 主題）。
class AppColors {
  // 版面層次 (暖焙黑巧克力木質調)
  static const page = Color(0xFF141218);
  static const surface = Color(0xFF1F1D26);
  static const surfaceAlt = Color(0xFF2A2735);
  static const surfaceHigh = Color(0xFF383446);
  static const border = Color(0xFF3D384D);

  // 文字
  static const textPrimary = Color(0xFFFDF8F0);
  static const textSecondary = Color(0xFFC4BDD4);
  static const textMuted = Color(0xFF867E96);

  // 品牌與強調 (超商經典暖金、招牌綠、元氣橘)
  static const accent = Color(0xFFFFB800); // 暖金幣黃
  static const accentSoft = Color(0xFFFDE68A);
  static const storeGreen = Color(0xFF10B981); // 超商活力綠
  static const storeOrange = Color(0xFFFF7A00); // 元氣橘
  static const storeRed = Color(0xFFEF4444); // 招牌鮮紅

  // 狀態 (固定語意)
  static const good = Color(0xFF10B981);
  static const warning = Color(0xFFFFB800);
  static const serious = Color(0xFFF97316);
  static const critical = Color(0xFFEF4444);

  // 圖表序列
  static const series1 = Color(0xFFFFB800); // 金
  static const series2 = Color(0xFFFF7A00); // 橘
  static const series3 = Color(0xFF10B981); // 綠
  static const seriesNegative = Color(0xFFEF4444); // 紅（虧損側）

  // 圖表骨架
  static const gridline = Color(0xFF2E2B3B);
  static const axis = Color(0xFF454054);

  /// 依商譽分數給色
  static Color forReputation(int rep) {
    if (rep >= 80) return good;
    if (rep >= 60) return accent;
    if (rep >= 40) return warning;
    return critical;
  }

  /// 依金額正負給色
  static Color forAmount(double v) => v >= 0 ? good : critical;
}

class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

class AppText {
  static const hero = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.1,
  );
  static const title = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );
  static const sectionTitle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: 0.3,
  );
  static const body = TextStyle(
    fontSize: 13,
    color: AppColors.textSecondary,
    height: 1.45,
  );
  static const label = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
    letterSpacing: 0.2,
  );
  static const caption = TextStyle(
    fontSize: 11,
    color: AppColors.textMuted,
    height: 1.4,
  );

  /// 需要縱向對齊的數字（表格、座標軸刻度）
  static const tabular = TextStyle(
    fontSize: 12,
    color: AppColors.textSecondary,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}

ThemeData buildAppTheme() {
  const fontFallbacks = [
    'Microsoft JhengHei',
    'Microsoft YaHei',
    'PingFang SC',
    'Segoe UI Emoji',
    'Noto Sans TC',
    'sans-serif',
  ];

  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.page,
    fontFamilyFallback: fontFallbacks,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.accent,
      secondary: AppColors.good,
      surface: AppColors.surface,
      error: AppColors.critical,
      onPrimary: Colors.black,
      onSurface: AppColors.textPrimary,
    ),
  );

  return base.copyWith(
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border, width: 1.2),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.border,
      thickness: 1,
      space: 1,
    ),
    textTheme: base.textTheme.apply(
      fontFamilyFallback: fontFallbacks,
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    ),
    tooltipTheme: const TooltipThemeData(
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.all(Radius.circular(8)),
        border: Border.fromBorderSide(BorderSide(color: AppColors.border)),
      ),
      textStyle: TextStyle(fontSize: 12, color: AppColors.textPrimary),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.black,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      elevation: 4,
      indicatorColor: AppColors.accent.withValues(alpha: 0.22),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontSize: 11,
          fontWeight: selected ? FontWeight.bold : FontWeight.w500,
          color: selected ? AppColors.accent : AppColors.textMuted,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          size: 22,
          color: selected ? AppColors.accent : AppColors.textMuted,
        );
      }),
    ),
  );
}
