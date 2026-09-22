import 'package:flutter/material.dart';

/// 全 App 共用的設計語彙。
///
/// 舊版每個分頁各自硬寫 `Color(0xFF1E293B)`、`Colors.cyanAccent`，
/// 同一種東西在五個分頁有五種樣子。這裡把顏色、間距、字級收斂成單一來源。
///
/// 圖表色取自已驗證的類別調色盤（深色模式階），並實測過本 App 表面色的
/// 對比度：blue 4.68、orange 4.38、red 5.27，皆高於 3:1 門檻。
class AppColors {
  // 版面層次
  static const page = Color(0xFF0B1220);
  static const surface = Color(0xFF131C2E);
  static const surfaceAlt = Color(0xFF1B2740);
  static const surfaceHigh = Color(0xFF243453);
  static const border = Color(0xFF253148);

  // 文字
  static const textPrimary = Color(0xFFE8EDF7);
  static const textSecondary = Color(0xFF94A3B8);
  static const textMuted = Color(0xFF6B7C93);

  // 品牌強調
  static const accent = Color(0xFF3987E5);
  static const accentSoft = Color(0xFF86B6EF);

  // 狀態（固定語意，不得拿來當第 N 個資料序列）
  static const good = Color(0xFF0CA30C);
  static const warning = Color(0xFFFAB219);
  static const serious = Color(0xFFEC835A);
  static const critical = Color(0xFFD03B3B);

  // 圖表序列（固定順序，不循環）
  static const series1 = Color(0xFF3987E5); // 藍
  static const series2 = Color(0xFFD95926); // 橘
  static const series3 = Color(0xFF199E70); // 青
  static const seriesNegative = Color(0xFFE66767); // 紅（虧損側）

  // 圖表骨架
  static const gridline = Color(0xFF1F2B42);
  static const axis = Color(0xFF32415C);

  /// 依商譽分數給色（狀態語意，永遠搭配數字與標籤）
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
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.page,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.accent,
      secondary: AppColors.series3,
      surface: AppColors.surface,
      error: AppColors.critical,
      onPrimary: Colors.white,
      onSurface: AppColors.textPrimary,
    ),
  );

  return base.copyWith(
    cardTheme: const CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.border,
      thickness: 1,
      space: 1,
    ),
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    ),
    tooltipTheme: const TooltipThemeData(
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.all(Radius.circular(6)),
      ),
      textStyle: TextStyle(fontSize: 12, color: AppColors.textPrimary),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.accent.withValues(alpha: 0.18),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontSize: 11,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? AppColors.textPrimary : AppColors.textMuted,
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
