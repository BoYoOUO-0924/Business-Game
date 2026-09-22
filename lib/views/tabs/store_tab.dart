import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/store_fixture.dart';
import '../../providers/game_state.dart';
import '../components/isometric_store_view.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_kit.dart';

/// 門市 —— 設備投資、店面實景與成就。
/// 設備是整個進程的主軸：每台設備解鎖一批商品與一條貨源。
class StoreTab extends StatelessWidget {
  const StoreTab({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GameState>();
    final currency = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl),
      children: [
        _StoreHeader(state: state, currency: currency),
        const SizedBox(height: AppSpacing.lg),
        SectionCard(
          title: '門市實景',
          icon: Icons.storefront_rounded,
          subtitle: '點擊畫面可手動為顧客結帳',
          padding: const EdgeInsets.all(AppSpacing.md),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: const SizedBox(height: 260, child: IsometricStoreView()),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _FixtureSection(state: state, currency: currency),
        const SizedBox(height: AppSpacing.lg),
        _StoreUpgradeCard(state: state, currency: currency),
        const SizedBox(height: AppSpacing.lg),
        _QuestSection(state: state, currency: currency),
      ],
    );
  }
}

class _StoreHeader extends StatelessWidget {
  final GameState state;
  final NumberFormat currency;
  const _StoreHeader({required this.state, required this.currency});

  @override
  Widget build(BuildContext context) {
    final c = state.company;
    final totalCapacity = state.fixtures
        .where((f) => f.isPurchased)
        .fold(0, (a, f) => a + f.currentCapacity);
    final used = state.items.fold(0, (a, i) => a + i.stock);

    return SectionCard(
      title: '幸福連鎖便利商店 · 1 號創始店',
      icon: Icons.store_rounded,
      subtitle: '門市等級 Lv.${c.storeLevel}',
      child: Column(
        children: [
          KeyValueRow('每日租金', currency.format(c.dailyRent)),
          KeyValueRow('門市商譽', '${c.reputation} / 100',
              valueColor: AppColors.forReputation(c.reputation)),
          KeyValueRow('總陳列容量', '$used / $totalCapacity 件'),
          KeyValueRow('可販售品項',
              '${state.items.where((i) => i.isUnlocked).length} / ${state.items.length} 項'),
          KeyValueRow('累計銷售', '${NumberFormat.decimalPattern().format(c.totalUnitsSold)} 件'),
        ],
      ),
    );
  }
}

class _FixtureSection extends StatelessWidget {
  final GameState state;
  final NumberFormat currency;
  const _FixtureSection({required this.state, required this.currency});

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: '門市設備',
      icon: Icons.construction_rounded,
      subtitle: '每台設備解鎖一批商品與對應的批發貨源',
      child: Column(
        children: [
          for (final f in state.fixtures)
            _FixtureCard(fixture: f, state: state, currency: currency),
        ],
      ),
    );
  }
}

class _FixtureCard extends StatelessWidget {
  final StoreFixture fixture;
  final GameState state;
  final NumberFormat currency;
  const _FixtureCard(
      {required this.fixture, required this.state, required this.currency});

