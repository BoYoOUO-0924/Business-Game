import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/inventory_item.dart';
import '../../providers/game_state.dart';
import '../theme/app_theme.dart';
import '../widgets/charts.dart';
import '../widgets/ui_kit.dart';

/// 營運總覽 —— 玩家的指揮台。
///
/// 資訊架構由上而下：現在怎麼了（警示）→ 今天賺多少（KPI + 損益）
/// → 人流撐不撐得住（班表覆蓋圖）→ 長期走勢 → 主線進度 → 營運日誌。
class OverviewTab extends StatelessWidget {
  final void Function(int index) onNavigateTab;
  const OverviewTab({super.key, required this.onNavigateTab});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GameState>();
    final currency = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl),
      children: [
        _Alerts(state: state, onNavigateTab: onNavigateTab),
        _KpiGrid(state: state, currency: currency),
        const SizedBox(height: AppSpacing.lg),
        _TodayPnl(state: state, currency: currency),
        const SizedBox(height: AppSpacing.lg),
        _CoverageSection(state: state, onNavigateTab: onNavigateTab),
        const SizedBox(height: AppSpacing.lg),
        _TrendSection(state: state, currency: currency),
        const SizedBox(height: AppSpacing.lg),
        _ChapterSection(state: state, onNavigateTab: onNavigateTab),
        const SizedBox(height: AppSpacing.lg),
        _LogSection(state: state),
      ],
    );
  }
}

// ─────────────────────────────── 警示 ───────────────────────────────

class _Alerts extends StatelessWidget {
  final GameState state;
  final void Function(int) onNavigateTab;
  const _Alerts({required this.state, required this.onNavigateTab});

  @override
  Widget build(BuildContext context) {
    final alerts = <Widget>[];

    if (state.isBankrupt) {
      alerts.add(const AlertBanner(
        title: '門市已歇業',
        message: '連續 3 天週轉不靈，房東收回店面。可從上方選單重新開店。',
        color: AppColors.critical,
        icon: Icons.dangerous_rounded,
      ));
    } else if (state.company.cash < 0) {
      alerts.add(AlertBanner(
        title: '現金為負，瀕臨倒閉',
        message: '還剩 ${3 - state.consecutiveInsolventDays} 天可以挽救。'
            '立刻減班降低工資、或調高售價改善毛利。',
        color: AppColors.critical,
        icon: Icons.warning_rounded,
        action: FilledButton(
          onPressed: () => onNavigateTab(3),
          child: const Text('調整班表'),
        ),
      ));
    }

    final low = state.lowStockItems;
    if (low.isNotEmpty && !state.isBankrupt) {
      alerts.add(AlertBanner(
        title: '${low.length} 項商品即將缺貨',
        message: '${low.take(3).map((i) => i.name).join('、')}'
            '${low.length > 3 ? ' 等' : ''} 撐不到 4 小時。缺貨的客人會直接掉頭走人。',
        color: AppColors.warning,
        icon: Icons.inventory_2_rounded,
        action: FilledButton(
          onPressed: () => state.restockAllToCapacity(),
          child: const Text('一鍵補貨'),
        ),
      ));
    }

    final uncovered = List.generate(24, (h) => h)
        .where((h) => state.onDutyStaff(h).isEmpty)
        .length;
    if (uncovered >= 8 && !state.isBankrupt) {
      alerts.add(AlertBanner(
        title: '每天有 $uncovered 小時是打烊狀態',
        message: '沒人值班的時段不會有營收。補上大夜班可以把營業時間拉長到 24 小時。',
        color: AppColors.accent,
        icon: Icons.schedule_rounded,
        action: OutlinedButton(
          onPressed: () => onNavigateTab(3),
          child: const Text('去排班'),
        ),
      ));
    }

    if (state.activeEvent != null) {
      final e = state.activeEvent!;
      final boost = e.trafficMultiplier >= 1.0;
      alerts.add(AlertBanner(
        title: '${e.icon} ${e.title}（剩 ${e.hoursRemaining} 小時）',
        message: e.description,
        color: boost ? AppColors.good : AppColors.serious,
        icon: boost ? Icons.trending_up_rounded : Icons.trending_down_rounded,
      ));
    }

    if (alerts.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        for (final a in alerts) ...[a, const SizedBox(height: AppSpacing.md)],
      ],
    );
  }
}

// ─────────────────────────────── KPI ───────────────────────────────

class _KpiGrid extends StatelessWidget {
  final GameState state;
  final NumberFormat currency;
  const _KpiGrid({required this.state, required this.currency});

