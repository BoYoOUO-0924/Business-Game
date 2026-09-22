import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/store_fixture.dart';
import '../../providers/game_state.dart';
import '../../services/audio_service.dart';

/// 點擊 2.5D 店面設備彈出的實體操作抽屜 (Micro-Management Drawer)
class FixtureDetailSheet extends StatefulWidget {
  final StoreFixture fixture;

  const FixtureDetailSheet({super.key, required this.fixture});

  static Future<void> show(BuildContext context, StoreFixture fixture) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FixtureDetailSheet(fixture: fixture),
    );
  }

  @override
  State<FixtureDetailSheet> createState() => _FixtureDetailSheetState();
}

class _FixtureDetailSheetState extends State<FixtureDetailSheet> {
  final _currency = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GameState>();
    // 重新從 state 取得最新的 fixture 實例以確保狀態同步
    final currentFixture = state.fixtures.firstWhere(
      (f) => f.id == widget.fixture.id,
      orElse: () => widget.fixture,
    );

    final assignedItems = state.items
        .where((i) => i.requiredFixtureId == currentFixture.id && i.isUnlocked)
        .toList();

    final usedCapacity = state.shelfUsed(currentFixture.id);
    final maxCapacity = currentFixture.currentCapacity;
    final capacityRatio = maxCapacity > 0 ? (usedCapacity / maxCapacity).clamp(0.0, 1.0) : 0.0;
    final remainingSpace = state.remainingShelfSpaceForFixture(currentFixture.id);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.78,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1D24),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: const Color(0xFFFFB800).withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 24,
            spreadRadius: 4,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. 頂部拖曳把手與標題
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFB800).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFFB800).withValues(alpha: 0.4)),
                  ),
                  child: Text(currentFixture.icon, style: const TextStyle(fontSize: 26)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            currentFixture.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFB800),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Lv.${currentFixture.level}',
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '陳列容量：$usedCapacity / $maxCapacity 件 (剩餘空間 $remainingSpace 件)',
                        style: TextStyle(
                          color: remainingSpace == 0 ? Colors.amberAccent : Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                ),
              ],
            ),
          ),

          // 容量進度條
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: capacityRatio,
                minHeight: 6,
                backgroundColor: Colors.white10,
                valueColor: AlwaysStoppedAnimation<Color>(
                  capacityRatio >= 0.9
                      ? const Color(0xFFEF4444)
                      : (capacityRatio >= 0.6 ? const Color(0xFFFFB800) : const Color(0xFF10B981)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 2. 貨架商品清單
          Flexible(
            child: assignedItems.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(32),
                    child: Text('此設備目前尚無已解鎖陳列商品', style: TextStyle(color: Colors.white54)),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                    itemCount: assignedItems.length,
                    separatorBuilder: (ctx, idx) => const SizedBox(height: 10),
                    itemBuilder: (ctx, idx) {
                      final item = assignedItems[idx];
                      final unitCost = state.effectiveUnitCost(item);
                      final marginPct = (item.grossMargin * 100).toStringAsFixed(0);

                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF272630),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: item.stock == 0 ? Colors.redAccent.withValues(alpha: 0.5) : Colors.white10,
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(item.icon, style: const TextStyle(fontSize: 24)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        item.name,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13.5,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      if (item.stock == 0)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: Colors.redAccent,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Text('缺貨', style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold)),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${item.brandName} · 庫存: ${item.stock} 件 · 進價: ${_currency.format(unitCost)}',
                                    style: const TextStyle(color: Colors.white60, fontSize: 11.5),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '售價: ${_currency.format(item.retailPrice)} (毛利率 $marginPct%)',
                                    style: TextStyle(
                                      color: item.grossMargin < 0.15 ? Colors.orangeAccent : const Color(0xFF34D399),
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // 微調售價按鈕
                            IconButton(
                              onPressed: () => _adjustPrice(context, state, item),
                              icon: const Icon(Icons.price_change_outlined, color: Color(0xFF38BDF8), size: 20),
                              tooltip: '修改零售價',
                            ),
                            // 單品補貨按鈕
                            FilledButton.tonal(
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                backgroundColor: const Color(0xFF334155),
                                foregroundColor: Colors.white,
                              ),
                              onPressed: remainingSpace <= 0
                                  ? null
                                  : () {
                                      final qtyToBuy = remainingSpace.clamp(1, 10);
                                      final success = state.restockItem(item.id, qtyToBuy);
                                      if (success) {
                                        AudioService().playRestock();
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            backgroundColor: const Color(0xFF065F46),
                                            content: Text('已進貨 $qtyToBuy 件 ${item.name}'),
                                            duration: const Duration(seconds: 1),
                                          ),
                                        );
                                      }
                                    },
                              child: Text(remainingSpace <= 0 ? '架滿' : '+10進貨', style: const TextStyle(fontSize: 11.5)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          const Divider(color: Colors.white12, height: 1),

          // 3. 底部快捷操作列 (一鍵補滿此貨架 & 升級貨架)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // 升級設備按鈕
                Expanded(
                  flex: 4,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: Color(0xFFFFB800)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      final success = state.upgradeFixture(currentFixture.id);
                      if (success) {
                        AudioService().playFanfare();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: const Color(0xFF0284C7),
                            content: Text('✨ ${currentFixture.name} 成功升級至 Lv.${currentFixture.level + 1}！'),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: Colors.redAccent,
                            content: Text('資金不足以支付升級費用 ${_currency.format(currentFixture.upgradeCost)}！'),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.arrow_upward_rounded, color: Color(0xFFFFB800), size: 18),
                    label: Text(
                      '升級 ${_currency.format(currentFixture.upgradeCost)}',
                      style: const TextStyle(color: Color(0xFFFFB800), fontSize: 12.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // 一鍵填滿此貨架按鈕
                Expanded(
                  flex: 6,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: remainingSpace <= 0
                        ? null
                        : () {
                            int restockedCount = 0;
                            // 將可用空間平均配給架上商品
                            if (assignedItems.isNotEmpty) {
                              final eachQty = (remainingSpace / assignedItems.length).floor().clamp(1, 999);
                              for (final item in assignedItems) {
                                if (state.restockItem(item.id, eachQty)) {
                                  restockedCount += eachQty;
                                }
                              }
                            }
                            if (restockedCount > 0) {
                              AudioService().playRestock();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: const Color(0xFF047857),
                                  content: Text('📦 已成功填滿貨架，總計進貨 $restockedCount 件商品'),
                                ),
                              );
                            }
                          },
                    icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                    label: Text(
                      remainingSpace <= 0 ? '貨架已滿載' : '⚡ 一鍵補滿此貨架',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _adjustPrice(BuildContext context, GameState state, dynamic item) {
    double currentPrice = item.retailPrice;
    final unitCost = state.effectiveUnitCost(item);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInner) {
          final marginPct = currentPrice > 0 ? ((currentPrice - unitCost) / currentPrice * 100) : 0.0;

          return AlertDialog(
            backgroundColor: const Color(0xFF22202A),
            title: Text('${item.icon} ${item.name} 調整售價', style: const TextStyle(color: Colors.white, fontSize: 16)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '進價成本: ${_currency.format(unitCost)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 12),
                Text(
                  '零售定價: ${_currency.format(currentPrice)}',
                  style: const TextStyle(color: Color(0xFFFFB800), fontSize: 24, fontWeight: FontWeight.bold),
                ),
                Text(
                  '預期毛利率: ${marginPct.toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: marginPct < 15 ? Colors.orangeAccent : const Color(0xFF10B981),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Slider(
                  value: currentPrice.clamp(unitCost * 0.8, unitCost * 3.0),
                  min: (unitCost * 0.8).floorToDouble(),
                  max: (unitCost * 3.0).ceilToDouble(),
                  divisions: 40,
                  activeColor: const Color(0xFFFFB800),
                  onChanged: (v) => setInner(() => currentPrice = v.roundToDouble()),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('取消', style: TextStyle(color: Colors.white60)),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFFB800), foregroundColor: Colors.black),
                onPressed: () {
                  state.updateRetailPrice(item.id, currentPrice);
                  Navigator.of(ctx).pop();
                },
                child: const Text('確認定價', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }
}
