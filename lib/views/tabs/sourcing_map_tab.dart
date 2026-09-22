import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/inventory_item.dart';
import '../../models/negotiation.dart';
import '../../models/supplier.dart';
import '../../providers/game_state.dart';
import '../../services/ai_negotiation_service.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_kit.dart';

/// 批發地圖 —— 選貨源、談進價。
/// 好感度越高折扣越深，砍價直接改善每一件商品的毛利。
class SourcingMapTab extends StatefulWidget {
  const SourcingMapTab({super.key});

  @override
  State<SourcingMapTab> createState() => _SourcingMapTabState();
}

class _SourcingMapTabState extends State<SourcingMapTab> {
  final _msgController = TextEditingController();
  double _proposedPrice = 0;
  int _proposedQuantity = 0;
  String? _selectedItemId;

  @override
  void dispose() {
    _msgController.dispose();
    super.dispose();
  }

  /// 該供應商可談的商品。老李是萬用在地貨源，任何已解鎖的商品都能跟他談。
  List<InventoryItem> _negotiableItems(GameState state, Supplier supplier) {
    if (supplier.suppliedItemIds.isEmpty) {
      return state.items.where((i) => i.isUnlocked).toList();
    }
    return state.items.where((i) => supplier.suppliedItemIds.contains(i.id)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GameState>();
    final supplier = state.selectedSupplier;
    final currency = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
    final items = _negotiableItems(state, supplier);

    final activeItem = items.isEmpty
        ? null
        : items.firstWhere((i) => i.id == _selectedItemId, orElse: () => items.first);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl),
      children: [
        _SupplierDirectory(
          state: state,
          onSelect: (id) {
            state.selectSupplier(id);
            setState(() {
              _selectedItemId = null;
              _proposedPrice = 0;
              _proposedQuantity = 0;
            });
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        if (activeItem == null)
          SectionCard(
            title: '洽談',
            icon: Icons.handshake_rounded,
            child: const EmptyHint(
                icon: Icons.inventory_rounded,
                message: '這位供應商目前沒有你能販售的商品\n先添購對應的陳列設備'),
          )
        else
          _NegotiationConsole(
            state: state,
            supplier: supplier,
            items: items,
            activeItem: activeItem,
            currency: currency,
            msgController: _msgController,
            proposedPrice: _proposedPrice <= 0
                ? activeItem.currentNegotiatedPrice * 0.85
                : _proposedPrice,
            proposedQuantity:
                _proposedQuantity <= 0 ? supplier.minOrderQuantity : _proposedQuantity,
            onSelectItem: (id) => setState(() {
              _selectedItemId = id;
              _proposedPrice = 0;
            }),
            onPrice: (v) => setState(() => _proposedPrice = v),
            onQuantity: (v) => setState(() => _proposedQuantity = v),
          ),
        const SizedBox(height: AppSpacing.lg),
        _NegotiationLog(state: state),
      ],
    );
  }
}

class _SupplierDirectory extends StatelessWidget {
  final GameState state;
  final void Function(String id) onSelect;
  const _SupplierDirectory({required this.state, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final unlocked = state.suppliers.where((s) => s.isUnlocked).length;

    return SectionCard(
      title: '商圈批發貨源',
      icon: Icons.map_rounded,
      subtitle: '好感度越高，批發折扣越深',
      trailing: Pill('$unlocked / ${state.suppliers.length} 已開通',
          color: AppColors.accent),
      child: Column(
        children: [
          for (final s in state.suppliers)
            _SupplierRow(
              supplier: s,
              isSelected: s.id == state.selectedSupplierId,
              onTap: s.isUnlocked ? () => onSelect(s.id) : null,
            ),
        ],
      ),
    );
  }
}

class _SupplierRow extends StatelessWidget {
  final Supplier supplier;
  final bool isSelected;
  final VoidCallback? onTap;
  const _SupplierRow(
      {required this.supplier, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final locked = !supplier.isUnlocked;
    final discount = ((1 - supplier.effectiveWholesaleMultiplier) * 100);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.surfaceHigh : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.accent : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Opacity(
              opacity: locked ? 0.4 : 1,
              child: Text(supplier.avatar, style: const TextStyle(fontSize: 24)),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          supplier.name,
                          style: AppText.body.copyWith(
                            color: locked
                                ? AppColors.textMuted
                                : AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      if (locked)
                        const Icon(Icons.lock_rounded,
                            size: 13, color: AppColors.textMuted)
                      else if (isSelected)
                        const Pill('洽談中',
                            color: AppColors.accent, filled: true),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    locked
                        ? '解鎖條件：${supplier.unlockRequirementText}'
                        : supplier.description,
                    style: AppText.caption.copyWith(
                        color: locked ? AppColors.warning : AppColors.textSecondary),
                  ),
                  if (!locked) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Pill('好感 ${supplier.relationship}',
                            color: supplier.relationship >= 65
                                ? AppColors.good
                                : AppColors.textMuted),
                        const SizedBox(width: AppSpacing.sm),
                        Pill(
                            discount > 0.5
                                ? '折扣 ${discount.toStringAsFixed(0)}%'
                                : '無折扣',
                            color: discount > 0.5
                                ? AppColors.good
                                : AppColors.textMuted),
                        const SizedBox(width: AppSpacing.sm),
                        Pill('起訂 ${supplier.minOrderQuantity} 件',
                            color: AppColors.textMuted),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NegotiationConsole extends StatelessWidget {
  final GameState state;
  final Supplier supplier;
  final List<InventoryItem> items;
  final InventoryItem activeItem;
  final NumberFormat currency;
  final TextEditingController msgController;
  final double proposedPrice;
  final int proposedQuantity;
  final void Function(String) onSelectItem;
  final void Function(double) onPrice;
  final void Function(int) onQuantity;

  const _NegotiationConsole({
    required this.state,
    required this.supplier,
    required this.items,
    required this.activeItem,
    required this.currency,
    required this.msgController,
    required this.proposedPrice,
    required this.proposedQuantity,
    required this.onSelectItem,
    required this.onPrice,
    required this.onQuantity,
  });

  @override
  Widget build(BuildContext context) {
    final floor = activeItem.wholesaleCost * 0.65;
    final totalCost = proposedPrice * proposedQuantity;
    final projectedMargin = activeItem.retailPrice > 0
        ? (activeItem.retailPrice - proposedPrice) / activeItem.retailPrice
        : 0.0;

    return SectionCard(
      title: '與 ${supplier.contactPerson} 洽談',
      icon: Icons.handshake_rounded,
      subtitle: supplier.location,
      trailing: DropdownButton<AiProvider>(
        value: state.aiProvider,
        dropdownColor: AppColors.surfaceHigh,
        underline: const SizedBox(),
        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        items: const [
          DropdownMenuItem(value: AiProvider.localRule, child: Text('離線規則')),
          DropdownMenuItem(value: AiProvider.ollama, child: Text('本機 Ollama')),
          DropdownMenuItem(value: AiProvider.gemini, child: Text('雲端 Gemini')),
        ],
        onChanged: (v) {
          if (v != null) state.setAiProvider(v);
        },
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('談判商品', style: AppText.label),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
              itemBuilder: (_, i) {
                final item = items[i];
                final sel = item.id == activeItem.id;
                return InkWell(
                  onTap: () => onSelectItem(item.id),
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md, vertical: 6),
                    decoration: BoxDecoration(
                      color: sel ? AppColors.accent.withValues(alpha: 0.2) : AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                          color: sel ? AppColors.accent : AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Text(item.icon, style: const TextStyle(fontSize: 13)),
                        const SizedBox(width: 5),
                        Text(item.name,
                            style: AppText.caption.copyWith(
                                color: sel
                                    ? AppColors.textPrimary
                                    : AppColors.textSecondary)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: '目前進價',
                  value: currency.format(activeItem.currentNegotiatedPrice),
                  hint: '原廠牌價 ${currency.format(activeItem.wholesaleCost)}',
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: StatTile(
                  label: '議價後毛利率',
                  value: '${(projectedMargin * 100).toStringAsFixed(0)}%',
                  accent: projectedMargin <= 0
                      ? AppColors.critical
                      : AppColors.good,
                  hint: '售價 ${currency.format(activeItem.retailPrice)}',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('提議單價 ${currency.format(proposedPrice)}',
              style: AppText.body.copyWith(color: AppColors.textPrimary)),
          Slider(
            value: proposedPrice.clamp(floor * 0.8, activeItem.wholesaleCost * 1.1),
            min: floor * 0.8,
            max: activeItem.wholesaleCost * 1.1,
            activeColor: proposedPrice < floor ? AppColors.critical : AppColors.accent,
            onChanged: onPrice,
          ),
          Text(
            proposedPrice < floor
                ? '低於對方成本底線（約 ${currency.format(floor)}），大概率談不成。'
                : '在對方可接受的範圍內，成交機會不錯。',
            style: AppText.caption.copyWith(
                color: proposedPrice < floor ? AppColors.critical : AppColors.textMuted),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('採購量 $proposedQuantity 件（總計 ${currency.format(totalCost)}）',
              style: AppText.body.copyWith(color: AppColors.textPrimary)),
          Slider(
            value: proposedQuantity
                .toDouble()
                .clamp(supplier.minOrderQuantity.toDouble(), 400.0),
            min: supplier.minOrderQuantity.toDouble(),
            max: 400,
            activeColor: AppColors.accent,
            onChanged: (v) => onQuantity(v.round()),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: msgController,
            style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
            maxLines: 2,
            decoration: const InputDecoration(
              hintText: '說點什麼展現誠意，例如：長期合作、整箱進貨、現金結帳…',
              hintStyle: TextStyle(fontSize: 12, color: AppColors.textMuted),
              enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.border)),
              focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.accent)),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: state.isNegotiating
                  ? null
                  : () {
                      final text = msgController.text.trim();
                      state.sendNegotiationMessage(
                        userText: text.isEmpty ? '老闆，這個價格可以談嗎？' : text,
                        targetPrice: proposedPrice,
                        quantity: proposedQuantity,
                        supplierId: supplier.id,
                        itemId: activeItem.id,
                      );
                      msgController.clear();
                    },
              icon: state.isNegotiating
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded, size: 16),
              label: Text(state.isNegotiating ? '對方思考中…' : '送出議價'),
            ),
          ),
        ],
      ),
    );
  }
}

class _NegotiationLog extends StatelessWidget {
  final GameState state;
  const _NegotiationLog({required this.state});

  @override
  Widget build(BuildContext context) {
    final history = state.negotiationHistory.reversed.take(10).toList();
    return SectionCard(
      title: '洽談紀錄',
      icon: Icons.forum_rounded,
      trailing: Pill(state.currentAiEngine, color: AppColors.textMuted),
      child: history.isEmpty
          ? const EmptyHint(icon: Icons.chat_bubble_outline_rounded, message: '還沒有洽談紀錄')
          : Column(
              children: [for (final m in history) _Bubble(msg: m)],
            ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final NegotiationMessage msg;
  const _Bubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    final outcome = msg.outcome;
    final (label, color) = switch (outcome?.status) {
      NegotiationStatus.agreed => ('成交', AppColors.good),
      NegotiationStatus.counterOffer => ('還價', AppColors.warning),
      NegotiationStatus.rejected => ('回絕', AppColors.critical),
      _ => ('', AppColors.textMuted),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: msg.isUser ? AppColors.surfaceHigh : AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(msg.sender,
                  style: AppText.label.copyWith(
                      color: msg.isUser ? AppColors.accentSoft : AppColors.textPrimary)),
              const Spacer(),
              if (label.isNotEmpty) Pill(label, color: color, filled: true),
            ],
          ),
          const SizedBox(height: 5),
          Text(msg.text, style: AppText.body),
          if (outcome != null && outcome.status != NegotiationStatus.rejected) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              '成交單價 \$${outcome.agreedUnitPrice.toStringAsFixed(0)}'
              ' · 好感 ${outcome.relationshipChange >= 0 ? '+' : ''}${outcome.relationshipChange}',
              style: AppText.caption.copyWith(color: color),
            ),
          ],
        ],
      ),
    );
  }
}
