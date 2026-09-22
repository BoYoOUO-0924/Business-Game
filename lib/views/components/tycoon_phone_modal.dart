import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/game_state.dart';
import '../../services/audio_service.dart';

/// 商業大亨專用 SmartOS 智慧公務手機 (Executive SmartOS Phone)
/// 包含天使投資認領、即時商業新聞快訊、商業銀行信貸與企業估值
class TycoonPhoneModal extends StatefulWidget {
  const TycoonPhoneModal({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const TycoonPhoneModal(),
    );
  }

  @override
  State<TycoonPhoneModal> createState() => _TycoonPhoneModalState();
}

class _TycoonPhoneModalState extends State<TycoonPhoneModal> {
  int _activeAppIndex = 0; // 0: 簡訊 (Uncle Fred), 1: 商業快訊, 2: 銀行信貸
  final NumberFormat _currency = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GameState>();
    final c = state.company;

    return Center(
      child: Container(
        width: 380,
        height: MediaQuery.of(context).size.height * 0.85,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(44),
          border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.6), width: 3.0),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.8), blurRadius: 36, spreadRadius: 6),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(41),
          child: Column(
            children: [
              // 1. 靈動島與頂部狀態列
              Container(
                height: 46,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                color: const Color(0xFF1E293B),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      c.timeFormatted.split(' ').last,
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    // 靈動島
                    Container(
                      width: 80,
                      height: 18,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const Row(
                      children: [
                        Icon(Icons.signal_cellular_alt_rounded, color: Colors.white, size: 14),
                        SizedBox(width: 4),
                        Icon(Icons.wifi_rounded, color: Colors.white, size: 14),
                        SizedBox(width: 4),
                        Text('100%', style: TextStyle(color: Colors.white, fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ),

              // 2. 應用程式切換標籤列 (Messenger, News, Bank)
              Container(
                color: const Color(0xFF1E293B),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    _tabButton(0, '親友簡訊', Icons.chat_bubble_rounded, !state.hasClaimedUncleGift),
                    const SizedBox(width: 6),
                    _tabButton(1, '商業快訊', Icons.newspaper_rounded, state.activeEvent != null),
                    const SizedBox(width: 6),
                    _tabButton(2, '網銀信貸', Icons.account_balance_rounded, false),
                  ],
                ),
              ),

              // 3. 內容分頁
              Expanded(
                child: Container(
                  color: const Color(0xFF0F172A),
                  child: _buildActivePage(context, state),
                ),
              ),

              // 4. 底部 Home Bar
              Container(
                height: 36,
                alignment: Alignment.center,
                color: const Color(0xFF1E293B),
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 120,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.white38,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tabButton(int index, String label, IconData icon, bool hasBadge) {
    final isSelected = _activeAppIndex == index;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeAppIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF38BDF8).withValues(alpha: 0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? const Color(0xFF38BDF8) : Colors.transparent),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: isSelected ? const Color(0xFF38BDF8) : Colors.white60),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? const Color(0xFF38BDF8) : Colors.white70,
                  fontSize: 11.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              if (hasBadge) ...[
                const SizedBox(width: 4),
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActivePage(BuildContext context, GameState state) {
    switch (_activeAppIndex) {
      case 0:
        return _buildUncleMessagePage(context, state);
      case 1:
        return _buildMarketNewsPage(context, state);
      case 2:
        return _buildBankCreditPage(context, state);
      default:
        return const SizedBox();
    }
  }

  // --- 簡訊 App：Fred 叔叔天使啟動金 ---
  Widget _buildUncleMessagePage(BuildContext context, GameState state) {
    final hasClaimed = state.hasClaimedUncleGift;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            const CircleAvatar(
              backgroundColor: Color(0xFFF97316),
              radius: 20,
              child: Text('👨‍💼', style: TextStyle(fontSize: 20)),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Fred 叔叔 (天使投資人)', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                Text('在線 · 剛剛發來新消息', style: TextStyle(color: Color(0xFF10B981), fontSize: 11)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 訊息對話泡泡
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white12),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '「姪兒！聽說你隻身抵達大都會，準備在舊城幸福里開拓你的第一家連鎖便利超商！\n\n萬事起頭難，做零售最重要的是【現金流】與【合適的貨架設備】。叔叔匯了 \$10,000 當作你的第一筆天使創業基金，快點領取去添購飲料冰櫃和補齊零食吧！好好幹，讓全都會看看你的商業天賦！」',
                style: TextStyle(color: Colors.white, fontSize: 13, height: 1.5),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // 領取按鈕卡片
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF065F46), Color(0xFF047857)]),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: const Color(0xFF10B981).withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.monetization_on_rounded, color: Color(0xFFFBBF24), size: 28),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('天使創業基金支票', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                      Text('+NT\$ 10,000 啟動金', style: const TextStyle(color: Color(0xFFFDE68A), fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: hasClaimed ? Colors.white24 : const Color(0xFFFBBF24),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: hasClaimed
                      ? null
                      : () {
                          state.claimUncleGift();
                          AudioService().playFanfare();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              backgroundColor: Color(0xFF10B981),
                              content: Text('🎉 成功領取天使啟動金！+NT\$ 10,000 已匯入企業現金帳戶！'),
                            ),
                          );
                        },
                  child: Text(
                    hasClaimed ? '✓ 已存入企業網銀' : '立即點擊兌現 (+NT\$ 10,000)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: hasClaimed ? Colors.white54 : Colors.black,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- 商業快訊 App ---
  Widget _buildMarketNewsPage(BuildContext context, GameState state) {
    final active = state.activeEvent;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Row(
          children: [
            Icon(Icons.feed_rounded, color: Color(0xFF38BDF8), size: 20),
            SizedBox(width: 8),
            Text('都會商業前沿觀察報', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 12),

        if (active != null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: const Color(0xFFF59E0B), borderRadius: BorderRadius.circular(6)),
                      child: const Text('🚨 即時熱點', style: TextStyle(color: Colors.black, fontSize: 10.5, fontWeight: FontWeight.bold)),
                    ),
                    Text('剩餘 ${active.hoursRemaining} 小時', style: const TextStyle(color: Color(0xFFFBBF24), fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(active.title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(active.description, style: const TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.4)),
              ],
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(16)),
            child: const Text('目前市場波瀾不驚，供需平穩。隨時留意季節更替、競品價格戰與全城行銷脈動！', style: TextStyle(color: Colors.white60, fontSize: 12.5)),
          ),

        const SizedBox(height: 16),
        const Text('都會歷史商業大事件', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _newsHistoryItem('🔥 盛夏熱浪席捲都會', '氣溫飆升至 38 度，全城冷飲與現煮冰咖啡需求暴增 120%。'),
        _newsHistoryItem('🎓 大學城期末考週開幕', '大學生熬夜狂歡，深夜宵夜泡麵與能量提神飲料銷售突破歷史新高。'),
        _newsHistoryItem('💻 科技園區黑客松創投會', '工程師高薪消費力展現，精品咖啡與現做便當搶購一空。'),
      ],
    );
  }

  Widget _newsHistoryItem(String title, String desc) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFF18181B), borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(desc, style: const TextStyle(color: Colors.white54, fontSize: 11)),
        ],
      ),
    );
  }

  // --- 銀行信貸 App ---
  Widget _buildBankCreditPage(BuildContext context, GameState state) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            const Icon(Icons.account_balance_rounded, color: Color(0xFF34D399), size: 20),
            const SizedBox(width: 8),
            const Text('大都會商業銀行 · 企業信貸', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 14),

        // 企業財務評估卡
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            children: [
              _bankRow('企業商譽等級', '${state.company.reputation} 分 (AAA級)', const Color(0xFFFBBF24)),
              const Divider(color: Colors.white10, height: 16),
              _bankRow('現有流動資金', _currency.format(state.company.cash), const Color(0xFF34D399)),
              const Divider(color: Colors.white10, height: 16),
              _bankRow('最高核貸額度', '\$50,000', const Color(0xFF38BDF8)),
              const Divider(color: Colors.white10, height: 16),
              _bankRow('借款年化利率', '5.2% (免抵押保證)', Colors.white70),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // 借款快速操作
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF34D399),
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          icon: const Icon(Icons.paid_rounded, size: 20),
          label: const Text('申請 \$20,000 應急擴張週轉金', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          onPressed: () {
            state.company.cash += 20000.0;
            state.businessLogs.insert(0, '🏦 【銀行融資】成功向大都會商業銀行借貸 \$20,000 週轉信貸！');
            AudioService().playCashRegister();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                backgroundColor: Color(0xFF10B981),
                content: Text('💰 \$20,000 信貸資金已撥款入帳！請注意資金使用效率！'),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _bankRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12.5)),
        Text(value, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
