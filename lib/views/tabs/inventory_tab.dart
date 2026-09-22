import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/inventory_item.dart';
import '../../providers/game_state.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_kit.dart';

/// 進銷存 —— 補貨、定價與貨架管理。
class InventoryTab extends StatefulWidget {
  final VoidCallback onGoToNegotiate;
  const InventoryTab({super.key, required this.onGoToNegotiate});

  @override
  State<InventoryTab> createState() => _InventoryTabState();
}

class _InventoryTabState extends State<InventoryTab> {
  bool _showLocked = false;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GameState>();
    final currency = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

    final unlocked = state.items.where((i) => i.isUnlocked).toList()
      ..sort((a, b) {
        final ca = state.hoursOfCoverFor(a) ?? 999;
        final cb = state.hoursOfCoverFor(b) ?? 999;
        return ca.compareTo(cb); // 最急的排最前面
      });
    final locked = state.items.where((i) => !i.isUnlocked).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl),
      children: [
        _RestockBar(state: state, currency: currency),
        const SizedBox(height: AppSpacing.lg),
        _ShelfCapacityCard(state: state),
        const SizedBox(height: AppSpacing.lg),
        SectionCard(
          title: '在架商品',
          icon: Icons.local_grocery_store_rounded,
          subtitle: '依庫存吃緊程度排序',
          trailing: Pill('${unlocked.length} 項', color: AppColors.accent),
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
          child: Column(
            children: [
              for (final item in unlocked)
                _ItemRow(item: item, state: state, currency: currency),
            ],
          ),
        ),
        if (locked.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          SectionCard(
            title: '尚未解鎖的商品',
            icon: Icons.lock_rounded,
            subtitle: '需要添購對應的陳列設備才能上架',
            trailing: TextButton(
              onPressed: () => setState(() => _showLocked = !_showLocked),
              child: Text(_showLocked ? '收起' : '展開 ${locked.length} 項'),
            ),
            child: _showLocked
                ? Column(
                    children: [
                      for (final item in locked) _LockedRow(item: item, state: state),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ],
    );
  }
}

class _RestockBar extends StatelessWidget {
  final GameState state;
  final NumberFormat currency;
  const _RestockBar({required this.state, required this.currency});

  @override
  Widget build(BuildContext context) {
    final low = state.lowStockItems.length;
    return SectionCard(
      title: '補貨',
      icon: Icons.local_shipping_rounded,
      subtitle: '依各商品預估銷量配貨，並保留一日週轉金',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  low > 0
                      ? '$low 項商品撐不到 4 小時，缺貨的客人會直接離開。'
                      : '目前庫存水位健康。',
                  style: AppText.body.copyWith(
                      color: low > 0 ? AppColors.warning : AppColors.textSecondary),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              FilledButton.icon(
                onPressed: () {
                  final spent = state.restockAllToCapacity();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: AppColors.surfaceHigh,
                      content: Text(
                        spent > 0
                            ? '已補貨，花費 ${currency.format(spent)}'
                            : '庫存已足或現金不足，未進行採購',
                        style: const TextStyle(color: AppColors.textPrimary),
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                label: const Text('一鍵補貨'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '可動用現金 ${currency.format(state.company.cash)} · '
            '須保留週轉金 ${currency.format(state.projectedDailyFixedCost)}',
            style: AppText.caption,
          ),
        ],
      ),
    );
  }
}

class _ShelfCapacityCard extends StatelessWidget {
  final GameState state;
  const _ShelfCapacityCard({required this.state});

  @override
  Widget build(BuildContext context) {
    final purchased =
        state.fixtures.where((f) => f.isPurchased && f.currentCapacity > 0).toList();
    if (purchased.isEmpty) return const SizedBox.shrink();

    return SectionCard(
      title: '陳列空間',
      icon: Icons.shelves,
      subtitle: '同一設備上的商品共用容量，升級設備可擴充',
      child: Column(
        children: [
          for (final f in purchased) ...[
            LabeledProgress(
              label: '${f.icon} ${f.name}  Lv.${f.level}',
              value: '${state.shelfUsed(f.id)} / ${f.currentCapacity}',
              progress: f.currentCapacity == 0
                  ? 0
                  : state.shelfUsed(f.id) / f.currentCapacity,
              color: state.shelfUsed(f.id) >= f.currentCapacity
                  ? AppColors.warning
                  : AppColors.accent,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  final InventoryItem item;
  final GameState state;
  final NumberFormat currency;
  const _ItemRow({required this.item, required this.state, required this.currency});

  @override
  Widget build(BuildContext context) {
    final cover = state.hoursOfCoverFor(item);
    final expected = state.expectedDailyDemand(item);
    final space = state.remainingShelfSpaceFor(item);
    final supplier = state.effectiveSupplierFor(item);
    final unitCost = state.effectiveUnitCost(item);

    final (statusText, statusColor) = _status(item, cover);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: item.stock <= 0 ? AppColors.critical.withValues(alpha: 0.5) : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.icon, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name,
                        style: AppText.body.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text('${item.brandName} · ${item.category}',
                        style: AppText.caption),
                  ],
                ),
              ),
              Pill(statusText, color: statusColor, filled: true),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _Metric('庫存', '${item.stock}',
                    sub: '預估日銷 $expected'),
              ),
              Expanded(
                child: _Metric('進價', currency.format(unitCost),
                    sub: supplier.contactPerson),
              ),
              Expanded(
                child: _Metric('售價', currency.format(item.retailPrice),
                    sub: '毛利 ${(item.grossMargin * 100).toStringAsFixed(0)}%',
                    subColor: item.grossMargin <= 0
                        ? AppColors.critical
                        : AppColors.textMuted),
              ),
              if (item.isPerishable)
                Expanded(
                  child: _Metric(
                    '鮮度',
                    item.hoursUntilSpoil == null
                        ? '—'
                        : '${item.hoursUntilSpoil}h',
                    sub: '賞味 ${item.shelfLifeHours}h',
                    subColor: (item.hoursUntilSpoil ?? 99) < 4
                        ? AppColors.serious
                        : AppColors.textMuted,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              OutlinedButton(
                onPressed: () => _showPriceDialog(context, state, item),
                child: const Text('調價'),
              ),
              const SizedBox(width: AppSpacing.sm),
              OutlinedButton(
                onPressed: space <= 0
                    ? null
                    : () => _showRestockDialog(context, state, item, space, unitCost),
                child: Text(space <= 0 ? '貨架已滿' : '進貨'),
              ),
              const Spacer(),
              if (item.dailyLostSales > 0)
                Text('今日流失 ${item.dailyLostSales} 客',
                    style: AppText.caption.copyWith(color: AppColors.serious)),
              if (item.dailySpoiledUnits > 0) ...[
                const SizedBox(width: AppSpacing.sm),
                Text('報廢 ${item.dailySpoiledUnits} 件',
                    style: AppText.caption.copyWith(color: AppColors.warning)),
              ],
            ],
          ),
        ],
      ),
    );
  }

  (String, Color) _status(InventoryItem item, double? cover) {
    if (item.stock <= 0) return ('已售罄', AppColors.critical);
    if (cover == null) return ('充足', AppColors.good);
    if (cover < 2) return ('即將售罄', AppColors.critical);
    if (cover < 4) return ('吃緊', AppColors.warning);
    if (cover < 12) return ('可撐 ${cover.toStringAsFixed(0)}h', AppColors.accent);
    return ('充足', AppColors.good);
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;
  final Color? subColor;
  const _Metric(this.label, this.value, {this.sub, this.subColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.caption),
        const SizedBox(height: 2),
        Text(value,
            style: AppText.tabular.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
        if (sub != null)
          Text(sub!,
              style: AppText.caption.copyWith(color: subColor),
              overflow: TextOverflow.ellipsis),
      ],
    );
  }
}

class _LockedRow extends StatelessWidget {
  final InventoryItem item;
  final GameState state;
  const _LockedRow({required this.item, required this.state});

  @override
  Widget build(BuildContext context) {
    final fixture = state.fixtureFor(item);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Opacity(opacity: 0.45, child: Text(item.icon, style: const TextStyle(fontSize: 18))),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: AppText.body),
                Text('需要：${fixture.icon} ${fixture.name}',
                    style: AppText.caption.copyWith(color: AppColors.warning)),
              ],
            ),
          ),
          const Icon(Icons.lock_rounded, size: 14, color: AppColors.textMuted),
        ],
      ),
    );
  }
}