  @override
  Widget build(BuildContext context) {
    final unlocks =
        state.items.where((i) => i.requiredFixtureId == fixture.id).toList();
    final canBuy = state.company.cash >= fixture.cost;
    final canUpgrade = state.company.cash >= fixture.upgradeCost;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: fixture.isPurchased
              ? AppColors.border
              : AppColors.accent.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(fixture.icon, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(fixture.name,
                        style: AppText.body.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(fixture.description, style: AppText.caption),
                  ],
                ),
              ),
              if (fixture.isPurchased)
                Pill('Lv.${fixture.level}', color: AppColors.good, filled: true)
              else
                Pill(currency.format(fixture.cost),
                    color: canBuy ? AppColors.accent : AppColors.textMuted,
                    filled: true),
            ],
          ),
          if (unlocks.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              fixture.isPurchased
                  ? '陳列中：${unlocks.map((i) => i.icon).join(' ')}（${unlocks.length} 項）'
                  : '可解鎖 ${unlocks.length} 項商品：${unlocks.take(4).map((i) => i.name).join('、')}${unlocks.length > 4 ? ' 等' : ''}',
              style: AppText.caption.copyWith(
                  color: fixture.isPurchased
                      ? AppColors.textSecondary
                      : AppColors.accentSoft),
            ),
          ],
          if (fixture.isPurchased && fixture.currentCapacity > 0) ...[
            const SizedBox(height: AppSpacing.md),
            LabeledProgress(
              label: '陳列使用率',
              value: '${state.shelfUsed(fixture.id)} / ${fixture.currentCapacity}',
              progress: state.shelfUsed(fixture.id) / fixture.currentCapacity,
              color: AppColors.accent,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              if (!fixture.isPurchased)
                FilledButton(
                  onPressed: canBuy ? () => state.purchaseFixture(fixture.id) : null,
                  child: Text(canBuy ? '添購設備' : '現金不足'),
                )
              else if (fixture.currentCapacity > 0)
                OutlinedButton(
                  onPressed:
                      canUpgrade ? () => state.upgradeFixture(fixture.id) : null,
                  child: Text('升級 ${currency.format(fixture.upgradeCost)}'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StoreUpgradeCard extends StatelessWidget {
  final GameState state;
  final NumberFormat currency;
  const _StoreUpgradeCard({required this.state, required this.currency});

  @override
  Widget build(BuildContext context) {
    const cost = 15000.0;
    final canUpgrade = state.company.cash >= cost;

    return SectionCard(
      title: '門市擴建',
      icon: Icons.upgrade_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '一次把門市所有已購置的陳列設備升一級，全面擴充容量。'
            '容量越大，單次補貨能撐越久，也越不容易在尖峰時段缺貨。',
            style: AppText.body,
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Text('升級花費 ${currency.format(cost)}',
                  style: AppText.body.copyWith(
                      color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
              const Spacer(),
              FilledButton(
                onPressed: canUpgrade ? () => state.upgradeStoreShelf() : null,
                child: Text(canUpgrade ? '升級至 Lv.${state.company.storeLevel + 1}' : '現金不足'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuestSection extends StatelessWidget {
  final GameState state;
  final NumberFormat currency;
  const _QuestSection({required this.state, required this.currency});

  double _current(String id, GameState s) {
    switch (id) {
      case 'q_revenue_30k':
        return s.company.totalRevenue;
      case 'q_negotiation':
        return s.items.firstWhere((e) => e.id == 'coffee_bean').currentNegotiatedPrice;
      case 'q_hire_team':
        return s.hiredStaff.length.toDouble();
      case 'q_sales_volume':
        return s.company.totalUnitsSold.toDouble();
      case 'q_reputation_80':
        return s.company.reputation.toDouble();
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final num = NumberFormat.decimalPattern();
    final done = state.quests.where((q) => q.isCompleted).length;

    return SectionCard(
      title: '經營成就',
      icon: Icons.emoji_events_rounded,
      trailing: Pill('$done / ${state.quests.length}', color: AppColors.accent),
      child: Column(
        children: [
          for (final q in state.quests) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(q.icon, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LabeledProgress(
                        label: q.isCompleted ? '✓ ${q.title}' : q.title,
                        value: q.id == 'q_negotiation'
                            ? '\$${_current(q.id, state).toStringAsFixed(0)} → \$${q.targetValue.toInt()}'
                            : '${num.format(_current(q.id, state).clamp(0, q.targetValue).round())}'
                                ' / ${num.format(q.targetValue.round())}',
                        progress: q.isCompleted
                            ? 1.0
                            : q.currentProgress(_current(q.id, state)),
                        color: q.isCompleted ? AppColors.good : AppColors.accent,
                        note: '${q.description} · 獎勵 ${currency.format(q.rewardCash)}'
                            '、商譽 +${q.rewardReputation}',
                      ),
                    ],
                  ),
                ),
                if (q.isCompleted && !q.isClaimed) ...[
                  const SizedBox(width: AppSpacing.sm),
                  FilledButton(
                    onPressed: () => state.claimQuestReward(q.id),
                    child: const Text('領取'),
                  ),
                ] else if (q.isClaimed) ...[
                  const SizedBox(width: AppSpacing.sm),
                  const Pill('已領取', color: AppColors.textMuted),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ],
      ),
    );
  }
}
