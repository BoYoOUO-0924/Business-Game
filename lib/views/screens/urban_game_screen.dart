import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../models/player_life_state.dart';
import '../../services/audio_service.dart';
import '../components/smart_phone_modal.dart';

/// 風格二：現代都會 Low-Poly 3D 微縮模型開局主畫面 (Urban Ambition Act 1)
class UrbanGameScreen extends StatefulWidget {
  final PlayerLifeState playerLife;

  const UrbanGameScreen({super.key, required this.playerLife});

  @override
  State<UrbanGameScreen> createState() => _UrbanGameScreenState();
}

class _UrbanGameScreenState extends State<UrbanGameScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  final List<_RainDrop> _rainDrops = [];
  final math.Random _rng = math.Random();
  final NumberFormat _currency = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

  // 主角位置 (以街區網格座標為基準，初始站在路口斑馬線旁 (3.5, 4.0))
  double _playerGx = 3.5;
  double _playerGy = 4.0;
  double _targetGx = 3.5;
  double _targetGy = 4.0;
  bool _isMoving = false;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    _animCtrl.addListener(_onTick);

    // 進入第一幕時播放開局雨夜微音與提示
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AudioService().playDoorChime();
    });
  }

  void _onTick() {
    if (!mounted) return;

    // 1. 生成雨絲微粒
    if (_rainDrops.length < 40) {
      _rainDrops.add(
        _RainDrop(
          x: _rng.nextDouble() * 500,
          y: -20,
          length: 12 + _rng.nextDouble() * 8,
          speed: 7 + _rng.nextDouble() * 4,
        ),
      );
    }

    // 更新雨滴
    for (int i = _rainDrops.length - 1; i >= 0; i--) {
      final r = _rainDrops[i];
      r.y += r.speed;
      r.x -= 1.5; // 斜雨
      if (r.y > 900) {
        _rainDrops.removeAt(i);
      }
    }

    // 2. 主角尋路平滑移動
    if (_isMoving) {
      final dx = _targetGx - _playerGx;
      final dy = _targetGy - _playerGy;
      final dist = math.sqrt(dx * dx + dy * dy);

      if (dist < 0.05) {
        _playerGx = _targetGx;
        _playerGy = _targetGy;
        _isMoving = false;
        _checkLocationTrigger();
      } else {
        _playerGx += (dx / dist) * 0.04;
        _playerGy += (dy / dist) * 0.04;
      }
    }

    // 3. 生活狀態自然代謝
    widget.playerLife.tick();

    setState(() {});
  }

  void _checkLocationTrigger() {
    // 抵達出租公寓門口 (gx: 1.0, gy: 2.0)
    if ((_playerGx - 1.0).abs() < 0.8 && (_playerGy - 2.0).abs() < 0.8) {
      _showApartmentSleepDialog();
    }
  }

  void _showApartmentSleepDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF22202A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Text('🏠 ', style: TextStyle(fontSize: 22)),
            Text('抵達出租老公寓', style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '推開老木門，頂樓小套房裡放著一張折疊床和小冰箱。鑰匙確實壓在門墊底下。',
              style: TextStyle(color: Colors.white70, fontSize: 13.5, height: 1.4),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF18181B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.bed_rounded, color: Color(0xFF38BDF8), size: 22),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '在折疊床上睡到明天清晨 07:00\n(體力回滿至 100%，放下旅行皮箱)',
                      style: TextStyle(color: Color(0xFF38BDF8), fontSize: 12),
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
                  content: Text('🛌 睡了一個好覺！體力已完全恢復至 100%，天亮了！'),
                ),
              );
            },
            child: const Text('立刻入睡', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _animCtrl.removeListener(_onTick);
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF14131A),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: widget.playerLife,
          builder: (context, _) {
            return Stack(
              children: [
                // 1. 風格二：現代都會 Low-Poly 3D 微縮模型畫布
                Positioned.fill(
                  child: GestureDetector(
                    onTapUp: (details) => _handleCanvasTap(details.localPosition),
                    child: CustomPaint(
                      painter: _LowPolyDioramaPainter(
                        playerGx: _playerGx,
                        playerGy: _playerGy,
                        isCarryingSuitcase: widget.playerLife.isCarryingSuitcase,
                        rainDrops: _rainDrops,
                      ),
                    ),
                  ),
                ),

                // 2. 頂部極簡手機 HUD (Energy, Hunger, Cash, Quest)
                Positioned(
                  top: 10,
                  left: 14,
                  right: 14,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 上排：生理指標與個人現金
                      Row(
                        children: [
                          // 體力條 (ENERGY 藍色進度條)
                          Expanded(
                            child: _buildHudBar(
                              icon: Icons.flash_on_rounded,
                              iconColor: const Color(0xFF38BDF8),
                              label: 'ENERGY',
                              value: '${widget.playerLife.energy.toInt()}/100',
                              ratio: widget.playerLife.energy / 100.0,
                              barColor: const Color(0xFF38BDF8),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // 飽食條 (HUNGER 橘色進度條)
                          Expanded(
                            child: _buildHudBar(
                              icon: Icons.restaurant_rounded,
                              iconColor: const Color(0xFFFB923C),
                              label: 'HUNGER',
                              value: '${widget.playerLife.hunger.toInt()}/100',
                              ratio: widget.playerLife.hunger / 100.0,
                              barColor: const Color(0xFFFB923C),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // 現金徽章 (CASH 金色)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1C1A24).withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFFFB800).withValues(alpha: 0.5)),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFFB800).withValues(alpha: 0.2),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('🪙 ', style: TextStyle(fontSize: 12)),
                                Text(
                                  _currency.format(widget.playerLife.personalCash),
                                  style: const TextStyle(
                                    color: Color(0xFFFFB800),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    fontFeatures: [FontFeature.tabularFigures()],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // 下排：主線任務指引膠囊
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Row(
                          children: [
                            const Text('📜 ', style: TextStyle(fontSize: 13)),
                            Expanded(
                              child: Text(
                                widget.playerLife.currentQuest,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              widget.playerLife.timeFormatted,
                              style: const TextStyle(color: Colors.white60, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // 3. 右下角懸浮智慧手機 SmartOS 按鈕 (附未讀紅點與提示氣泡)
                Positioned(
                  bottom: 20,
                  right: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 未讀簡訊提示氣泡
                      if (!widget.playerLife.hasReadUncleMessage)
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          constraints: const BoxConstraints(maxWidth: 220),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFF38BDF8)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.5),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('👴 ', style: TextStyle(fontSize: 14)),
                              Expanded(
                                child: Text(
                                  '叔叔發來新簡訊！點擊查看',
                                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // 智慧手機按鈕
                      GestureDetector(
                        onTap: () => SmartPhoneModal.show(context, widget.playerLife),
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF27272A), Color(0xFF09090B)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: !widget.playerLife.hasReadUncleMessage ? const Color(0xFF38BDF8) : Colors.white24,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: (!widget.playerLife.hasReadUncleMessage
                                    ? const Color(0xFF38BDF8).withValues(alpha: 0.4)
                                    : Colors.black.withValues(alpha: 0.5)),
                                blurRadius: 14,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              const Icon(Icons.phone_iphone_rounded, color: Colors.white, size: 30),
                              // 紅色未讀通知角標
                              if (!widget.playerLife.hasReadUncleMessage || !widget.playerLife.hasClaimedUncleGift)
                                Positioned(
                                  top: 10,
                                  right: 12,
                                  child: Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEF4444),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 4. 左下角操作提示
                Positioned(
                  bottom: 24,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      '💡 單指點擊人行道移動主角',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHudBar({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required double ratio,
    required Color barColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1A24).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
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
                  Icon(icon, color: iconColor, size: 12),
                  const SizedBox(width: 3),
                  Text(label, style: const TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.bold)),
                ],
              ),
              Text(value, style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 3),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: ratio.clamp(0.0, 1.0),
              minHeight: 4,
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
        ],
      ),
    );
  }

  void _handleCanvasTap(Offset localPos) {
    const double tileW = 46.0;
    const double tileH = 23.0;
    final cx = MediaQuery.of(context).size.width / 2;
    const cy = 180.0;

    final dx = localPos.dx - cx;
    final dy = localPos.dy - cy;

    final gx = (dx / (tileW / 2) + dy / (tileH / 2)) / 2;
    final gy = (dy / (tileH / 2) - dx / (tileW / 2)) / 2;

    // 設定主角目標移動座標 (限制在人行道與街區範圍)
    setState(() {
      _targetGx = gx.clamp(0.5, 5.5);
      _targetGy = gy.clamp(0.5, 5.5);
      _isMoving = true;
    });
  }
}

// -----------------------------------------------------------------------------
// 風格二：現代都會 Low-Poly 3D 微縮立體模型 CustomPainter
// -----------------------------------------------------------------------------
class _LowPolyDioramaPainter extends CustomPainter {
  final double playerGx;
  final double playerGy;
  final bool isCarryingSuitcase;
  final List<_RainDrop> rainDrops;

  _LowPolyDioramaPainter({
    required this.playerGx,
    required this.playerGy,
    required this.isCarryingSuitcase,
    required this.rainDrops,
  });

  static const double tileW = 46.0;
  static const double tileH = 23.0;

  Offset _iso(double gx, double gy, double cx, double cy, {double height = 0}) {
    final x = cx + (gx - gy) * (tileW / 2);
    final y = cy + (gx + gy) * (tileH / 2) - height;
    return Offset(x, y);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    const cy = 180.0;

    // 1. 黃昏暮光天空背景漸層 (Dusk Twilight)
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF2E2638), Color(0xFF181520), Color(0xFF0F0E14)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // 2. 遠景低多邊形大樓剪影 (Distant Low-Poly City Skyline)
    _drawSkyline(canvas, size);

    // 3. 地面柏油路與人行道路緣石 (Wet Asphalt Street & Sidewalk)
    _drawStreetAndSidewalk(canvas, cx, cy);

    // 4. 斑馬線與路面水坑倒影 (Crosswalk & Water Reflection)
    _drawCrosswalkAndPuddles(canvas, cx, cy);

    // 5. 實體建築與物件 (Y-Sorting 深度排序繪製)
    final List<_DioramaEntity> entities = [];

    // (1) 轉角超商 (City Mart) —— 帶有前牆剖面透視
    entities.add(
      _DioramaEntity(
        sortDepth: 1.5 + 4.0,
        render: (c) => _drawCutawayStore(c, cx, cy),
      ),
    );

    // (2) 叔叔的出租老舊公寓 (Apartment Building)
    entities.add(
      _DioramaEntity(
        sortDepth: 1.0 + 1.5,
        render: (c) => _drawApartmentBuilding(c, cx, cy),
      ),
    );

    // (3) 街頭黃色低多邊形計程車 (Yellow Taxi)
    entities.add(
      _DioramaEntity(
        sortDepth: 4.5 + 2.0,
        render: (c) => _drawLowPolyTaxi(c, cx, cy),
      ),
    );

    // (4) 立體路燈 (Street Lamp) 投射暖黃光錐
    entities.add(
      _DioramaEntity(
        sortDepth: 3.0 + 3.0,
        render: (c) => _drawStreetLamp(c, cx, cy),
      ),
    );

    // (5) 主角小人 (提著皮箱走動)
    entities.add(
      _DioramaEntity(
        sortDepth: playerGx + playerGy,
        render: (c) => _drawProtagonist(c, cx, cy),
      ),
    );

    // 依深度排序並繪製
    entities.sort((a, b) => a.sortDepth.compareTo(b.sortDepth));
    for (final e in entities) {
      e.render(canvas);
    }

    // 6. 雨絲微粒動畫 (Raindrops)
    final rainPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.28)
      ..strokeWidth = 1.2;
    for (final r in rainDrops) {
      canvas.drawLine(Offset(r.x, r.y), Offset(r.x - 3, r.y + r.length), rainPaint);
    }
  }

  void _drawSkyline(Canvas canvas, Size size) {
    final buildingPaint = Paint()..color = const Color(0xFF1E1C26);
    final litWindow = Paint()..color = const Color(0xFFFDE047).withValues(alpha: 0.7);

    // 遠處幾棟高低錯落的大樓方塊
    final bldgs = [
      {'x': 10.0, 'w': 50.0, 'h': 160.0},
      {'x': 70.0, 'w': 70.0, 'h': 210.0},
      {'x': 150.0, 'w': 45.0, 'h': 140.0},
      {'x': 210.0, 'w': 80.0, 'h': 240.0},
      {'x': 300.0, 'w': 65.0, 'h': 180.0},
    ];

    for (final b in bldgs) {
      final rect = Rect.fromLTWH(b['x']!, 120 - b['h']!, b['w']!, b['h']!);
      canvas.drawRect(rect, buildingPaint);

      // 大樓發光小方窗
      for (double wy = rect.top + 16; wy < rect.bottom - 20; wy += 22) {
        for (double wx = rect.left + 8; wx < rect.right - 10; wx += 14) {
          if ((wx + wy).toInt() % 3 != 0) {
            canvas.drawRect(Rect.fromLTWH(wx, wy, 6, 8), litWindow);
          }
        }
      }
    }
  }

  void _drawStreetAndSidewalk(Canvas canvas, double cx, double cy) {
    // 濕潤的深黑柏油路面
    final roadPaint = Paint()..color = const Color(0xFF18171F);
    final sidewalkPaint = Paint()..color = const Color(0xFF474454);
    final curbPaint = Paint()..color = const Color(0xFF6B677C);

    // 繪製 6x6 基礎網格
    for (int gx = 0; gx < 6; gx++) {
      for (int gy = 0; gy < 6; gy++) {
        final p0 = _iso(gx.toDouble(), gy.toDouble(), cx, cy);
        final p1 = _iso(gx + 1.0, gy.toDouble(), cx, cy);
        final p2 = _iso(gx + 1.0, gy + 1.0, cx, cy);
        final p3 = _iso(gx.toDouble(), gy + 1.0, cx, cy);

        final path = Path()
          ..moveTo(p0.dx, p0.dy)
          ..lineTo(p1.dx, p1.dy)
          ..lineTo(p2.dx, p2.dy)
          ..lineTo(p3.dx, p3.dy)
          ..close();

        // 劃分人行道 (靠近建築側 gx <= 3 && gy <= 3) 與馬路
        final isSidewalk = (gx <= 3 && gy <= 3);
        canvas.drawPath(path, isSidewalk ? sidewalkPaint : roadPaint);

        // 人行道路緣石凸起邊界
        if ((gx == 3 && gy <= 3) || (gy == 3 && gx <= 3)) {
          canvas.drawLine(p1, p2, curbPaint..strokeWidth = 2.0);
        }
      }
    }
  }

  void _drawCrosswalkAndPuddles(Canvas canvas, double cx, double cy) {
    // 斑馬線白色低多邊形色塊
    final stripePaint = Paint()..color = Colors.white.withValues(alpha: 0.85);

    for (int i = 0; i < 4; i++) {
      final p0 = _iso(3.2 + (i * 0.4), 4.0, cx, cy);
      final p1 = _iso(3.4 + (i * 0.4), 4.0, cx, cy);
      final p2 = _iso(3.4 + (i * 0.4), 5.2, cx, cy);
      final p3 = _iso(3.2 + (i * 0.4), 5.2, cx, cy);

      final path = Path()
        ..moveTo(p0.dx, p0.dy)
        ..lineTo(p1.dx, p1.dy)
        ..lineTo(p2.dx, p2.dy)
        ..lineTo(p3.dx, p3.dy)
        ..close();
      canvas.drawPath(path, stripePaint);
    }

    // 路面水窪倒影 (黃色路燈光暈映在水面上)
    final puddlePaint = Paint()
      ..color = const Color(0xFFFDE047).withValues(alpha: 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    final pPuddle = _iso(3.6, 3.8, cx, cy);
    canvas.drawOval(Rect.fromCenter(center: pPuddle, width: 36, height: 16), puddlePaint);
  }

  // --- 核心實體：轉角超商 (City Mart) 室內無縫剖面 ---
  void _drawCutawayStore(Canvas canvas, double cx, double cy) {
    final base = _iso(1.5, 4.0, cx, cy);

    // 1. 超商外框立體幾何建築
    final wallPaint = Paint()..color = const Color(0xFF2C2836);
    final glassInterior = Paint()..color = const Color(0xFFFFFBEB).withValues(alpha: 0.88); // 暖白室內光

    // 室內發光區域 (剖面無前牆)
    canvas.drawRect(
      Rect.fromCenter(center: Offset(base.dx, base.dy - 38), width: 74, height: 60),
      glassInterior,
    );

    // 外牆邊框
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(base.dx, base.dy - 40), width: 78, height: 68),
        const Radius.circular(4),
      ),
      wallPaint..style = PaintingStyle.stroke..strokeWidth = 3,
    );

    // 2. 室內實體物件：木質收銀台、收銀機與瓦楞紙箱
    final counterWood = Paint()..color = const Color(0xFF854D0E);
    canvas.drawRect(Rect.fromLTWH(base.dx - 26, base.dy - 32, 24, 14), counterWood);

    // 收銀機 (亮藍螢幕)
    final posPaint = Paint()..color = const Color(0xFF38BDF8);
    canvas.drawRect(Rect.fromLTWH(base.dx - 22, base.dy - 40, 10, 8), posPaint);

    // 地上堆疊的瓦楞紙箱 (Cardboard Boxes)
    final boxPaint = Paint()..color = const Color(0xFFB45309);
    final boxShadow = Paint()..color = const Color(0xFF78350F);
    canvas.drawRect(Rect.fromLTWH(base.dx + 4, base.dy - 24, 12, 10), boxPaint);
    canvas.drawRect(Rect.fromLTWH(base.dx + 16, base.dy - 22, 10, 8), boxPaint);
    canvas.drawRect(Rect.fromLTWH(base.dx + 8, base.dy - 32, 10, 8), boxShadow); // 疊在上方

    // 3. 屋頂發光霓虹招牌 (CITY MART · OPEN 24HR)
    final signBg = Paint()..color = const Color(0xFF0F172A);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(base.dx - 36, base.dy - 78, 72, 16), const Radius.circular(3)),
      signBg,
    );

    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'CITY MART',
        style: TextStyle(
          color: Color(0xFFF97316),
          fontSize: 8.5,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, Offset(base.dx - textPainter.width / 2, base.dy - 75));
  }

  void _drawApartmentBuilding(Canvas canvas, double cx, double cy) {
    final base = _iso(1.0, 1.5, cx, cy);

    // 紅磚色低多邊形老公寓
    final brickPaint = Paint()..color = const Color(0xFF7F1D1D);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(base.dx - 28, base.dy - 80, 56, 75), const Radius.circular(4)),
      brickPaint,
    );

    // 發光窗戶
    final windowPaint = Paint()..color = const Color(0xFFFDE047).withValues(alpha: 0.8);
    for (int y = 0; y < 3; y++) {
      for (int x = 0; x < 2; x++) {
        canvas.drawRect(
          Rect.fromLTWH(base.dx - 20 + (x * 24), base.dy - 72 + (y * 22), 14, 12),
          windowPaint,
        );
      }
    }

    // 門口門墊 (藏鑰匙處)
    final matPaint = Paint()..color = const Color(0xFF10B981);
    canvas.drawRect(Rect.fromLTWH(base.dx - 8, base.dy - 6, 16, 6), matPaint);
  }

  void _drawLowPolyTaxi(Canvas canvas, double cx, double cy) {
    final pos = _iso(4.5, 2.0, cx, cy);

    // 黃色計程車身
    final taxiPaint = Paint()..color = const Color(0xFFEAB308);
    final taxiRoof = Paint()..color = const Color(0xFFCA8A04);
    final wheelPaint = Paint()..color = const Color(0xFF0F172A);

    // 車體
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(pos.dx, pos.dy - 10), width: 34, height: 14), const Radius.circular(3)),
      taxiPaint,
    );
    // 車頂車窗
    canvas.drawRect(Rect.fromLTWH(pos.dx - 10, pos.dy - 19, 20, 9), taxiRoof);
    // 輪子
    canvas.drawCircle(Offset(pos.dx - 11, pos.dy - 3), 3.5, wheelPaint);
    canvas.drawCircle(Offset(pos.dx + 11, pos.dy - 3), 3.5, wheelPaint);
    // 車頂燈
    canvas.drawRect(Rect.fromLTWH(pos.dx - 4, pos.dy - 23, 8, 4), Paint()..color = Colors.white);
  }

  void _drawStreetLamp(Canvas canvas, double cx, double cy) {
    final pos = _iso(3.0, 3.0, cx, cy);

    // 燈桿
    final polePaint = Paint()
      ..color = const Color(0xFF334155)
      ..strokeWidth = 2.5;
    canvas.drawLine(pos, Offset(pos.dx, pos.dy - 44), polePaint);

    // 燈罩
    canvas.drawCircle(Offset(pos.dx + 3, pos.dy - 44), 4, Paint()..color = const Color(0xFFFDE047));

    // 地面暖黃光錐暈染 (Warm Light Cone)
    final glowPaint = Paint()
      ..color = const Color(0xFFFDE047).withValues(alpha: 0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawOval(Rect.fromCenter(center: Offset(pos.dx + 10, pos.dy + 4), width: 50, height: 24), glowPaint);
  }

  void _drawProtagonist(Canvas canvas, double cx, double cy) {
    final pos = _iso(playerGx, playerGy, cx, cy);

    // 主角腳下陰影
    final shadowPaint = Paint()..color = Colors.black.withValues(alpha: 0.45);
    canvas.drawOval(Rect.fromCenter(center: Offset(pos.dx, pos.dy + 2), width: 14, height: 6), shadowPaint);

    // 主角風衣 (深棕駝色)
    final coatPaint = Paint()..color = const Color(0xFF78350F);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(pos.dx - 5, pos.dy - 20, 10, 14), const Radius.circular(2)),
      coatPaint,
    );

    // 頭部
    canvas.drawCircle(Offset(pos.dx, pos.dy - 24), 4.5, Paint()..color = const Color(0xFFFBBF24));

    // 手提旅行皮箱 (Suitcase)
    if (isCarryingSuitcase) {
      final suitcasePaint = Paint()..color = const Color(0xFF92400E);
      final brassLatch = Paint()..color = const Color(0xFFFDE047);

      // 皮箱體
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(pos.dx + 5, pos.dy - 15, 8, 10), const Radius.circular(1.5)),
        suitcasePaint,
      );
      // 銅鎖扣
      canvas.drawRect(Rect.fromLTWH(pos.dx + 7.5, pos.dy - 12, 3, 2), brassLatch);
    }
  }

  @override
  bool shouldRepaint(covariant _LowPolyDioramaPainter oldDelegate) => true;
}

class _DioramaEntity {
  final double sortDepth;
  final void Function(Canvas) render;

  _DioramaEntity({required this.sortDepth, required this.render});
}

class _RainDrop {
  double x;
  double y;
  final double length;
  final double speed;

  _RainDrop({
    required this.x,
    required this.y,
    required this.length,
    required this.speed,
  });
}