void _showPriceDialog(BuildContext context, GameState state, InventoryItem item) {
  final controller = TextEditingController(text: item.retailPrice.toStringAsFixed(0));
  final currency = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setInner) {
        final entered = double.tryParse(controller.text) ?? item.retailPrice;
        final margin = entered > 0
            ? (entered - item.currentNegotiatedPrice) / entered
            : 0.0;
        // 顧客的心理合理價錨點：批發成本 × 1.6
        final anchor = item.wholesaleCost * 1.6;

        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text('${item.icon} ${item.name} 定價', style: AppText.title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 18),
                onChanged: (_) => setInner(() {}),
                decoration: const InputDecoration(
                  prefixText: '\$ ',
                  prefixStyle: TextStyle(color: AppColors.textSecondary),
                  enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: AppColors.border)),
                  focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: AppColors.accent)),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              KeyValueRow('進貨成本', currency.format(item.currentNegotiatedPrice)),
              KeyValueRow('毛利率', '${(margin * 100).toStringAsFixed(1)}%',
                  valueColor: margin <= 0 ? AppColors.critical : AppColors.good),
              KeyValueRow('顧客心理價位', '約 ${currency.format(anchor)}'),
              const SizedBox(height: AppSpacing.sm),
              Text(
                entered > anchor * 1.15
                    ? '定價偏高，來客購買意願會明顯下降。'
                    : (entered < anchor * 0.85
                        ? '定價偏低，賣得快但毛利被壓縮。'
                        : '定價落在顧客可接受的區間。'),
                style: AppText.caption,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            FilledButton(
              onPressed: () {
                final v = double.tryParse(controller.text);
                if (v != null && v > 0) state.updateRetailPrice(item.id, v);
                Navigator.pop(ctx);
              },
              child: const Text('確定'),
            ),
          ],
        );
      },
    ),
  );
}

