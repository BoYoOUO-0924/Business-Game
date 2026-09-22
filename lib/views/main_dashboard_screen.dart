import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/game_state.dart';
import 'tabs/hr_tab.dart';
import 'tabs/inventory_tab.dart';
import 'tabs/overview_tab.dart';
import 'tabs/sourcing_map_tab.dart';
import 'tabs/store_tab.dart';
import 'theme/app_theme.dart';
import 'widgets/ui_kit.dart';

class MainDashboardScreen extends StatefulWidget {
  const MainDashboardScreen({super.key});

  @override
  State<MainDashboardScreen> createState() => _MainDashboardScreenState();
}

class _MainDashboardScreenState extends State<MainDashboardScreen> {
  int _currentTab = 0;
  int _lastSavedDay = 0;

  void _goTo(int index) => setState(() => _currentTab = index);

  /// 每跨一天自動存檔一次
  void _autoSaveIfNeeded(GameState state) {
    if (state.company.day != _lastSavedDay) {
      _lastSavedDay = state.company.day;
      state.save();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GameState>();
    _autoSaveIfNeeded(state);

    final tabs = [
      OverviewTab(onNavigateTab: _goTo),
      InventoryTab(onGoToNegotiate: () => _goTo(2)),
      const SourcingMapTab(),
      const HrTab(),
      const StoreTab(),
    ];

    return Scaffold(
      backgroundColor: AppColors.page,
      appBar: _buildAppBar(context, state),
      body: Stack(
        children: [
          IndexedStack(index: _currentTab, children: tabs),
          if (state.isBankrupt) _BankruptOverlay(state: state),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentTab,
        onDestinationSelected: _goTo,
        height: 62,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: '總覽',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2_rounded),
            label: '進銷存',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map_rounded),
            label: '批發地圖',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_alt_outlined),
            selectedIcon: Icon(Icons.people_alt_rounded),
            label: '人事排班',
          ),
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront_rounded),
            label: '門市',
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, GameState state) {
    final currency = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
    final c = state.company;
    final open = state.isStoreOpen;

    return AppBar(
      elevation: 0,
      backgroundColor: AppColors.surface,
      toolbarHeight: 62,
      titleSpacing: AppSpacing.lg,
      title: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(c.timeFormatted,
                        style: AppText.tabular.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                    const SizedBox(width: AppSpacing.sm),
                    Pill(
                      open ? '營業中' : '打烊',
                      color: open ? AppColors.good : AppColors.textMuted,
                      icon: open ? Icons.check_circle_rounded : Icons.nightlight_round,
                      filled: true,
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(currency.format(c.cash),
                        style: AppText.tabular.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: c.cash < 0 ? AppColors.critical : AppColors.textSecondary,
                        )),
                    const SizedBox(width: AppSpacing.md),
                    Icon(Icons.star_rounded,
                        size: 12, color: AppColors.forReputation(c.reputation)),
                    const SizedBox(width: 3),
                    Text('${c.reputation}',
                        style: AppText.tabular.copyWith(
                            fontSize: 12,
                            color: AppColors.forReputation(c.reputation))),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        _TimeButton(
          tooltip: '推進 1 小時',
          icon: Icons.skip_next_rounded,
          onPressed: state.isBankrupt ? null : state.advanceHour,
        ),
        _TimeButton(
          tooltip: '快進 1 天',
          icon: Icons.fast_forward_rounded,
          onPressed: state.isBankrupt ? null : state.advanceDay,
        ),
        _TimeButton(
          tooltip: state.isAutoPlaying ? '暫停' : '自動推進',
          icon: state.isAutoPlaying
              ? Icons.pause_circle_filled_rounded
              : Icons.play_circle_fill_rounded,
          color: state.isAutoPlaying ? AppColors.warning : AppColors.good,
          size: 28,
          onPressed: state.isBankrupt ? null : state.toggleAutoPlay,
        ),
        PopupMenuButton<String>(
          tooltip: '選單',
          color: AppColors.surfaceHigh,
          icon: const Icon(Icons.more_vert_rounded, color: AppColors.textSecondary),
          onSelected: (v) async {
            if (v == 'save') {
              await state.save();
              if (context.mounted) _toast(context, '已存檔');
            } else if (v == 'reset') {
              if (context.mounted) _confirmRestart(context, state);
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: 'save',
              child: Row(children: [
                Icon(Icons.save_rounded, size: 16, color: AppColors.textSecondary),
                SizedBox(width: AppSpacing.sm),
                Text('立即存檔', style: TextStyle(color: AppColors.textPrimary)),
              ]),
            ),
            PopupMenuItem(
              value: 'reset',
              child: Row(children: [
                Icon(Icons.restart_alt_rounded, size: 16, color: AppColors.critical),
                SizedBox(width: AppSpacing.sm),
                Text('重新開店', style: TextStyle(color: AppColors.critical)),
              ]),
            ),
          ],
        ),
        const SizedBox(width: AppSpacing.sm),
      ],
    );
  }
}

class _TimeButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? color;
  final double size;

  const _TimeButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.color,
    this.size = 22,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon,
          size: size,
          color: onPressed == null
              ? AppColors.textMuted.withValues(alpha: 0.4)
              : (color ?? AppColors.textSecondary)),
    );
  }
}

class _BankruptOverlay extends StatelessWidget {
  final GameState state;
  const _BankruptOverlay({required this.state});

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
    return Container(
      color: AppColors.page.withValues(alpha: 0.88),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SectionCard(
          title: '門市歇業',
          icon: Icons.dangerous_rounded,
          subtitle: '連續 3 天週轉不靈，房東收回了店面',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              KeyValueRow('經營天數', '${state.company.day} 天'),
              KeyValueRow('累計營業額', currency.format(state.company.totalRevenue)),
              KeyValueRow('累計銷售', '${state.company.totalUnitsSold} 件'),
              KeyValueRow('最終商譽', '${state.company.reputation} / 100'),
              const SizedBox(height: AppSpacing.lg),
              Text(
                '下次記得：沒人值班的時段不會有營收，但工資與租金照付；'
                '尖峰時段人手不足會讓客人排隊到放棄；鮮食進太多會整批報廢。',
                style: AppText.body,
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _confirmRestart(context, state, fromBankruptcy: true),
                  icon: const Icon(Icons.restart_alt_rounded, size: 16),
                  label: const Text('重新開店'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void _toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      backgroundColor: AppColors.surfaceHigh,
      duration: const Duration(seconds: 2),
      content: Text(message, style: const TextStyle(color: AppColors.textPrimary)),
    ),
  );
}

void _confirmRestart(BuildContext context, GameState state,
    {bool fromBankruptcy = false}) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text('重新開店', style: AppText.title),
      content: Text(
        fromBankruptcy
            ? '將清除存檔並從第 1 天重新開始。'
            : '這會清除目前的存檔並從第 1 天重新開始，確定嗎？',
        style: AppText.body,
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.critical),
          onPressed: () async {
            await state.deleteSave();
            state.resetToNewGame();
            if (ctx.mounted) Navigator.pop(ctx);
          },
          child: const Text('確定重開'),
        ),
      ],
    ),
  );
}
