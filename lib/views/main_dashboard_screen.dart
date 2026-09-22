import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/game_state.dart';
import '../services/audio_service.dart';
import 'components/tycoon_phone_modal.dart';
import 'tabs/city_gis_tab.dart';
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
      const CityGisTab(),
      InventoryTab(onGoToNegotiate: () => _goTo(3)),
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
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map_rounded),
            label: '商圈擴張',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2_rounded),
            label: '進銷存',
          ),
          NavigationDestination(
            icon: Icon(Icons.handshake_outlined),
            selectedIcon: Icon(Icons.handshake_rounded),
            label: '批發談判',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_alt_outlined),
            selectedIcon: Icon(Icons.people_alt_rounded),
            label: '人事排班',
          ),
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront_rounded),
            label: '門市設備',
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, GameState state) {
    final currency = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
    final c = state.company;
    final open = state.isStoreOpen;
    final isDayTime = c.hour >= 6 && c.hour <= 18;

    return AppBar(
      elevation: 2,
      backgroundColor: AppColors.surface,
      toolbarHeight: 66,
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
                    Icon(
                      isDayTime ? Icons.wb_sunny_rounded : Icons.nightlight_round,
                      size: 14,
                      color: isDayTime ? const Color(0xFFF59E0B) : const Color(0xFF818CF8),
                    ),
                    const SizedBox(width: 4),
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
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFB800).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFFFB800).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🪙 ', style: TextStyle(fontSize: 10)),
                          Text(
                            currency.format(c.cash),
                            style: AppText.tabular.copyWith(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: c.cash < 0 ? AppColors.critical : const Color(0xFFFFB800),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Icon(Icons.star_rounded,
                        size: 13, color: AppColors.forReputation(c.reputation)),
                    const SizedBox(width: 2),
                    Text('${c.reputation}',
                        style: AppText.tabular.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.forReputation(c.reputation))),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        // 公務手機 SmartOS (含 Fred 叔叔贊助未讀紅點)
        Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              tooltip: '公務手機 SmartOS (商情與天使投資)',
              icon: const Icon(Icons.smartphone_rounded, color: Color(0xFF38BDF8), size: 22),
              onPressed: () => TycoonPhoneModal.show(context),
            ),
            if (!state.hasClaimedUncleGift)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEF4444),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),

        // 一鍵智能補貨快捷鍵
        IconButton(
          tooltip: '一鍵全品項安全庫存補貨',
          icon: const Icon(Icons.flash_auto_rounded, color: Color(0xFFFBBF24), size: 20),
          onPressed: state.isBankrupt
              ? null
              : () {
                  final count = state.autoRestockSafeStock();
                  if (context.mounted) {
                    if (count > 0) {
                      AudioService().playRestock();
                      _toast(context, '📦 智能補貨完成！已自動進貨 $count 件低庫存品項！');
                    } else {
                      _toast(context, '目前庫存充裕，無需補貨');
                    }
                  }
                },
        ),

        // 音效開關切換
        IconButton(
          tooltip: AudioService().isMuted ? '開啟音效' : '靜音',
          icon: Icon(
            AudioService().isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
            size: 20,
            color: AudioService().isMuted ? AppColors.textMuted : AppColors.accent,
          ),
          onPressed: () {
            setState(() {
              AudioService().toggleMute();
            });
          },
        ),

        // 流速倍率 (1x / 3x / 8x)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: InkWell(
            onTap: () {
              final nextSpeed = state.autoPlaySpeed == 1 ? 2 : (state.autoPlaySpeed == 2 ? 3 : 1);
              state.setAutoPlaySpeed(nextSpeed);
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.4)),
              ),
              child: Text(
                state.autoPlaySpeed == 3 ? '8x' : (state.autoPlaySpeed == 2 ? '3x' : '1x'),
                style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11.5, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),

        _TimeButton(
          tooltip: '推進 1 小時',
          icon: Icons.skip_next_rounded,
          onPressed: state.isBankrupt ? null : state.advanceHour,
        ),
        _TimeButton(
          tooltip: '快進 1 天 (跳至明日 08:00)',
          icon: Icons.fast_forward_rounded,
          onPressed: state.isBankrupt ? null : state.advanceDay,
        ),
        _TimeButton(
          tooltip: state.isAutoPlaying ? '暫停時間' : '開始時間推進',
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