  @override
  Widget build(BuildContext context) {
    final c = state.company;
    final net = c.dailyNetProfit;
    final serviceRate = c.dailyServiceRate;

    final tiles = [
      StatTile(
        label: '現金',
        value: currency.format(c.cash),
        icon: Icons.account_balance_wallet_rounded,
        accent: c.cash < 0 ? AppColors.critical : AppColors.textPrimary,
        hint: '每日固定開銷 ${currency.format(state.projectedDailyFixedCost)}',
      ),
      StatTile(
        label: '今日淨利',
        value: currency.format(net),
        icon: Icons.trending_up_rounded,
        accent: AppColors.forAmount(net),
        hint: '營收 ${currency.format(c.dailyRevenue)}',
      ),
      StatTile(
        label: '門市商譽',
        value: '${c.reputation}',
        icon: Icons.star_rounded,
        accent: AppColors.forReputation(c.reputation),
        delta: _reputationLabel(c.reputation),
        deltaColor: AppColors.forReputation(c.reputation),
        hint: '決定每小時上門的人流',
      ),
      StatTile(
        label: '服務達成率',
        value: '${(serviceRate * 100).toStringAsFixed(0)}%',
        icon: Icons.groups_rounded,
        accent: serviceRate >= 0.9
            ? AppColors.good
            : (serviceRate >= 0.75 ? AppColors.warning : AppColors.critical),
        hint: '接客 ${c.dailyCustomersServed} 人 · 流失 ${c.dailyCustomersLost} 人',
      ),
    ];

    // 用固定高度而非長寬比：磚的內容高度是固定的，
    // 用 aspect ratio 會在寬螢幕下把卡片拉出一大片空白。
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth > 620 ? 4 : 2;
        final rows = <Widget>[];
        for (var i = 0; i < tiles.length; i += cols) {
          final slice = tiles.sublist(i, (i + cols).clamp(0, tiles.length));
          rows.add(SizedBox(
            height: 112,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var j = 0; j < slice.length; j++) ...[
                  if (j > 0) const SizedBox(width: AppSpacing.md),
                  Expanded(child: slice[j]),
                ],
              ],
            ),
          ));
          if (i + cols < tiles.length) {
            rows.add(const SizedBox(height: AppSpacing.md));
          }
        }
        return Column(children: rows);
      },
    );
  }

  static String _reputationLabel(int rep) {
    if (rep >= 85) return '五星名店';
    if (rep >= 70) return '口碑良好';
    if (rep >= 50) return '普通';
    if (rep >= 30) return '評價低落';
    return '乏人問津';
  }
}

// ─────────────────────────── 今日損益 ───────────────────────────

class _TodayPnl extends StatelessWidget {
  final GameState state;
  final NumberFormat currency;
  const _TodayPnl({required this.state, required this.currency});

