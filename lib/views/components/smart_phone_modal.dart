import 'package:flutter/material.dart';
import '../../models/player_life_state.dart';
import '../../services/audio_service.dart';

/// 懸浮滑出式智慧型公務手機 (In-Game SmartOS Modal)
class SmartPhoneModal extends StatelessWidget {
  final PlayerLifeState playerLife;
  final VoidCallback onClose;

  const SmartPhoneModal({
    super.key,
    required this.playerLife,
    required this.onClose,
  });

  static void show(BuildContext context, PlayerLifeState playerLife) {
    playerLife.markUncleMessageRead();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SmartPhoneModal(
        playerLife: playerLife,
        onClose: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 380,
        height: MediaQuery.of(context).size.height * 0.85,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        decoration: BoxDecoration(
          color: const Color(0xFF101014),
          borderRadius: BorderRadius.circular(44),
          border: Border.all(color: const Color(0xFF3F3F46), width: 3.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.8),
              blurRadius: 32,
              spreadRadius: 8,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(40),
          child: Column(
            children: [
              // 1. 手機頂部靈動島與狀態列 (Status Bar)
              Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                color: const Color(0xFF18181B),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${playerLife.hour.toString().padLeft(2, '0')}:${playerLife.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    // 靈動島藥丸
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
                        Text('98%', style: TextStyle(color: Colors.white, fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ),

              // 2. 簡訊 App 頂部導航列 (Messenger Header)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: const BoxDecoration(
                  color: Color(0xFF1F1F24),
                  border: Border(bottom: BorderSide(color: Colors.white12)),
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: onClose,
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF38BDF8), size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 12),
                    // 叔叔頭像
                    Stack(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF3F3F46),
                            border: Border.all(color: Colors.white30),
                          ),
                          child: const Center(
                            child: Text('👴', style: TextStyle(fontSize: 20)),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.black, width: 1.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '叔叔 (Uncle Fred)',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          Text(
                            '線上 · 舊城幸福里聯絡人',
                            style: TextStyle(color: Color(0xFF10B981), fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: onClose,
                      icon: const Icon(Icons.close_rounded, color: Colors.white60),
                    ),
                  ],
                ),
              ),

              // 3. 對話訊息內容區 (Chat Bubbles)
              Expanded(
                child: Container(
                  color: const Color(0xFF121216),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text('今天 19:14', style: TextStyle(color: Colors.white54, fontSize: 11)),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 叔叔第 1 則訊息
                      _buildUncleMessage(
                        '嘿！小子，歡迎來到這座大都會。我在街角借了你一間便宜的出租套房，鑰匙就在門墊底下。',
                      ),
                      const SizedBox(height: 12),

                      // 叔叔第 2 則訊息
                      _buildUncleMessage(
                        '另外我先轉了 \$10,000 到你帳戶，這筆錢是你在這座城市活下去的底氣！',
                      ),
                      const SizedBox(height: 12),

                      // 轉帳領取卡片 (Transfer Card)
                      AnimatedBuilder(
                        animation: playerLife,
                        builder: (context, _) {
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: playerLife.hasClaimedUncleGift
                                    ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                                    : [const Color(0xFFD97706), const Color(0xFFB45309)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: playerLife.hasClaimedUncleGift ? Colors.white24 : const Color(0xFFFDE68A),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: playerLife.hasClaimedUncleGift
                                      ? Colors.transparent
                                      : const Color(0xFFD97706).withValues(alpha: 0.4),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
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
                                        Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 20),
                                        SizedBox(width: 8),
                                        Text(
                                          '都會商業網銀 · 啟動資金轉帳',
                                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.black26,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        playerLife.hasClaimedUncleGift ? '已入帳' : '待領取',
                                        style: TextStyle(
                                          color: playerLife.hasClaimedUncleGift ? const Color(0xFF10B981) : Colors.amberAccent,
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                const Text('轉入金額：', style: TextStyle(color: Colors.white70, fontSize: 11.5)),
                                const Text(
                                  '+NT\$ 10,000',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: playerLife.hasClaimedUncleGift
                                          ? const Color(0xFF334155)
                                          : const Color(0xFFFEF08A),
                                      foregroundColor: playerLife.hasClaimedUncleGift ? Colors.white70 : Colors.black,
                                      elevation: playerLife.hasClaimedUncleGift ? 0 : 4,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    onPressed: playerLife.hasClaimedUncleGift
                                        ? null
                                        : () {
                                            final success = playerLife.claimUncleGift();
                                            if (success) {
                                              AudioService().playCashRegister();
                                              AudioService().playFanfare();
                                            }
                                          },
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          playerLife.hasClaimedUncleGift
                                              ? Icons.check_circle_rounded
                                              : Icons.touch_app_rounded,
                                          size: 18,
                                          color: playerLife.hasClaimedUncleGift ? const Color(0xFF10B981) : Colors.black,
                                        ),
                                        const SizedBox(width: 6),
                                        Flexible(
                                          child: Text(
                                            playerLife.hasClaimedUncleGift
                                                ? '已存入網銀 (+NT\$ 10,000)'
                                                : '領取啟動金 (+NT\$ 10,000)',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),

                      // 叔叔第 3 則訊息
                      _buildUncleMessage(
                        '長途跋涉累壞了吧？先回套房睡一覺，明天我們再來談談怎麼在這座城市闖天下。 - 叔叔',
                      ),
                    ],
                  ),
                ),
              ),

              // 4. 手機底部功能選單與 Home Indicator
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                color: const Color(0xFF18181B),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildPhoneAppIcon('💬', '簡訊', isSelected: true),
                        _buildPhoneAppIcon('🗺️', '地產'),
                        _buildPhoneAppIcon('🚚', '物流'),
                        _buildPhoneAppIcon('📈', '股市'),
                        _buildPhoneAppIcon('💼', '兼職'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // 底部 Home 橫條
                    Container(
                      width: 120,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white38,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUncleMessage(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFF3F3F46),
          ),
          child: const Center(child: Text('👴', style: TextStyle(fontSize: 16))),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF27272A),
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              border: Border.all(color: Colors.white10),
            ),
            child: Text(
              text,
              style: const TextStyle(color: Colors.white, fontSize: 13.5, height: 1.45),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneAppIcon(String emoji, String label, {bool isSelected = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF38BDF8).withValues(alpha: 0.25) : const Color(0xFF27272A),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? const Color(0xFF38BDF8) : Colors.white12,
            ),
          ),
          child: Center(
            child: Text(emoji, style: const TextStyle(fontSize: 18)),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
            color: isSelected ? const Color(0xFF38BDF8) : Colors.white54,
            fontSize: 10.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
