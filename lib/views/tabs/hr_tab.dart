import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/employee.dart';
import '../../providers/game_state.dart';
import '../theme/app_theme.dart';
import '../widgets/charts.dart';
import '../widgets/ui_kit.dart';

/// 人事排班 —— 把人放對時段，是這款遊戲的核心決策。
class HrTab extends StatelessWidget {
  const HrTab({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GameState>();
    final currency = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl),
      children: [
        _CoverageCard(state: state),
        const SizedBox(height: AppSpacing.lg),
        _ShiftBoard(state: state, currency: currency),
        const SizedBox(height: AppSpacing.lg),
        _StaffList(state: state, currency: currency),
        const SizedBox(height: AppSpacing.lg),
        _CandidateList(state: state, currency: currency),
      ],
    );
  }
}

class _CoverageCard extends StatelessWidget {
  final GameState state;
  const _CoverageCard({required this.state});

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
    final lost = slices.fold<int>(0, (a, s) => a + s.lost);
    final closed = slices.where((s) => !s.isOpen).length;

    return SectionCard(
      title: '排班健檢',
      icon: Icons.insights_rounded,
      subtitle: '橘色是人手不足會流失的客人，灰色是打烊時段',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShiftCoverageChart(slices: slices),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: '每日流失來客',
                  value: '$lost 人',
                  icon: Icons.person_off_rounded,
                  accent: lost > 40 ? AppColors.critical : AppColors.textPrimary,
                  hint: lost > 0 ? '尖峰時段加派人手可減少流失' : '目前人力可消化全日人流',
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: StatTile(
                  label: '打烊時數',
                  value: '$closed 小時',
                  icon: Icons.nightlight_round,
                  accent: closed >= 8 ? AppColors.warning : AppColors.textPrimary,
                  hint: closed > 0 ? '這些時段完全沒有營收' : '已達成 24 小時營業',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ShiftBoard extends StatelessWidget {
  final GameState state;
  final NumberFormat currency;
  const _ShiftBoard({required this.state, required this.currency});

  static const _shifts = [
    (ShiftType.morning, '早班', '08:00 – 16:00', Icons.wb_sunny_rounded),
    (ShiftType.evening, '晚班', '16:00 – 24:00', Icons.wb_twilight_rounded),
    (ShiftType.night, '大夜', '00:00 – 08:00', Icons.bedtime_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: '班別配置',
      icon: Icons.calendar_view_week_rounded,
      subtitle: '每日人事成本 ${currency.format(state.projectedDailyFixedCost - state.company.dailyRent)}',
      child: Column(
        children: [
          for (final (type, name, time, icon) in _shifts) ...[
            _ShiftRow(state: state, type: type, name: name, time: time, icon: icon),
            const SizedBox(height: AppSpacing.md),
          ],
          _ShiftRow(
            state: state,
            type: ShiftType.none,
            name: '休假',
            time: '未排班',
            icon: Icons.weekend_rounded,
          ),
        ],
      ),
    );
  }
}

class _ShiftRow extends StatelessWidget {
  final GameState state;
  final ShiftType type;
  final String name;
  final String time;
  final IconData icon;

  const _ShiftRow({
    required this.state,
    required this.type,
    required this.name,
    required this.time,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final members = state.hiredStaff.where((e) => e.assignedShift == type).toList();
    final isWorkShift = type != ShiftType.none;

    // 該班別的尖峰缺口
    var peakGap = 0;
    if (isWorkShift) {
      final hours = switch (type) {
        ShiftType.morning => List.generate(8, (i) => i + 8),
        ShiftType.evening => List.generate(8, (i) => i + 16),
        ShiftType.night => List.generate(8, (i) => i),
        ShiftType.none => <int>[],
      };
      for (final h in hours) {
        final gap = state.projectedFootfall(h) - state.checkoutCapacity(h).floor();
        if (gap > peakGap) peakGap = gap;
      }
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isWorkShift && members.isEmpty
              ? AppColors.warning.withValues(alpha: 0.45)
              : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: AppSpacing.sm),
              Text(name,
                  style: AppText.body.copyWith(
                      color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
              const SizedBox(width: AppSpacing.sm),
              Text(time, style: AppText.caption),
              const Spacer(),
              if (isWorkShift && members.isEmpty)
                const Pill('無人值班・打烊',
                    color: AppColors.warning, icon: Icons.warning_rounded, filled: true)
              else if (isWorkShift && peakGap > 0)
                Pill('尖峰缺口 $peakGap 人',
                    color: AppColors.serious, icon: Icons.trending_down_rounded, filled: true)
              else if (isWorkShift)
                const Pill('人力充足',
                    color: AppColors.good, icon: Icons.check_rounded, filled: true)
              else
                Pill('${members.length} 人', color: AppColors.textMuted),
            ],
          ),
          if (members.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final m in members)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceHigh,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(m.avatar, style: const TextStyle(fontSize: 13)),
                        const SizedBox(width: 5),
                        Text(m.name,
                            style: AppText.caption.copyWith(
                                color: AppColors.textPrimary)),
                        const SizedBox(width: 5),
                        Text('×${m.effectiveEfficiency.toStringAsFixed(2)}',
                            style: AppText.caption.copyWith(
                                color: m.effectiveEfficiency < 0.9
                                    ? AppColors.serious
                                    : AppColors.good)),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StaffList extends StatelessWidget {
  final GameState state;
  final NumberFormat currency;
  const _StaffList({required this.state, required this.currency});

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: '在職員工',
      icon: Icons.badge_rounded,
      trailing: Pill('${state.hiredStaff.length} 人', color: AppColors.accent),
      child: state.hiredStaff.isEmpty
          ? const EmptyHint(
              icon: Icons.person_search_rounded, message: '目前沒有員工，門市全日打烊中')
          : Column(
              children: [
                for (final s in state.hiredStaff)
                  _StaffCard(staff: s, state: state, currency: currency),
              ],
            ),
    );
  }
}

class _StaffCard extends StatelessWidget {
  final Employee staff;
  final GameState state;
  final NumberFormat currency;
  const _StaffCard({required this.staff, required this.state, required this.currency});

  @override
  Widget build(BuildContext context) {
    final conditionColor = staff.isAboutToQuit
        ? AppColors.critical
        : (staff.fatigue >= 55 ? AppColors.warning : AppColors.good);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: staff.isAboutToQuit
              ? AppColors.critical.withValues(alpha: 0.5)
              : AppColors.border,
        ),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(staff.avatar, style: const TextStyle(fontSize: 26)),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(staff.name,
                            style: AppText.body.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(width: AppSpacing.sm),
                        Pill(staff.conditionLabel, color: conditionColor, filled: true),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text('${staff.role} · 時薪 ${currency.format(staff.hourlyWage)}',
                        style: AppText.caption),
                    Text(staff.trait, style: AppText.caption),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('×${staff.effectiveEfficiency.toStringAsFixed(2)}',
                      style: AppText.tabular.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: staff.effectiveEfficiency < 0.9
                              ? AppColors.serious
                              : AppColors.good)),
                  Text('實際效率', style: AppText.caption),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: LabeledProgress(
                  label: '疲勞',
                  value: '${staff.fatigue}',
                  progress: staff.fatigue / 100,
                  color: staff.fatigue >= 80
                      ? AppColors.critical
                      : (staff.fatigue >= 55 ? AppColors.warning : AppColors.accent),
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: LabeledProgress(
                  label: '士氣',
                  value: '${staff.morale}',
                  progress: staff.morale / 100,
                  color: staff.morale <= 30 ? AppColors.critical : AppColors.good,
                ),
              ),
            ],
          ),
          if (staff.fatigue >= 55 || staff.isAboutToQuit) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              staff.isAboutToQuit
                  ? '士氣過低，再不讓他休假就會提出辭呈。'
                  : '疲勞過高已拖慢結帳速度，安排休假可恢復。',
              style: AppText.caption.copyWith(color: conditionColor),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<ShiftType>(
                  initialValue: staff.assignedShift,
                  dropdownColor: AppColors.surfaceHigh,
                  style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: AppColors.border)),
                    focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: AppColors.accent)),
                  ),
                  items: const [
                    DropdownMenuItem(value: ShiftType.morning, child: Text('早班 08–16')),
                    DropdownMenuItem(value: ShiftType.evening, child: Text('晚班 16–24')),
                    DropdownMenuItem(value: ShiftType.night, child: Text('大夜 00–08')),
                    DropdownMenuItem(value: ShiftType.none, child: Text('休假')),
                  ],
                  onChanged: (v) {
                    if (v != null) state.assignShift(staff.id, v);
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              IconButton(
                tooltip: '解僱',
                onPressed: () => _confirmFire(context, state, staff),
                icon: const Icon(Icons.person_remove_rounded,
                    size: 18, color: AppColors.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmFire(BuildContext context, GameState state, Employee staff) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('解僱員工', style: AppText.title),
        content: Text('確定讓「${staff.name}」離職嗎？該班別可能因此變成無人值班。',
            style: AppText.body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.critical),
            onPressed: () {
              state.fireEmployee(staff.id);
              Navigator.pop(ctx);
            },
            child: const Text('確定解僱'),
          ),
        ],
      ),
    );
  }
}

class _CandidateList extends StatelessWidget {
  final GameState state;
  final NumberFormat currency;
  const _CandidateList({required this.state, required this.currency});

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: '人力市場',
      icon: Icons.person_search_rounded,
      subtitle: '培訓費 \$1,500 · 商譽越高越容易吸引好手',
      child: state.candidatePool.isEmpty
          ? const EmptyHint(
              icon: Icons.hourglass_empty_rounded, message: '目前沒有應徵者，明天會有新的人來')
          : Column(
              children: [
                for (final c in state.candidatePool)
                  Container(
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Text(c.avatar, style: const TextStyle(fontSize: 22)),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(c.name,
                                  style: AppText.body.copyWith(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w600)),
                              Text(
                                  '${c.role} · 時薪 ${currency.format(c.hourlyWage)} · 效率 ×${c.efficiency.toStringAsFixed(2)}',
                                  style: AppText.caption),
                              Text(c.trait, style: AppText.caption),
                            ],
                          ),
                        ),
                        FilledButton(
                          onPressed: state.company.cash < 1500
                              ? null
                              : () => state.hireEmployee(c),
                          child: const Text('聘用'),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}
