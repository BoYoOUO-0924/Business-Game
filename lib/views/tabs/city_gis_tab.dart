import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/district.dart';
import '../../providers/game_state.dart';
import '../../services/audio_service.dart';

/// 都會商圈與展店地圖 (City Commercial GIS & Store Expansion)
/// 玩家在此勘查五大商圈、觀察客流與競品市佔率、簽約租鋪擴張分店、發動商圈行銷戰
class CityGisTab extends StatefulWidget {
  const CityGisTab({super.key});

  @override
  State<CityGisTab> createState() => _CityGisTabState();
}

class _CityGisTabState extends State<CityGisTab> {
  final NumberFormat _currency = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

  void _showLeaseDialog(BuildContext context, GameState state, District district) {
    final nameController = TextEditingController(text: '${district.name.substring(0, 2)}分店');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF18181B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xFF38BDF8), width: 1.5),
        ),
        title: Row(
          children: [
            Text(district.icon, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 8),
            Text('進駐【${district.name}】', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              district.description,
              style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black38,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                children: [
                  _dialogRow('月租金行情', _currency.format(district.monthlyRent)),
                  const SizedBox(height: 6),
                  _dialogRow('簽約保證金(押金)', _currency.format(district.depositRequired), isHighlight: true),
                  const SizedBox(height: 6),
                  _dialogRow('現有企業現金', _currency.format(state.company.cash), isCash: true, cashValue: state.company.cash),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text('為新門市命名：', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF27272A),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('再考慮', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF38BDF8),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              final storeName = nameController.text.trim();
              if (storeName.isEmpty) return;

              if (state.company.cash < district.depositRequired) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: Color(0xFFEF4444),
                    content: Text('⚠️ 企業現金不足以支付簽約保證金！'),
                  ),
                );
                return;
              }

              final success = state.leaseDistrict(district.id, storeName);
              Navigator.of(ctx).pop();

              if (success) {
                AudioService().playFanfare();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: const Color(0xFF10B981),
                    content: Text('🎉 恭喜！成功簽約進駐【${district.name}】！【$storeName】正式開幕！'),
                  ),
                );
              }
            },
            child: const Text('簽署租約並立項', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _dialogRow(String label, String value, {bool isHighlight = false, bool isCash = false, double cashValue = 0}) {
    Color valColor = isHighlight ? const Color(0xFFFBBF24) : Colors.white;
    if (isCash) valColor = cashValue >= 0 ? const Color(0xFF34D399) : const Color(0xFFEF4444);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
        Text(value, style: TextStyle(color: valColor, fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }

  void _showMarketingCampaignDialog(BuildContext context, GameState state, District district) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF18181B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.campaign_rounded, color: Color(0xFFF59E0B), size: 24),
                const SizedBox(width: 8),
                Text('在【${district.name}】策劃行銷大戰', style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            _campaignOption(
              ctx,
              state,
              title: '商圈傳單與社群打卡大派送',
              cost: 1500.0,
              desc: '在主要街道派發抵用券，吸引學生與上班族，來客數 +30% (持續 24 小時)',
              boost: 1.30,
              hours: 24,
            ),
            const SizedBox(height: 10),
            _campaignOption(
              ctx,
              state,
              title: '全店冷飲便當第二件 6 折大促銷',
              cost: 3500.0,
              desc: '發動價格戰重擊對手【${district.rivalName}】，全品項來客數 +60% (持續 48 小時)',
              boost: 1.60,
              hours: 48,
            ),
            const SizedBox(height: 10),
            _campaignOption(
              ctx,
              state,
              title: '明星網紅一日店長造勢活動',
              cost: 8000.0,
              desc: '邀請人氣網紅現場直播互動，引爆全都會排隊打卡狂潮，來客數 +120% (持續 36 小時)',
              boost: 2.20,
              hours: 36,
            ),
          ],
        ),
      ),
    );
  }

  Widget _campaignOption(
    BuildContext ctx,
    GameState state, {
    required String title,
    required double cost,
    required String desc,
    required double boost,
    required int hours,
  }) {
    final canAfford = state.company.cash >= cost;

    return InkWell(
      onTap: canAfford
          ? () {
              state.launchMarketingCampaign(
                campaignName: title,
                cost: cost,
                trafficMultiplier: boost,
                hours: hours,
              );
              Navigator.of(ctx).pop();
              AudioService().playCashRegister();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: const Color(0xFFF59E0B),
                  content: Text('📢 【$title】行銷大戰正式啟動！全城來客飆升！'),
                ),
              );
            }
          : null,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: canAfford ? const Color(0xFF27272A) : const Color(0xFF1E1E22),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: canAfford ? Colors.white24 : Colors.white10),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: canAfford ? Colors.white : Colors.white38, fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(desc, style: TextStyle(color: canAfford ? Colors.white70 : Colors.white30, fontSize: 11.5)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(_currency.format(cost), style: TextStyle(color: canAfford ? const Color(0xFFFBBF24) : Colors.white38, fontSize: 14, fontWeight: FontWeight.bold)),
                Text(canAfford ? '點擊啟動' : '資金不足', style: TextStyle(color: canAfford ? const Color(0xFF38BDF8) : Colors.redAccent, fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GameState>();
    final districts = state.districts;
    final leasedCount = districts.where((d) => d.isLeased).length;
    final totalTraffic = districts.where((d) => d.isLeased).fold(0, (sum, d) => sum + d.baseTrafficPerHour);
    final totalRent = districts.where((d) => d.isLeased).fold(0.0, (sum, d) => sum + d.monthlyRent);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      children: [
        // 1. 都會商業版圖總覽卡
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.4)),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 16, offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.map_rounded, color: Color(0xFF38BDF8), size: 20),
                      SizedBox(width: 8),
                      Text('都會商圈版圖 (Metropolis GIS)', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.3)),
                    ),
                    child: Text('已開拓 $leasedCount / ${districts.length} 大商圈', style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11.5, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _statPill('旗下營運門市', '$leasedCount 間', Icons.storefront_rounded, const Color(0xFF10B981)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _statPill('覆蓋商圈客流', '$totalTraffic 人/時', Icons.people_alt_rounded, const Color(0xFF38BDF8)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _statPill('月租金總負擔', _currency.format(totalRent), Icons.receipt_long_rounded, const Color(0xFFFB923C)),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // 2. 五大特色商圈列表
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('都會五大核心商圈', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
            Text('當前企業商譽：${state.company.reputation} 分', style: const TextStyle(color: Color(0xFFFBBF24), fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 10),

        ...districts.map((district) => _buildDistrictCard(context, state, district)),

        const SizedBox(height: 14),

        // 3. 連鎖規模效益提示
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF18181B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.workspace_premium_rounded, color: Color(0xFFFBBF24), size: 18),
                  SizedBox(width: 6),
                  Text('連鎖商業帝國・規模加成 (Synergy Perks)', style: TextStyle(color: Color(0xFFFBBF24), fontSize: 13, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              _perkRow('2 間門市', '成立區域物流集散統購，全品項進貨成本 -5%', leasedCount >= 2),
              _perkRow('3 間門市', '大都會品牌聯動效益，各分店基礎來客量 +15%', leasedCount >= 3),
              _perkRow('4 間門市', '供應鏈大宗議價話語權，全品項進貨成本 -10%', leasedCount >= 4),
              _perkRow('5 間全制霸', '榮膺大都會零售霸主，獲利加乘 +25% 並解鎖 IPO 上市資格', leasedCount >= 5),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statPill(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Text(label, style: const TextStyle(color: Colors.white60, fontSize: 9.5)),
            ],
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: TextStyle(color: color, fontSize: 12.5, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _perkRow(String condition, String benefit, bool unlocked) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(unlocked ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, size: 14, color: unlocked ? const Color(0xFF10B981) : Colors.white30),
          const SizedBox(width: 6),
          Text('【$condition】', style: TextStyle(color: unlocked ? Colors.white : Colors.white38, fontSize: 11.5, fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(benefit, style: TextStyle(color: unlocked ? Colors.white70 : Colors.white24, fontSize: 11.5)),
          ),
        ],
      ),
    );
  }

  Widget _buildDistrictCard(BuildContext context, GameState state, District district) {
    final isLeased = district.isLeased;
    final canUnlock = state.company.reputation >= district.minReputationRequired;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isLeased
              ? const Color(0xFF10B981).withValues(alpha: 0.6)
              : (canUnlock ? Colors.white24 : Colors.white10),
          width: isLeased ? 2.0 : 1.0,
        ),
        boxShadow: isLeased
            ? [
                BoxShadow(color: const Color(0xFF10B981).withValues(alpha: 0.15), blurRadius: 12, spreadRadius: 1),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 頂部標題與狀態標籤
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isLeased ? const Color(0xFF10B981).withValues(alpha: 0.2) : Colors.white10,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isLeased ? const Color(0xFF10B981) : Colors.white24),
                ),
                child: Text(district.icon, style: const TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(district.name, style: const TextStyle(color: Colors.white, fontSize: 15.5, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white12,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(district.tag, style: const TextStyle(color: Colors.white70, fontSize: 10)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(district.description, style: const TextStyle(color: Colors.white60, fontSize: 11.5)),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 10),

          // 核心商圈數值矩陣
          Row(
            children: [
              Expanded(
                child: _dataCol('人流規模', '${district.baseTrafficPerHour} 人/時', Icons.people_outline_rounded),
              ),
              Expanded(
                child: _dataCol('月租行情', _currency.format(district.monthlyRent), Icons.store_outlined),
              ),
              Expanded(
                child: _dataCol('主要競品', district.rivalName, Icons.business_outlined),
              ),
              Expanded(
                child: _dataCol('熱銷剛需', district.favoriteCategory, Icons.shopping_bag_outlined),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // 底部操作與進駐狀態
          if (isLeased)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 16),
                    const SizedBox(width: 6),
                    Text(district.branchStoreName ?? '已營運門市', style: const TextStyle(color: Color(0xFF10B981), fontSize: 13, fontWeight: FontWeight.bold)),
                  ],
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.campaign_rounded, size: 16),
                  label: const Text('策劃商圈促銷戰', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: () => _showMarketingCampaignDialog(context, state, district),
                ),
              ],
            )
          else if (canUnlock)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('店面待租賃招商中', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 12, fontWeight: FontWeight.bold)),
                    Text('簽約押金需 ${_currency.format(district.depositRequired)}', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                  ],
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF38BDF8),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.edit_note_rounded, size: 18),
                  label: const Text('簽約租鋪立項', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  onPressed: () => _showLeaseDialog(context, state, district),
                ),
              ],
            )
          else
            Row(
              children: [
                const Icon(Icons.lock_rounded, color: Colors.white38, size: 15),
                const SizedBox(width: 6),
                Text('未解鎖：需門市商譽達到 ${district.minReputationRequired.toInt()} 分（目前 ${state.company.reputation} 分）', style: const TextStyle(color: Colors.white38, fontSize: 11.5)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _dataCol(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 11, color: Colors.white38),
            const SizedBox(width: 3),
            Text(label, style: const TextStyle(color: Colors.white38, fontSize: 9.5)),
          ],
        ),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
      ],
    );
  }
}