void _showRestockDialog(BuildContext context, GameState state, InventoryItem item,
    int maxSpace, double unitCost) {
  final currency = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
  final suggested =
      state.expectedDailyDemand(item).clamp(0, maxSpace).toDouble();
  var qty = suggested > 0 ? suggested : maxSpace.toDouble().clamp(0.0, 50.0);

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setInner) {
        final cost = qty * unitCost;
        final affordable = cost <= state.company.cash;
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text('${item.icon} 進貨 ${item.name}', style: AppText.title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${qty.round()} 件',
                  style: AppText.hero.copyWith(fontSize: 24)),
              Slider(
                value: qty,
                min: 0,
                max: maxSpace.toDouble(),
                divisions: maxSpace > 0 ? maxSpace : 1,
                activeColor: AppColors.accent,
                onChanged: (v) => setInner(() => qty = v),
              ),
              KeyValueRow('單價', currency.format(unitCost)),
              KeyValueRow('總計', currency.format(cost),
                  valueColor: affordable ? AppColors.textPrimary : AppColors.critical),
              KeyValueRow('貨架剩餘空間', '$maxSpace 件'),
              KeyValueRow('預估日銷量', '${state.expectedDailyDemand(item)} 件'),
              if (item.isPerishable) ...[
                const SizedBox(height: AppSpacing.sm),
                Text('鮮食賞味期 ${item.shelfLifeHours} 小時，一次進太多會整批報廢。',
                    style: AppText.caption.copyWith(color: AppColors.serious)),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            FilledButton(
              onPressed: qty < 1 || !affordable
                  ? null
                  : () {
                      state.restockItem(item.id, qty.round());
                      Navigator.pop(ctx);
                    },
              child: Text(affordable ? '確認進貨' : '現金不足'),
            ),
          ],
        );
      },
    ),
  );
}
