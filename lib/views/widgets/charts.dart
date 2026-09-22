import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'ui_kit.dart';

/// 一小時的營運預測
class HourSlice {
  final int hour;
  final int footfall; // 這小時會上門的人流
  final int capacity; // 這小時結得完的上限
  final bool isOpen; // 是否有人值班
  final bool isNow;

  const HourSlice({
    required this.hour,
    required this.footfall,
    required this.capacity,
    required this.isOpen,
    this.isNow = false,
  });

  int get served => isOpen ? min(footfall, capacity) : 0;
  int get lost => isOpen ? max(0, footfall - capacity) : 0;
}

/// 24 小時人流 vs 結帳產能對照圖。
///
/// 這張圖是整個排班機制的說明書：每根長條是該時段的人流，
/// 藍色是結得完的部分、橘色是人力不足會流失的部分，打烊時段標灰。
/// 玩家一眼就能看出「哪幾個小時該加人」——舊版完全沒有這個資訊。
class ShiftCoverageChart extends StatefulWidget {
  final List<HourSlice> slices;
  const ShiftCoverageChart({super.key, required this.slices});

  @override
  State<ShiftCoverageChart> createState() => _ShiftCoverageChartState();
}

class _ShiftCoverageChartState extends State<ShiftCoverageChart> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final slices = widget.slices;
    final maxV = slices.fold<int>(1, (a, s) => max(a, max(s.footfall, s.capacity)));
    final totalLost = slices.fold<int>(0, (a, s) => a + s.lost);
    final detail = _selected != null && _selected! < slices.length ? slices[_selected!] : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const LegendDot('可服務來客', AppColors.series1),
            const SizedBox(width: AppSpacing.md),
            const LegendDot('人力不足流失', AppColors.series2),
            const SizedBox(width: AppSpacing.md),
            const LegendDot('打烊', AppColors.surfaceHigh),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        LayoutBuilder(
          builder: (context, constraints) {
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) {
                final w = constraints.maxWidth;
                final idx = (d.localPosition.dx / (w / slices.length)).floor();
                setState(() =>
                    _selected = (idx >= 0 && idx < slices.length) ? idx : null);
              },
              child: CustomPaint(
                size: Size(constraints.maxWidth, 128),
                painter: _CoveragePainter(slices, maxV, _selected),
              ),
            );
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        // 資料表替代呈現：選中時段的明細，讓資訊不只靠顏色傳達
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(8),
          ),
          child: detail == null
              ? Text(
                  totalLost > 0
                      ? '今日預估將有 $totalLost 位客人因結帳人力不足而流失 · 點選長條查看各時段明細'
                      : '目前班表可消化全日人流 · 點選長條查看各時段明細',
                  style: AppText.caption,
                )
              : Row(
                  children: [
                    Text('${detail.hour.toString().padLeft(2, '0')}:00',
                        style: AppText.tabular.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        detail.isOpen
                            ? '人流 ${detail.footfall} 人 · 結帳上限 ${detail.capacity} 人'
                                '${detail.lost > 0 ? ' · 流失 ${detail.lost} 人' : ' · 綽綽有餘'}'
                            : '無人值班，門市此時段打烊',
                        style: AppText.caption.copyWith(
                          color: detail.lost > 0
                              ? AppColors.serious
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _CoveragePainter extends CustomPainter {
  final List<HourSlice> slices;
  final int maxValue;
  final int? selected;

  _CoveragePainter(this.slices, this.maxValue, this.selected);

  @override
  void paint(Canvas canvas, Size size) {
    const labelH = 16.0;
    final plotH = size.height - labelH;
    final slotW = size.width / slices.length;
    const gap = 2.0; // 相鄰長條之間的表面間隙
    final barW = max(3.0, slotW - gap * 2);

    // 退到背景的格線
    final grid = Paint()
      ..color = AppColors.gridline
      ..strokeWidth = 1;
    for (var i = 0; i <= 2; i++) {
      final y = plotH - plotH * (i / 2);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    for (var i = 0; i < slices.length; i++) {
      final s = slices[i];
      final x = slotW * i + (slotW - barW) / 2;
      final isSel = selected == i;

      if (!s.isOpen) {
        // 打烊：畫一截矮而灰的底座，表示「這時段沒有營業」
        final h = max(3.0, plotH * (s.footfall / maxValue) * 0.18);
        _bar(canvas, x, plotH - h, barW, h, AppColors.surfaceHigh);
      } else {
        final servedH = plotH * (s.served / maxValue);
        final lostH = plotH * (s.lost / maxValue);

        if (servedH > 0) {
          _bar(canvas, x, plotH - servedH, barW, servedH, AppColors.series1);
        }
        if (lostH > 0) {
          // 堆疊段之間留 2px 表面間隙
          final top = plotH - servedH - gap - lostH;
          _bar(canvas, x, top, barW, lostH, AppColors.series2);
        }
      }

      if (isSel) {
        canvas.drawRect(
          Rect.fromLTWH(x - 1, 0, barW + 2, plotH),
          Paint()
            ..color = AppColors.textPrimary.withValues(alpha: 0.10)
            ..style = PaintingStyle.fill,
        );
      }

      // 目前時刻標記
      if (s.isNow) {
        canvas.drawLine(
          Offset(x + barW / 2, 0),
          Offset(x + barW / 2, plotH),
          Paint()
            ..color = AppColors.accentSoft.withValues(alpha: 0.7)
            ..strokeWidth = 1.5,
        );
      }

      // 每 3 小時一個刻度，避免標籤打架
      if (s.hour % 3 == 0) {
        final tp = TextPainter(
          text: TextSpan(
            text: s.hour.toString().padLeft(2, '0'),
            style: const TextStyle(fontSize: 9, color: AppColors.textMuted),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x + barW / 2 - tp.width / 2, plotH + 4));
      }
    }

    // 基線
    canvas.drawLine(
      Offset(0, plotH),
      Offset(size.width, plotH),
      Paint()
        ..color = AppColors.axis
        ..strokeWidth = 1,
    );

    // 量級刻度：標出上緣人數，讓長條高度有比例尺可讀
    final scaleLabel = TextPainter(
      text: TextSpan(
        text: '$maxValue 人/小時',
        style: const TextStyle(fontSize: 9, color: AppColors.textMuted),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    scaleLabel.paint(canvas, const Offset(0, 0));
  }

  /// 資料端 4px 圓角，錨在基線側
  void _bar(Canvas canvas, double x, double y, double w, double h, Color color) {
    final r = min(4.0, w / 2);
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(x, y, w, h),
        topLeft: Radius.circular(r),
        topRight: Radius.circular(r),
      ),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_CoveragePainter old) =>
      old.selected != selected || old.maxValue != maxValue || old.slices != slices;
}

/// 近 7 日單序列長條圖。
/// 淨利模式下以零為基準雙向發散（藍=獲利／紅=虧損）。
class TrendBars extends StatelessWidget {
  final List<double> values;
  final bool diverging;
  final String Function(double) formatValue;

  const TrendBars({
    super.key,
    required this.values,
    required this.formatValue,
    this.diverging = false,
  });

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) {
      return const EmptyHint(icon: Icons.show_chart_rounded, message: '還沒有營業紀錄，先推進一天看看');
    }
    return LayoutBuilder(
      builder: (context, c) => CustomPaint(
        size: Size(c.maxWidth, 92),
        painter: _TrendPainter(values, diverging, formatValue),
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  final List<double> values;
  final bool diverging;
  final String Function(double) fmt;

  _TrendPainter(this.values, this.diverging, this.fmt);

  @override
  void paint(Canvas canvas, Size size) {
    const labelH = 15.0;
    final plotH = size.height - labelH;
    final slotW = size.width / values.length;
    const gap = 3.0;
    final barW = max(6.0, slotW - gap * 2);

    final maxAbs = values.fold<double>(1, (a, v) => max(a, v.abs()));
    // 發散模式：零線置中；單向模式：零線在底部
    final zeroY = diverging ? plotH / 2 : plotH;
    final scale = diverging ? (plotH / 2) / maxAbs : plotH / maxAbs;

    // 零線／基線
    canvas.drawLine(
      Offset(0, zeroY),
      Offset(size.width, zeroY),
      Paint()
        ..color = AppColors.axis
        ..strokeWidth = 1,
    );

    for (var i = 0; i < values.length; i++) {
      final v = values[i];
      final x = slotW * i + (slotW - barW) / 2;
      final h = (v.abs() * scale).clamp(2.0, plotH);
      final isNeg = v < 0;
      final color = diverging
          ? (isNeg ? AppColors.seriesNegative : AppColors.series1)
          : AppColors.series1;

      final r = min(4.0, barW / 2);
      final rect = isNeg
          ? RRect.fromRectAndCorners(
              Rect.fromLTWH(x, zeroY, barW, h),
              bottomLeft: Radius.circular(r),
              bottomRight: Radius.circular(r),
            )
          : RRect.fromRectAndCorners(
              Rect.fromLTWH(x, zeroY - h, barW, h),
              topLeft: Radius.circular(r),
              topRight: Radius.circular(r),
            );
      canvas.drawRRect(rect, Paint()..color = color);

      // 只直接標示最後一根（最新一天），不是每根都掛數字
      if (i == values.length - 1) {
        final tp = TextPainter(
          text: TextSpan(
            text: fmt(v),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final ty = isNeg ? zeroY + h + 2 : zeroY - h - tp.height - 2;
        tp.paint(
          canvas,
          Offset(
            (x + barW / 2 - tp.width / 2).clamp(0.0, size.width - tp.width),
            ty.clamp(0.0, plotH - tp.height),
          ),
        );
      }
    }

    // 座標軸：只標最舊與最新
    final oldest = TextPainter(
      text: TextSpan(
          text: '${values.length} 天前',
          style: const TextStyle(fontSize: 9, color: AppColors.textMuted)),
      textDirection: TextDirection.ltr,
    )..layout();
    oldest.paint(canvas, Offset(0, plotH + 3));

    final latest = TextPainter(
      text: const TextSpan(
          text: '昨日', style: TextStyle(fontSize: 9, color: AppColors.textMuted)),
      textDirection: TextDirection.ltr,
    )..layout();
    latest.paint(canvas, Offset(size.width - latest.width, plotH + 3));
  }

  @override
  bool shouldRepaint(_TrendPainter old) =>
      old.values != values || old.diverging != diverging;
}