  @override
  Widget build(BuildContext context) {
    final c = state.company;
    final net = c.dailyNetProfit;

    return SectionCard(
      title: '今日損益',
      icon: Icons.receipt_long_rounded,
      subtitle: '第 ${c.day} 天 · 已營業 ${c.dailyOpenHours} 小時',
      trailing: Pill(
        net >= 0 ? '獲利中' : '虧損中',
        color: AppColors.forAmount(net),
        icon: net >= 0 ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
        filled: true,
      ),
      child: Column(
        children: [
          KeyValueRow('營業收入', currency.format(c.dailyRevenue),
              valueColor: AppColors.good),
          const Divider(height: AppSpacing.lg),
          KeyValueRow('進貨成本', '−${currency.format(c.dailyExpenses)}'),
          KeyValueRow('員工工資', '−${currency.format(c.dailyWages)}'),
          KeyValueRow('鮮食報廢', '−${currency.format(c.dailySpoilageCost)}',
              valueColor: c.dailySpoilageCost > 0 ? AppColors.serious : null),
          KeyValueRow('門市租金', '−${currency.format(c.dailyRent)}'),
          const Divider(height: AppSpacing.lg),
          KeyValueRow('淨利', currency.format(net),
              valueColor: AppColors.forAmount(net), emphasize: true),
          if (c.dailyCustomersServed > 0) ...[
            const SizedBox(height: AppSpacing.sm),
            Text('客單價 ${currency.format(c.averageTicket)}',
                style: AppText.caption),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────── 班表覆蓋（核心新視覺） ───────────────────────

class _CoverageSection extends StatelessWidget {
  final GameState state;
  final void Function(int) onNavigateTab;
  const _CoverageSection({required this.state, required this.onNavigateTab});

  @override
  Widget build(BuildContext context) {
    final slices = [
      for (var h = 0; h < 24; h++)
        HourSlice(
          hour: h,
          footfall: state.projectedFootfall(h),
          capacity: state.checkoutCapacity(h).floor(),
          isOpen: state.onDutyStaff(h).isNotEmpty,
          isNow: h == state.company.hour,
        ),
    ];

    return SectionCard(
      title: '24 小時人流與結帳產能',
      icon: Icons.bar_chart_rounded,
      subtitle: '人流由商譽與時段決定；產能由當班人手決定',
      trailing: OutlinedButton(
        onPressed: () => onNavigateTab(3),
        child: const Text('排班'),
      ),
      child: ShiftCoverageChart(slices: slices),
    );
  }
}

// ─────────────────────────── 近期走勢 ───────────────────────────

class _TrendSection extends StatelessWidget {
  final GameState state;
  final NumberFormat currency;
  const _TrendSection({required this.state, required this.currency});

  @override
  Widget build(BuildContext context) {
    final rev = state.company.revenueHistory;
    final net = state.company.netProfitHistory;
    final compact = NumberFormat.compactCurrency(symbol: '\$', decimalDigits: 0);

    // 兩個量級不同的指標 → 兩張各自獨立的圖，不共用雙軸
    return Column(
      children: [
        SectionCard(
          title: '每日營業額',
          icon: Icons.show_chart_rounded,
          subtitle: rev.isEmpty ? null : '近 ${rev.length} 天',
          child: TrendBars(values: rev, formatValue: (v) => compact.format(v)),
        ),
        const SizedBox(height: AppSpacing.lg),
        SectionCard(
          title: '每日淨利',
          icon: Icons.stacked_line_chart_rounded,
          subtitle: '以零為基準：向上獲利、向下虧損',
          child: TrendBars(
            values: net,
            diverging: true,
            formatValue: (v) => compact.format(v),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────── 主線進度 ───────────────────────────

class _ChapterSection extends StatelessWidget {
  final GameState state;
  final void Function(int) onNavigateTab;
  const _ChapterSection({required this.state, required this.onNavigateTab});

  double _current(String metric, GameState s) {
    switch (metric) {
      case 'customers_served':
        return s.totalCustomersServed.toDouble();
      case 'revenue':
        return s.company.totalRevenue;
      case 'cash':
        return s.company.cash;
      case 'daily_revenue':
        return s.company.dailyRevenue;
      case 'reputation':
        return s.company.reputation.toDouble();
      case 'hired_staff':
        return s.hiredStaff.length.toDouble();
      case 'units_sold':
        return s.company.totalUnitsSold.toDouble();
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ch = state.currentChapter;
    final num = NumberFormat.decimalPattern();

    return SectionCard(
      title: ch.title,
      icon: Icons.flag_rounded,
      subtitle: ch.subtitle,
      trailing: ch.isCompleted && !ch.isClaimed
          ? FilledButton(
              onPressed: () => state.claimChapterReward(ch.chapterNumber),
              child: const Text('領取獎勵'),
            )
          : Pill('第 ${ch.chapterNumber} / ${state.chapters.length} 章',
              color: AppColors.accent),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(ch.storyIntro, style: AppText.body),
          const SizedBox(height: AppSpacing.lg),
          for (final g in ch.goals) ...[
            LabeledProgress(
              label: g.isAchieved ? '✓ ${g.title}' : g.title,
              value: g.metricType == 'fixture_purchased'
                  ? (g.isAchieved ? '已完成' : '未完成')
                  : '${num.format(_current(g.metricType, state).clamp(0, g.targetValue).round())}'
                      ' / ${num.format(g.targetValue.round())}',
              progress: g.isAchieved
                  ? 1.0
                  : g.getProgress(_current(g.metricType, state)),
              color: g.isAchieved ? AppColors.good : AppColors.accent,
              note: g.description,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────── 營運日誌 ───────────────────────────

class _LogSection extends StatelessWidget {
  final GameState state;
  const _LogSection({required this.state});

  @override
  Widget build(BuildContext context) {
    final logs = state.businessLogs.take(12).toList();
    return SectionCard(
      title: '營運日誌',
      icon: Icons.article_rounded,
      child: logs.isEmpty
          ? const EmptyHint(icon: Icons.inbox_rounded, message: '還沒有紀錄')
          : Column(
              children: [
                for (final log in logs)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 6, right: AppSpacing.sm),
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: _logColor(log),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        Expanded(child: Text(log, style: AppText.body)),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  static Color _logColor(String log) {
    if (log.contains('🚨') || log.contains('🏚️') || log.contains('❌')) {
      return AppColors.critical;
    }
    if (log.contains('⚠️') || log.contains('📉') || log.contains('🍱') || log.contains('💔')) {
      return AppColors.warning;
    }
    if (log.contains('🎉') || log.contains('🏆') || log.contains('🔨') || log.contains('🗺️')) {
      return AppColors.good;
    }
    return AppColors.textMuted;
  }
}

/// 供其他分頁重用的庫存健康度標籤
String stockHealthLabel(GameState state, InventoryItem item) {
  final cover = state.hoursOfCoverFor(item);
  if (item.stock <= 0) return '已售罄';
  if (cover == null) return '庫存充足';
  if (cover < 2) return '即將售罄';
  if (cover < 4) return '庫存吃緊';
  return '可撐 ${cover.toStringAsFixed(0)} 小時';
}
