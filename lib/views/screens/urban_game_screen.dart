import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../models/player_life_state.dart';
import '../../services/audio_service.dart';
import '../components/smart_phone_modal.dart';
import '../main_dashboard_screen.dart';

/// 風格二：現代都會 Low-Poly 3D 微縮模型開局主畫面 (Urban Ambition Act 1)
/// 採用高精細 3D 微縮模型底圖 + 9:16 手機比例視圖 + 即時動態粒子 + 互動標籤 + 1:1 概念圖 HUD
class UrbanGameScreen extends StatefulWidget {
  final PlayerLifeState playerLife;

  const UrbanGameScreen({super.key, required this.playerLife});

  @override
  State<UrbanGameScreen> createState() => _UrbanGameScreenState();
}

class _UrbanGameScreenState extends State<UrbanGameScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  final List<_RainParticle> _rainParticles = [];
  final List<_RippleEffect> _ripples = [];
  final math.Random _rng = math.Random();
  final NumberFormat _currency = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

  Timer? _gameClockTimer;

  @override
  void initState() {
    super.initState();

    // 1. 動畫循環 (用於雨滴物理與光暈呼吸特效)
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _animCtrl.addListener(_updateFx);

    // 2. 獨立真實時間時鐘 (每 3 秒推進遊戲內 1 分鐘，避免 60fps 幀率暴走)
    _gameClockTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) {
        widget.playerLife.tick();
      }
    });

    // 進入第一幕時播放開局雨夜微音
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AudioService().playDoorChime();
    });
  }

  void _updateFx() {
    if (!mounted) return;

    // 生成雨滴微粒
    if (_rainParticles.length < 55) {
      _rainParticles.add(
        _RainParticle(
          x: _rng.nextDouble() * 500,
          y: -30,
          length: 16 + _rng.nextDouble() * 12,
          speed: 8 + _rng.nextDouble() * 5,
        ),
      );
    }

    // 更新雨滴位置
    for (int i = _rainParticles.length - 1; i >= 0; i--) {
      final r = _rainParticles[i];
      r.y += r.speed;
      r.x -= 2.0; // 傾斜細雨
      if (r.y > 900) {
        // 雨滴落到地面產生偶發漣漪
        if (_rng.nextDouble() < 0.25 && _ripples.length < 12) {
          _ripples.add(_RippleEffect(x: r.x, y: 700 + _rng.nextDouble() * 150));
        }
        _rainParticles.removeAt(i);
      }
    }

    // 更新水窪漣漪
    for (int i = _ripples.length - 1; i >= 0; i--) {
      _ripples[i].radius += 0.4;
      _ripples[i].opacity -= 0.02;
      if (_ripples[i].opacity <= 0.0) {
        _ripples.removeAt(i);
      }
    }

    setState(() {});
  }

  @override
  void dispose() {
    _animCtrl.removeListener(_updateFx);
    _animCtrl.dispose();
    _gameClockTimer?.cancel();
    super.dispose();
  }

  // --- 互動彈窗 ---

  void _showApartmentSleepDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1B29),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Text('🏠 ', style: TextStyle(fontSize: 22)),
            Text('街角出租套房', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '推開老木門，頂樓小套房裡放著一張折疊床和小冰箱。叔叔說的鑰匙確實壓在門墊底下。',
              style: TextStyle(color: Colors.white70, fontSize: 13.5, height: 1.45),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.5)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.bed_rounded, color: Color(0xFF38BDF8), size: 24),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '在折疊床上睡到明日早晨 07:00\n(⚡ 體力回滿至 100%，放下旅行皮箱)',
                      style: TextStyle(color: Color(0xFF38BDF8), fontSize: 12.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('稍後再睡', style: TextStyle(color: Colors.white60)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF38BDF8),
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              widget.playerLife.sleepInApartment();
              AudioService().playFanfare();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  backgroundColor: Color(0xFF0284C7),
                  content: Text('🛌 睡了一個好覺！體力完全恢復至 100%，早晨 07:00 天亮了！皮箱已安放在房間裡。'),
                ),
              );
            },
            child: const Text('立刻入睡', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showCityMartDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF18181B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF97316).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.storefront_rounded, color: Color(0xFFF97316), size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CITY MART 街角門市',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        '幸福里老牌超商 · 24 小時營業',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  icon: const Icon(Icons.close_rounded, color: Colors.white60),
                ),
              ],
            ),
            const Divider(color: Colors.white12, height: 24),
            ListTile(
              leading: const Icon(Icons.dashboard_customize_rounded, color: Color(0xFF38BDF8)),
              title: const Text('進入連鎖超商後台管理系統', style: TextStyle(color: Colors.white, fontSize: 14)),
              subtitle: const Text('檢視進銷存、貨架微觀操作、人事排班與批發商談判', style: TextStyle(color: Colors.white54, fontSize: 11)),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white30, size: 14),
              onTap: () {
                Navigator.of(ctx).pop();
                AudioService().playScanBeep();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const MainDashboardScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.work_history_rounded, color: Color(0xFFFBBF24)),
              title: const Text('在 CITY MART 兼職打工', style: TextStyle(color: Colors.white, fontSize: 14)),
              subtitle: const Text('值班 4 小時整理貨架與結帳，賺取 NT\$ 600 現金', style: TextStyle(color: Colors.white54, fontSize: 11)),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white30, size: 14),
              onTap: () {
                Navigator.of(ctx).pop();
                if (widget.playerLife.energy >= 48) {
                  widget.playerLife.takePartTimeShift(hours: 4, hourlyWage: 150);
                  AudioService().playCashRegister();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      backgroundColor: Color(0xFF10B981),
                      content: Text('💼 兼職打工 4 小時完成！現領薪資 +NT\$ 600 入帳！'),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      backgroundColor: Color(0xFFDC2626),
                      content: Text('⚠️ 體力不足！請先回出租公寓折疊床睡一覺再來打工。'),
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showTaxiDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1B29),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Text('🚖 ', style: TextStyle(fontSize: 22)),
            Text('大都會計程車呼叫站', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          '目前您正位於「舊城幸福里」。\n\n隨著主線商業擴展，後續章節將可搭乘計程車前往「中央金融 CBD」、「海濱觀光文創區」與「高新科技園區」簽署新門市店租！',
          style: TextStyle(color: Colors.white70, fontSize: 13.5, height: 1.45),
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFACC15), foregroundColor: Colors.black),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('了解', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showFoodDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1B29),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Text('🍱 ', style: TextStyle(fontSize: 22)),
            Text('街角便當小吃店', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '剛下火車飢腸轆轆，熱騰騰的排骨便當傳來撲鼻香氣。',
              style: TextStyle(color: Colors.white70, fontSize: 13.5),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFB923C).withValues(alpha: 0.5)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.restaurant_rounded, color: Color(0xFFFB923C), size: 22),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '招牌排骨便當：NT\$ 80\n(🍴 飽食度 +25%，幸福感 +5%)',
                      style: TextStyle(color: Color(0xFFFB923C), fontSize: 12.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('暫不購買', style: TextStyle(color: Colors.white60)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFB923C), foregroundColor: Colors.black),
            onPressed: () {
              Navigator.of(ctx).pop();
              if (widget.playerLife.personalCash >= 80) {
                widget.playerLife.eatFood(restore: 25, cost: 80);
                AudioService().playScanBeep();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: Color(0xFFEA580C),
                    content: Text('😋 便當真香！飽食度 +25%，花費 NT\$ 80。'),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: Color(0xFFDC2626),
                    content: Text('⚠️ 現金不足！請先點擊手機領取叔叔贈送的啟動金。'),
                  ),
                );
              }
            },
            child: const Text('購買並享用', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // --- 主視圖構建 ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0A10),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // 9:16 手機比例自我適配容器
            final isWide = (constraints.maxWidth / constraints.maxHeight) > (9.0 / 16.0);
            final targetWidth = isWide
                ? math.min(constraints.maxWidth, constraints.maxHeight * (9.0 / 16.0))
                : constraints.maxWidth;
            final targetHeight = constraints.maxHeight;

            return Center(
              child: Container(
                width: targetWidth,
                height: targetHeight,
                decoration: BoxDecoration(
                  color: const Color(0xFF14131A),
                  borderRadius: isWide ? BorderRadius.circular(28) : BorderRadius.zero,
                  border: isWide ? Border.all(color: const Color(0xFF27272A), width: 3.5) : null,
                  boxShadow: isWide
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.8),
                            blurRadius: 40,
                            spreadRadius: 6,
                          ),
                        ]
                      : null,
                ),
                child: ClipRRect(
                  borderRadius: isWide ? BorderRadius.circular(24) : BorderRadius.zero,
                  child: AnimatedBuilder(
                    animation: widget.playerLife,
                    builder: (context, _) {
                      return Stack(
                        children: [
                          // 1. 純淨 3D Low-Poly 微縮原畫底圖 (滿版填滿 9:16 容器)
                          Positioned.fill(
                            child: Image.asset(
                              'assets/images/urban_diorama_clean.jpg',
                              fit: BoxFit.cover,
                              alignment: Alignment.center,
                            ),
                          ),

                          // 2. 即時雨滴與漣漪粒子物理層 (動態 CustomPaint)
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _AtmosphericFxPainter(
                                rainParticles: _rainParticles,
                                ripples: _ripples,
                                pulseRatio: _animCtrl.value,
                              ),
                            ),
                          ),

                          // 3. 立體互動熱區標籤 (Interactive Hotspots)
                          // [熱區 A] CITY MART 門市 (Top 45%, Left 12%)
                          Positioned(
                            top: targetHeight * 0.44,
                            left: targetWidth * 0.10,
                            child: _buildInteractiveTag(
                              icon: Icons.storefront_rounded,
                              title: 'CITY MART',
                              subtitle: '老鋪 (24H)',
                              color: const Color(0xFFF97316),
                              pulse: _animCtrl.value,
                              onTap: _showCityMartDialog,
                            ),
                          ),

                          // [熱區 B] 街角出租套房 (Top 22%, Left 48%)
                          Positioned(
                            top: targetHeight * 0.22,
                            left: targetWidth * 0.46,
                            child: _buildInteractiveTag(
                              icon: Icons.bed_rounded,
                              title: '出租套房',
                              subtitle: '折疊床・回滿體力',
                              color: const Color(0xFF38BDF8),
                              pulse: _animCtrl.value,
                              onTap: _showApartmentSleepDialog,
                            ),
                          ),

                          // [熱區 C] 城市計程車 (Top 51%, Left 58%)
                          Positioned(
                            top: targetHeight * 0.50,
                            left: targetWidth * 0.56,
                            child: _buildInteractiveTag(
                              icon: Icons.local_taxi_rounded,
                              title: '計程車站',
                              subtitle: '前往其他商圈',
                              color: const Color(0xFFFACC15),
                              pulse: _animCtrl.value,
                              onTap: _showTaxiDialog,
                            ),
                          ),

                          // [熱區 D] 主角定位光圈 (Top 67%, Left 38%)
                          Positioned(
                            top: targetHeight * 0.66,
                            left: targetWidth * 0.36,
                            child: _buildProtagonistBeacon(pulse: _animCtrl.value),
                          ),

                          // 4. 頂部 1:1 概念圖精緻 HUD
                          Positioned(
                            top: 12,
                            left: 14,
                            right: 14,
                            child: _buildTopHud(),
                          ),

                          // 5. 左下角生存快捷操作 (便當/打工)
                          Positioned(
                            bottom: 22,
                            left: 16,
                            child: _buildQuickSurvivalButtons(),
                          ),

                          // 6. 右下角公務手機 SmartOS 懸浮鍵 (含未讀簡訊紅點與氣泡)
                          Positioned(
                            bottom: 22,
                            right: 16,
                            child: _buildSmartPhoneWidget(),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // --- UI 子元件建置 ---

  /// 頂部 1:1 概念圖風格 HUD
  Widget _buildTopHud() {
    final life = widget.playerLife;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 上排：三大指標
        Row(
          children: [
            // ⚡ ENERGY
            Expanded(
              child: _buildVitalPill(
                icon: Icons.flash_on_rounded,
                iconColor: const Color(0xFF38BDF8),
                label: 'ENERGY',
                valueText: '${life.energy.toInt()}/100',
                ratio: (life.energy / 100.0).clamp(0.0, 1.0),
                fillGradient: const [Color(0xFF38BDF8), Color(0xFF0284C7)],
              ),
            ),
            const SizedBox(width: 8),

            // 🍴 HUNGER
            Expanded(
              child: _buildVitalPill(
                icon: Icons.restaurant_rounded,
                iconColor: const Color(0xFFFB923C),
                label: 'HUNGER',
                valueText: '${life.hunger.toInt()}/100',
                ratio: (life.hunger / 100.0).clamp(0.0, 1.0),
                fillGradient: const [Color(0xFFFB923C), Color(0xFFEA580C)],
              ),
            ),
            const SizedBox(width: 8),

            // 🪙 CASH
            _buildCashPill(life.personalCash),
          ],
        ),
        const SizedBox(height: 8),

        // 下排：主線任務指引條
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.80),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 10,
              ),
            ],
          ),
          child: Row(
            children: [
              const Text('📜 ', style: TextStyle(fontSize: 13)),
              Expanded(
                child: Text(
                  life.currentQuest,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                life.timeFormatted,
                style: const TextStyle(color: Color(0xFFFBBF24), fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVitalPill({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String valueText,
    required double ratio,
    required List<Color> fillGradient,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF181724).withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: iconColor.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, color: iconColor, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: TextStyle(
                      color: iconColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              Text(
                valueText,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(
              children: [
                Container(height: 5, color: Colors.white12),
                FractionallySizedBox(
                  widthFactor: ratio,
                  child: Container(
                    height: 5,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: fillGradient),
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

  Widget _buildCashPill(double cash) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2E2412), Color(0xFF1E160A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFBBF24).withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.25),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.monetization_on_rounded, color: Color(0xFFFBBF24), size: 16),
          const SizedBox(width: 5),
          Text(
            _currency.format(cash),
            style: const TextStyle(
              color: Color(0xFFFDE68A),
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  /// 互動標籤卡片
  Widget _buildInteractiveTag({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required double pulse,
    required VoidCallback onTap,
  }) {
    final glow = 0.4 + 0.3 * math.sin(pulse * math.pi * 2);

    return GestureDetector(
      onTap: () {
        AudioService().playScanBeep();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF18181B).withValues(alpha: 0.90),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.8), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: glow),
              blurRadius: 12,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 14),
            ),
            const SizedBox(width: 7),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold),
                ),
                Text(
                  subtitle,
                  style: TextStyle(color: color, fontSize: 9.5),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 主角定位信標
  Widget _buildProtagonistBeacon({required double pulse}) {
    final scale = 1.0 + 0.15 * math.sin(pulse * math.pi * 2);
    final life = widget.playerLife;

    return GestureDetector(
      onTap: () {
        AudioService().playScanBeep();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF1E293B),
            content: Text(
              life.isCarryingSuitcase
                  ? '💼 主角：手提著皮箱初抵大都會，長途跋涉有點累了，請先前往套房折疊床睡一覺。'
                  : '👤 主角：已安頓在出租公寓，準備在這座大都會大展拳腳！',
            ),
          ),
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Transform.scale(
            scale: scale,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFFBBF24),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFBBF24).withValues(alpha: 0.6),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(life.isCarryingSuitcase ? '💼 ' : '👤 ', style: const TextStyle(fontSize: 10)),
                  Text(
                    life.isCarryingSuitcase ? '提著皮箱' : '主角',
                    style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
          const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFFFBBF24), size: 16),
        ],
      ),
    );
  }

  /// 左下角生存快捷鍵
  Widget _buildQuickSurvivalButtons() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 🍱 便當
        GestureDetector(
          onTap: _showFoodDialog,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1B29).withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFB923C).withValues(alpha: 0.7)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('🍱 ', style: TextStyle(fontSize: 13)),
                Text('吃便當', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),

        // 💼 打工
        GestureDetector(
          onTap: _showCityMartDialog,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1B29).withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.7)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('💼 ', style: TextStyle(fontSize: 13)),
                Text('超商打工', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 右下角公務手機 SmartOS 按鈕
  Widget _buildSmartPhoneWidget() {
    final hasUnread = !widget.playerLife.hasReadUncleMessage;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 未讀簡訊提示氣泡
        if (hasUnread)
          GestureDetector(
            onTap: () => SmartPhoneModal.show(context, widget.playerLife),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              constraints: const BoxConstraints(maxWidth: 220),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF38BDF8)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF38BDF8).withValues(alpha: 0.35),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('👴 ', style: TextStyle(fontSize: 13)),
                  Expanded(
                    child: Text(
                      '叔叔發來新簡訊！點擊查看',
                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // 智慧手機外觀按鈕
        GestureDetector(
          onTap: () => SmartPhoneModal.show(context, widget.playerLife),
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF27272A), Color(0xFF09090B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF71717A), width: 2.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.8),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(Icons.smartphone_rounded, color: Colors.white, size: 28),

                // 未讀紅點
                if (hasUnread)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// --- 物理粒子模型與 Painter ---

class _RainParticle {
  double x;
  double y;
  final double length;
  final double speed;

  _RainParticle({required this.x, required this.y, required this.length, required this.speed});
}

class _RippleEffect {
  double x;
  double y;
  double radius = 1.0;
  double opacity = 0.5;

  _RippleEffect({required this.x, required this.y});
}

class _AtmosphericFxPainter extends CustomPainter {
  final List<_RainParticle> rainParticles;
  final List<_RippleEffect> ripples;
  final double pulseRatio;

  _AtmosphericFxPainter({
    required this.rainParticles,
    required this.ripples,
    required this.pulseRatio,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. 細雨雨絲
    final rainPaint = Paint()
      ..color = const Color(0xFF93C5FD).withValues(alpha: 0.45)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    for (final r in rainParticles) {
      if (r.x >= 0 && r.x <= size.width && r.y >= 0 && r.y <= size.height) {
        canvas.drawLine(
          Offset(r.x, r.y),
          Offset(r.x - 3.5, r.y + r.length),
          rainPaint,
        );
      }
    }

    // 2. 地面水窪微漣漪
    for (final rip in ripples) {
      if (rip.x >= 0 && rip.x <= size.width && rip.y >= 0 && rip.y <= size.height) {
        final ripplePaint = Paint()
          ..color = const Color(0xFFE2E8F0).withValues(alpha: rip.opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0;
        canvas.drawOval(
          Rect.fromCenter(center: Offset(rip.x, rip.y), width: rip.radius * 3.0, height: rip.radius * 1.5),
          ripplePaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AtmosphericFxPainter oldDelegate) => true;
}
