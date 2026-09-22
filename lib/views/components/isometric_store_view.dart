import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/store_fixture.dart';
import '../../providers/game_state.dart';
import '../../services/audio_service.dart';
import 'fixture_detail_sheet.dart';

/// 2.5D Isometric 超商門市實體模擬畫面 (精緻復古像素風 + 實體貨架點擊微操作)
class IsometricStoreView extends StatefulWidget {
  final VoidCallback? onOpenBuildMode;

  const IsometricStoreView({super.key, this.onOpenBuildMode});

  @override
  State<IsometricStoreView> createState() => _IsometricStoreViewState();
}

class _IsometricStoreViewState extends State<IsometricStoreView> with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  bool isBuildMode = false;

  // 動態顧客與視覺微粒
  final List<_SimCustomer> _activeCustomers = [];
  final List<_FloatingToast> _floatingTexts = [];
  final List<_SteamParticle> _steamParticles = [];
  final math.Random _rng = math.Random();

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    _animCtrl.addListener(_onTick);
  }

  void _onTick() {
    if (!mounted) return;

    // 1. 定期生成顧客走進超商
    if (_activeCustomers.length < 4 && _rng.nextDouble() < 0.025) {
      _spawnCustomer();
    }

    // 2. 熟食與咖啡的熱氣蒸氣粒子
    if (_rng.nextDouble() < 0.15) {
      _steamParticles.add(
        _SteamParticle(
          gridX: 4.8 + _rng.nextDouble() * 0.4,
          gridY: 2.8 + _rng.nextDouble() * 0.4,
          speed: 0.008 + _rng.nextDouble() * 0.006,
        ),
      );
    }
    // 咖啡吧台蒸氣
    if (_rng.nextDouble() < 0.1) {
      _steamParticles.add(
        _SteamParticle(
          gridX: 1.0 + _rng.nextDouble() * 0.3,
          gridY: 3.0 + _rng.nextDouble() * 0.3,
          speed: 0.007 + _rng.nextDouble() * 0.005,
        ),
      );
    }

    // 更新蒸氣微粒
    for (int i = _steamParticles.length - 1; i >= 0; i--) {
      final p = _steamParticles[i];
      p.age += 0.02;
      p.offsetZ += p.speed;
      if (p.age >= 1.0) {
        _steamParticles.removeAt(i);
      }
    }

    // 3. 更新顧客動作與狀態流轉
    for (int i = _activeCustomers.length - 1; i >= 0; i--) {
      final c = _activeCustomers[i];
      c.progress += 0.007 * c.speed;

      if (c.progress >= 1.0) {
        if (c.state == _CustomerState.entering) {
          // 到達貨架挑選商品
          c.state = _CustomerState.shopping;
          c.progress = 0.0;
        } else if (c.state == _CustomerState.shopping) {
          // 前往收銀台排隊
          c.state = _CustomerState.queuing;
          c.progress = 0.0;
        } else if (c.state == _CustomerState.queuing) {
          // 結帳完成，冒出金幣與音效
          c.state = _CustomerState.leaving;
          c.progress = 0.0;
          _triggerCheckoutFx(c);
        } else if (c.state == _CustomerState.leaving) {
          _activeCustomers.removeAt(i);
        }
      }
    }

    // 4. 更新浮動文字
    for (int i = _floatingTexts.length - 1; i >= 0; i--) {
      final f = _floatingTexts[i];
      f.age += 0.025;
      f.offsetY -= 0.8;
      if (f.age >= 1.0) {
        _floatingTexts.removeAt(i);
      }
    }

    setState(() {});
  }

  void _spawnCustomer() {
    final types = [
      _CustomerType.student,
      _CustomerType.salaryman,
      _CustomerType.auntie,
      _CustomerType.casual,
    ];

    final shoppingTargets = [
      {'name': '義美小泡芙', 'icon': '🥐', 'x': 3.8, 'y': 2.0, 'price': 35},
      {'name': '麥香奶茶', 'icon': '🧋', 'x': 4.0, 'y': 2.5, 'price': 15},
      {'name': '茶裏王綠茶', 'icon': '🍵', 'x': 1.0, 'y': 1.0, 'price': 25},
      {'name': '奮起湖便當', 'icon': '🍱', 'x': 4.8, 'y': 3.0, 'price': 95},
      {'name': '茶葉蛋', 'icon': '🥚', 'x': 5.0, 'y': 3.4, 'price': 14},
      {'name': 'UCC熱拿鐵', 'icon': '☕', 'x': 1.0, 'y': 3.0, 'price': 65},
    ];

    final target = shoppingTargets[_rng.nextInt(shoppingTargets.length)];

    final newCustomer = _SimCustomer(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      type: types[_rng.nextInt(types.length)],
      targetItemIcon: target['icon'] as String,
      targetItemName: target['name'] as String,
      price: target['price'] as int,
      shelfX: target['x'] as double,
      shelfY: target['y'] as double,
      speed: 0.85 + _rng.nextDouble() * 0.4,
    );

    _activeCustomers.add(newCustomer);

    // 顧客推門進入觸發進門叮咚鈴聲
    AudioService().playDoorChime();
  }

  void _triggerCheckoutFx(_SimCustomer c) {
    // 結帳音效
    AudioService().playScanBeep();
    AudioService().playCashRegister();

    _floatingTexts.add(
      _FloatingToast(
        text: '🪙 +NT\$ ${c.price}',
        color: const Color(0xFFFFB800),
        gridX: 2.0,
        gridY: 4.0,
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
    final state = context.watch<GameState>();
    final onDutyStaff = state.hiredStaff.where((e) => e.isOnDuty(state.company.hour)).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final cx = constraints.maxWidth / 2;
        const cy = 60.0;

        return Container(
          height: 310,
          decoration: BoxDecoration(
            color: const Color(0xFF1B1924),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFFFB800).withValues(alpha: 0.35), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                // 1. 等角透視 2.5D 店景 Canvas + 點擊互動偵測
                GestureDetector(
                  onTapUp: (details) => _handleCanvasTap(details.localPosition, cx, cy, state),
                  child: CustomPaint(
                    size: Size(constraints.maxWidth, 310),
                    painter: _PixelStorePainter(
                      fixtures: state.fixtures,
                      customers: _activeCustomers,
                      floatingTexts: _floatingTexts,
                      steamParticles: _steamParticles,
                      onDutyStaff: onDutyStaff,
                      isBuildMode: isBuildMode,
                      gameHour: state.company.hour,
                    ),
                  ),
                ),

                // 2. 頂部狀態與操作 Bar
                Positioned(
                  top: 10,
                  left: 12,
                  right: 12,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // 門市狀態膠囊
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF14131A).withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: onDutyStaff.isNotEmpty ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              onDutyStaff.isNotEmpty
                                  ? '🟢 執勤: ${onDutyStaff.first.name}'
                                  : '🔴 櫃台空缺',
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '👥 店內 ${_activeCustomers.length} 人',
                              style: const TextStyle(color: Colors.white70, fontSize: 11),
                            ),
                          ],
                        ),
                      ),

                      // 右側操作工具 (手動快速服務 + 裝潢佈局)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 店長親收按鈕
                          InkWell(
                            onTap: () {
                              state.serveManualCustomer();
                              AudioService().playScanBeep();
                              AudioService().playCashRegister();
                              _floatingTexts.add(
                                _FloatingToast(
                                  text: '⚡ 店長親結 +1',
                                  color: const Color(0xFF38BDF8),
                                  gridX: 2.0,
                                  gridY: 4.0,
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFD97706), Color(0xFFF59E0B)],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.amber.shade200, width: 1.2),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.amber.withValues(alpha: 0.3),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.flash_on_rounded, color: Colors.white, size: 14),
                                  SizedBox(width: 3),
                                  Text('店長親收', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // 裝潢設備模式按鈕
                          InkWell(
                            onTap: () => setState(() => isBuildMode = !isBuildMode),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: isBuildMode ? const Color(0xFFFFB800) : const Color(0xFF14131A).withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isBuildMode ? const Color(0xFFFFB800) : Colors.white24,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.storefront_rounded,
                                    color: isBuildMode ? Colors.black : Colors.white70,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isBuildMode ? '完成裝潢' : '佈置設備',
                                    style: TextStyle(
                                      color: isBuildMode ? Colors.black : Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // 3. 裝潢佈局模式下的浮動設備操作面板
                if (isBuildMode)
                  Positioned(
                    bottom: 8,
                    left: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1D24).withValues(alpha: 0.96),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFFFB800).withValues(alpha: 0.6)),
                      ),
                      child: Row(
                        children: [
                          const Text(
                            '設備工坊：',
                            style: TextStyle(color: Color(0xFFFFB800), fontSize: 11.5, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: state.fixtures.map((f) {
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: ActionChip(
                                      avatar: Text(f.icon, style: const TextStyle(fontSize: 13)),
                                      label: Text(
                                        f.isPurchased ? '${f.name} Lv.${f.level}' : '${f.name} \$${f.cost.toInt()}',
                                        style: TextStyle(
                                          color: f.isPurchased ? Colors.white : Colors.amberAccent,
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      backgroundColor: f.isPurchased ? const Color(0xFF334155) : const Color(0xFF1E293B),
                                      side: BorderSide(
                                        color: f.isPurchased ? Colors.cyanAccent.withValues(alpha: 0.5) : Colors.amber.withValues(alpha: 0.4),
                                      ),
                                      onPressed: () => _handleFixtureTap(state, f),
                                    ),
                                  );
                                }).toList(),
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
        );
      },
    );
  }

  /// 處理點擊畫布上的實體物件 (貨架、冷藏櫃、收銀台、顧客)
  void _handleCanvasTap(Offset localPos, double cx, double cy, GameState state) {
    const double tileW = 46.0;
    const double tileH = 23.0;

    final dx = localPos.dx - cx;
    final dy = localPos.dy - cy;

    final gx = (dx / (tileW / 2) + dy / (tileH / 2)) / 2;
    final gy = (dy / (tileH / 2) - dx / (tileW / 2)) / 2;

    // 1. 檢查是否點擊到任一設備
    StoreFixture? clickedFixture;
    double minDistance = 1.1;

    for (final f in state.fixtures) {
      final dist = math.sqrt(math.pow(gx - f.gridX, 2) + math.pow(gy - f.gridY, 2));
      if (dist < minDistance) {
        minDistance = dist;
        clickedFixture = f;
      }
    }

    if (clickedFixture != null) {
      if (!clickedFixture.isPurchased) {
        _handleFixtureTap(state, clickedFixture);
      } else {
        // 已購置設備：彈出實體微觀抽屜
        AudioService().playDoorChime();
        FixtureDetailSheet.show(context, clickedFixture);
      }
      return;
    }

    // 2. 檢查是否點擊到收銀櫃台區域 (gx: 1.5~2.5, gy: 3.5~4.5)
    if (gx >= 1.2 && gx <= 2.8 && gy >= 3.2 && gy <= 4.8) {
      final onDutyStaff = state.hiredStaff.where((e) => e.isOnDuty(state.company.hour)).toList();
      final staffName = onDutyStaff.isNotEmpty ? onDutyStaff.first.name : '暫無值班人員';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF1E293B),
          content: Text('🏪 收銀台狀態：值班【$staffName】· 結帳順暢度: ${onDutyStaff.isNotEmpty ? "良好 ⚡" : "缺員緩慢 ⏳"}'),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    // 3. 檢查是否點擊到顧客
    for (final c in _activeCustomers) {
      final dist = math.sqrt(math.pow(gx - c.shelfX, 2) + math.pow(gy - c.shelfY, 2));
      if (dist < 1.0) {
        _floatingTexts.add(
          _FloatingToast(
            text: '💬 買【${c.targetItemName}】',
            color: const Color(0xFF38BDF8),
            gridX: c.shelfX,
            gridY: c.shelfY,
          ),
        );
        return;
      }
    }
  }

  void _handleFixtureTap(GameState state, StoreFixture fixture) {
    if (!fixture.isPurchased) {
      final success = state.purchaseFixture(fixture.id);
      if (success) {
        AudioService().playFanfare();
        _floatingTexts.add(
          _FloatingToast(
            text: '✨ 添購成功！${fixture.name}',
            color: const Color(0xFFFFB800),
            gridX: fixture.gridX.toDouble(),
            gridY: fixture.gridY.toDouble(),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('現金不足以支付 \$${fixture.cost.toInt()}！')),
        );
      }
    } else {
      // 升級
      final success = state.upgradeFixture(fixture.id);
      if (success) {
        AudioService().playFanfare();
        _floatingTexts.add(
          _FloatingToast(
            text: '⬆️ 升級成功 Lv.${fixture.level}！',
            color: const Color(0xFF06B6D4),
            gridX: fixture.gridX.toDouble(),
            gridY: fixture.gridY.toDouble(),
          ),
        );
      }
    }
  }
}

// -----------------------------------------------------------------------------
// 2.5D 精緻像素風 CustomPainter (Warm Isometric Store Renderer)
// -----------------------------------------------------------------------------
class _PixelStorePainter extends CustomPainter {
  final List<StoreFixture> fixtures;
  final List<_SimCustomer> customers;
  final List<_FloatingToast> floatingTexts;
  final List<_SteamParticle> steamParticles;
  final List<dynamic> onDutyStaff;
  final bool isBuildMode;
  final int gameHour;

  _PixelStorePainter({
    required this.fixtures,
    required this.customers,
    required this.floatingTexts,
    required this.steamParticles,
    required this.onDutyStaff,
    required this.isBuildMode,
    required this.gameHour,
  });

  static const double tileW = 46.0;
  static const double tileH = 23.0;
  static const int gridSize = 6;

  Offset _isoToScreen(double gx, double gy, double cx, double cy) {
    final x = cx + (gx - gy) * (tileW / 2);
    final y = cy + (gx + gy) * (tileH / 2);
    return Offset(x, y);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    const cy = 60.0;

    // 1. 繪製店面拋光磁磚地板 (暖象牙白與柔米黃交錯)
    final floorTile1 = Paint()..color = const Color(0xFFEBE6D3);
    final floorTile2 = Paint()..color = const Color(0xFFDED8C0);
    final groutLine = Paint()
      ..color = const Color(0xFFCAC3A5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (int gx = 0; gx < gridSize; gx++) {
      for (int gy = 0; gy < gridSize; gy++) {
        final p0 = _isoToScreen(gx.toDouble(), gy.toDouble(), cx, cy);
        final p1 = _isoToScreen(gx + 1.0, gy.toDouble(), cx, cy);
        final p2 = _isoToScreen(gx + 1.0, gy + 1.0, cx, cy);
        final p3 = _isoToScreen(gx.toDouble(), gy + 1.0, cx, cy);

        final path = Path()
          ..moveTo(p0.dx, p0.dy)
          ..lineTo(p1.dx, p1.dy)
          ..lineTo(p2.dx, p2.dy)
          ..lineTo(p3.dx, p3.dy)
          ..close();

        canvas.drawPath(path, (gx + gy) % 2 == 0 ? floorTile1 : floorTile2);
        canvas.drawPath(path, groutLine);
      }
    }

    // 繪製後牆踢腳線 (Store Baseboard)
    _drawWallBaseboard(canvas, cx, cy);

    // 2. 門口迎賓地墊與三色超商遮陽棚
    _drawEntranceAndAwning(canvas, cx, cy);

    // 3. 收集所有實體對象進行深度排序 (Y-Sorting)
    final List<_RenderableEntity> entities = [];

    // 加入家具設備
    for (final f in fixtures) {
      if (f.isPurchased || isBuildMode) {
        entities.add(
          _RenderableEntity(
            sortDepth: f.gridX + f.gridY + 0.1,
            render: (c) => _drawIsometricFixture(c, f, cx, cy),
          ),
        );
      }
    }

    // 加入執勤收銀員 (位於收銀台後方 (2.0, 3.6))
    if (onDutyStaff.isNotEmpty) {
      entities.add(
        _RenderableEntity(
          sortDepth: 2.0 + 3.6,
          render: (c) {
            final pos = _isoToScreen(2.0, 3.6, cx, cy);
            _drawCashierStaff(c, pos);
          },
        ),
      );
    }

    // 加入活生生顧客小人
    for (final cust in customers) {
      double curGx = 0.0;
      double curGy = 4.5;

      if (cust.state == _CustomerState.entering) {
        curGx = 0.0 + (cust.shelfX - 0.0) * cust.progress;
        curGy = 4.5 + (cust.shelfY - 4.5) * cust.progress;
      } else if (cust.state == _CustomerState.shopping) {
        curGx = cust.shelfX;
        curGy = cust.shelfY;
      } else if (cust.state == _CustomerState.queuing) {
        curGx = cust.shelfX + (2.0 - cust.shelfX) * cust.progress;
        curGy = cust.shelfY + (4.5 - cust.shelfY) * cust.progress;
      } else if (cust.state == _CustomerState.leaving) {
        curGx = 2.0 + (0.0 - 2.0) * cust.progress;
        curGy = 4.5 + (5.5 - 4.5) * cust.progress;
      }

      entities.add(
        _RenderableEntity(
          sortDepth: curGx + curGy + 0.2,
          render: (c) => _drawCustomerSprite(c, cust, curGx, curGy, cx, cy),
        ),
      );
    }

    // 依深度排序並繪製
    entities.sort((a, b) => a.sortDepth.compareTo(b.sortDepth));
    for (final entity in entities) {
      entity.render(canvas);
    }

    // 4. 繪製蒸氣微粒效果 (熟食、咖啡熱氣)
    _drawSteam(canvas, cx, cy);

    // 5. 繪製浮動金幣文字特效 (Top Overlay)
    for (final ft in floatingTexts) {
      final pos = _isoToScreen(ft.gridX, ft.gridY, cx, cy);
      final alpha = (1.0 - ft.age).clamp(0.0, 1.0);
      final toastPainter = TextPainter(
        text: TextSpan(
          text: ft.text,
          style: TextStyle(
            color: ft.color.withValues(alpha: alpha),
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
            shadows: const [
              Shadow(color: Colors.black, blurRadius: 4, offset: Offset(0, 1)),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      toastPainter.paint(canvas, Offset(pos.dx - toastPainter.width / 2, pos.dy + ft.offsetY - 32));
    }

    // 6. 日夜時間光影濾鏡 (Morning, Afternoon, Night)
    _drawTimeAtmosphere(canvas, size);
  }

  void _drawWallBaseboard(Canvas canvas, double cx, double cy) {
    final woodBasePaint = Paint()..color = const Color(0xFF6B4226);
    final woodTopPaint = Paint()
      ..color = const Color(0xFF8B5A2B)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    // 左後牆
    final pLeft0 = _isoToScreen(0, 0, cx, cy);
    final pLeftEnd = _isoToScreen(0, gridSize.toDouble(), cx, cy);
    canvas.drawLine(pLeft0, pLeftEnd, woodBasePaint..strokeWidth = 4.0);
    canvas.drawLine(pLeft0, pLeftEnd, woodTopPaint);

    // 右後牆
    final pRightEnd = _isoToScreen(gridSize.toDouble(), 0, cx, cy);
    canvas.drawLine(pLeft0, pRightEnd, woodBasePaint..strokeWidth = 4.0);
    canvas.drawLine(pLeft0, pRightEnd, woodTopPaint);
  }

  void _drawEntranceAndAwning(Canvas canvas, double cx, double cy) {
    final doorPos = _isoToScreen(0.0, 4.5, cx, cy);

    // 綠色迎賓踏墊
    final matPaint = Paint()..color = const Color(0xFF10B981);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(doorPos.dx - 10, doorPos.dy + 8), width: 34, height: 16),
        const Radius.circular(3),
      ),
      matPaint,
    );

    // 踏墊文字
    final matText = TextPainter(
      text: const TextSpan(
        text: 'WELCOME',
        style: TextStyle(color: Colors.white, fontSize: 6.5, fontWeight: FontWeight.bold, letterSpacing: 0.5),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    matText.paint(canvas, Offset(doorPos.dx - 10 - matText.width / 2, doorPos.dy + 4));

    // 門口三色招牌遮陽棚 (橘、綠、紅)
    final barW = 12.0;
    final topY = doorPos.dy - 32;
    final colors = [const Color(0xFFFF7A00), const Color(0xFF00805A), const Color(0xFFE53935)];

    for (int i = 0; i < 3; i++) {
      final awningPaint = Paint()..color = colors[i];
      canvas.drawRect(Rect.fromLTWH(doorPos.dx - 28 + (i * barW), topY, barW, 9), awningPaint);
    }
  }

  void _drawIsometricFixture(Canvas canvas, StoreFixture f, double cx, double cy) {
    final pos = _isoToScreen(f.gridX.toDouble(), f.gridY.toDouble(), cx, cy);

    if (!f.isPurchased) {
      // 裝潢模式下的虛擬藍圖預覽框
      final blueprintPaint = Paint()
        ..color = const Color(0xFFFFB800).withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawCircle(Offset(pos.dx, pos.dy), 16, blueprintPaint);
      _drawEmoji(canvas, '➕', pos.dx - 8, pos.dy - 12, 14);
      return;
    }

    // 設備實體立體陰影
    final shadowPaint = Paint()..color = Colors.black.withValues(alpha: 0.32);
    canvas.drawOval(Rect.fromCenter(center: Offset(pos.dx, pos.dy + 6), width: 34, height: 16), shadowPaint);

    // 依據不同設備繪製專屬 2.5D 精緻立體外觀
    switch (f.id) {
      case 'snack_shelf':
        _drawSnackShelf(canvas, pos);
        break;
      case 'drink_cooler':
        _drawDrinkCooler(canvas, pos);
        break;
      case 'hot_food_steamer':
        _drawHotFoodSteamer(canvas, pos);
        break;
      case 'coffee_bar':
        _drawCoffeeBar(canvas, pos);
        break;
      case 'cashier_counter':
      default:
        _drawCashierCounter(canvas, pos);
        break;
    }

    // 頂部等級與名牌標籤
    final labelPainter = TextPainter(
      text: TextSpan(
        text: '${f.name} Lv.${f.level}',
        style: const TextStyle(
          color: Color(0xFF1E293B),
          fontSize: 8.5,
          fontWeight: FontWeight.bold,
          backgroundColor: Color(0xFFFEF08A),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    labelPainter.paint(canvas, Offset(pos.dx - labelPainter.width / 2, pos.dy - 34));
  }

  // --- 各設備專屬 2.5D 立體繪製 ---

  void _drawCashierCounter(Canvas canvas, Offset pos) {
    // 櫃台木質主體
    final counterPaint = Paint()..color = const Color(0xFF78350F);
    final topPaint = Paint()..color = const Color(0xFFD97706);

    // 櫃台立面
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(pos.dx, pos.dy - 4), width: 32, height: 20), const Radius.circular(3)),
      counterPaint,
    );
    // 櫃面檯面
    canvas.drawOval(Rect.fromCenter(center: Offset(pos.dx, pos.dy - 12), width: 32, height: 12), topPaint);

    // POS 機與螢幕 (亮藍色光澤)
    final posMonitor = Paint()..color = const Color(0xFF0F172A);
    final posScreen = Paint()..color = const Color(0xFF38BDF8);
    canvas.drawRect(Rect.fromLTWH(pos.dx - 6, pos.dy - 24, 12, 10), posMonitor);
    canvas.drawRect(Rect.fromLTWH(pos.dx - 5, pos.dy - 23, 10, 8), posScreen);

    // 紅光條碼掃描槍
    final scannerPaint = Paint()..color = const Color(0xFFEF4444);
    canvas.drawLine(Offset(pos.dx + 8, pos.dy - 14), Offset(pos.dx + 12, pos.dy - 10), scannerPaint..strokeWidth = 2);
  }

  void _drawDrinkCooler(Canvas canvas, Offset pos) {
    // 冰櫃外框深藍色
    final framePaint = Paint()..color = const Color(0xFF0F172A);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(pos.dx, pos.dy - 10), width: 28, height: 36), const Radius.circular(4)),
      framePaint,
    );

    // 冰櫃內部冷光透視 (冰藍色漸層)
    final glassInterior = Paint()..color = const Color(0xFF0284C7);
    canvas.drawRect(Rect.fromLTWH(pos.dx - 11, pos.dy - 24, 22, 26), glassInterior);

    // 三層飲料罐色塊 (綠罐茶裏王、棕罐麥香、白瓶鮮乳)
    final canGreen = Paint()..color = const Color(0xFF10B981);
    final canBrown = Paint()..color = const Color(0xFFD97706);
    final canWhite = Paint()..color = Colors.white;

    for (int i = 0; i < 3; i++) {
      canvas.drawRect(Rect.fromLTWH(pos.dx - 9 + (i * 6), pos.dy - 22, 4, 6), canGreen);
      canvas.drawRect(Rect.fromLTWH(pos.dx - 9 + (i * 6), pos.dy - 14, 4, 6), canBrown);
      canvas.drawRect(Rect.fromLTWH(pos.dx - 9 + (i * 6), pos.dy - 6, 4, 6), canWhite);
    }

    // 玻璃雙門反光斜線
    final glarePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(pos.dx - 8, pos.dy - 22), Offset(pos.dx + 4, pos.dy - 6), glarePaint);
  }

  void _drawSnackShelf(Canvas canvas, Offset pos) {
    // 零食層架 (暖木褐色)
    final shelfWood = Paint()..color = const Color(0xFF92400E);
    final shelfLedge = Paint()..color = const Color(0xFFB45309);

    canvas.drawRect(Rect.fromLTWH(pos.dx - 14, pos.dy - 18, 28, 24), shelfWood);

    // 三層展示板與商品盒
    for (int row = 0; row < 3; row++) {
      final y = pos.dy - 16 + (row * 8);
      canvas.drawLine(Offset(pos.dx - 14, y), Offset(pos.dx + 14, y), shelfLedge..strokeWidth = 2);

      // 排滿的商品盒 (黃色洋芋片、紅色小泡芙)
      final boxPaint = Paint()..color = (row % 2 == 0) ? const Color(0xFFEF4444) : const Color(0xFFF59E0B);
      for (int c = 0; c < 3; c++) {
        canvas.drawRect(Rect.fromLTWH(pos.dx - 11 + (c * 8), y - 6, 6, 5), boxPaint);
      }
    }
  }

  void _drawHotFoodSteamer(Canvas canvas, Offset pos) {
    // 熟食保溫台底座
    final basePaint = Paint()..color = const Color(0xFF7C2D12);
    canvas.drawRect(Rect.fromLTWH(pos.dx - 13, pos.dy - 14, 26, 18), basePaint);

    // 保溫透明玻璃盒 (透出暖黃光)
    final warmLight = Paint()..color = const Color(0xFFFDE047).withValues(alpha: 0.7);
    canvas.drawRect(Rect.fromLTWH(pos.dx - 11, pos.dy - 24, 22, 12), warmLight);

    // 茶葉蛋鍋與便當盒
    final eggPot = Paint()..color = const Color(0xFF451A03);
    canvas.drawOval(Rect.fromCenter(center: Offset(pos.dx - 4, pos.dy - 16), width: 10, height: 6), eggPot);
    _drawEmoji(canvas, '🍱', pos.dx + 2, pos.dy - 22, 10);
  }

  void _drawCoffeeBar(Canvas canvas, Offset pos) {
    // 咖啡吧台深木色
    final barPaint = Paint()..color = const Color(0xFF3E2723);
    canvas.drawRect(Rect.fromLTWH(pos.dx - 14, pos.dy - 14, 28, 18), barPaint);

    // 義式商用咖啡機 (銀灰金屬 + 雙出水口)
    final chromePaint = Paint()..color = const Color(0xFFCBD5E1);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(pos.dx - 10, pos.dy - 26, 20, 14), const Radius.circular(2)),
      chromePaint,
    );

    // 紅色壓力表與咖啡豆頂部漏斗
    final redDial = Paint()..color = const Color(0xFFDC2626);
    canvas.drawCircle(Offset(pos.dx, pos.dy - 20), 2.5, redDial);
    _drawEmoji(canvas, '☕', pos.dx - 5, pos.dy - 16, 11);
  }

  // --- 顧客小人生動渲染 ---

  void _drawCustomerSprite(Canvas canvas, _SimCustomer cust, double gx, double gy, double cx, double cy) {
    final pos = _isoToScreen(gx, gy, cx, cy);

    // 走路彈跳動畫 (Bobbing)
    final bob = (cust.state == _CustomerState.entering || cust.state == _CustomerState.queuing || cust.state == _CustomerState.leaving)
        ? math.sin(cust.progress * math.pi * 8).abs() * 2.5
        : 0.0;

    final drawY = pos.dy - bob;

    // 腳下陰影
    final shadowPaint = Paint()..color = Colors.black.withValues(alpha: 0.35);
    canvas.drawOval(Rect.fromCenter(center: Offset(pos.dx, pos.dy + 3), width: 14, height: 6), shadowPaint);

    // 依身份身著不同服裝配色
    Color shirtColor;
    Color pantsColor;
    String hairEmoji;

    switch (cust.type) {
      case _CustomerType.student:
        shirtColor = const Color(0xFF1E3A8A); // 深藍學生制服
        pantsColor = const Color(0xFF0F172A);
        hairEmoji = '🧑‍🎓';
        break;
      case _CustomerType.salaryman:
        shirtColor = Colors.white; // 上班族襯衫 + 領帶
        pantsColor = const Color(0xFF1E293B);
        hairEmoji = '👨‍💼';
        break;
      case _CustomerType.auntie:
        shirtColor = const Color(0xFFF43F5E); // 鄰居阿姨粉紅上衣
        pantsColor = const Color(0xFF475569);
        hairEmoji = '👩';
        break;
      case _CustomerType.casual:
        shirtColor = const Color(0xFFF59E0B); // 休閒青年亮黃帽 T
        pantsColor = const Color(0xFF2563EB);
        hairEmoji = '🧑';
        break;
    }

    // 繪製身體與衣褲
    final bodyPaint = Paint()..color = shirtColor;
    final pantsPaint = Paint()..color = pantsColor;

    // 軀幹
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(pos.dx - 4, drawY - 14, 8, 8), const Radius.circular(2)),
      bodyPaint,
    );
    // 雙腳
    canvas.drawRect(Rect.fromLTWH(pos.dx - 3, drawY - 6, 2.5, 6), pantsPaint);
    canvas.drawRect(Rect.fromLTWH(pos.dx + 0.5, drawY - 6, 2.5, 6), pantsPaint);

    // 頭部表情 Emoji
    _drawEmoji(canvas, hairEmoji, pos.dx - 7, drawY - 26, 14);

    // 購物提籃 (紅色超商提籃)
    final basketPaint = Paint()..color = const Color(0xFFDC2626);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(pos.dx + 4, drawY - 11, 6, 5), const Radius.circular(1)),
      basketPaint,
    );

    // 頭頂動態心情對話氣泡 (Thought Bubble)
    _drawCustomerBubble(canvas, cust, pos.dx, drawY);
  }

  void _drawCustomerBubble(Canvas canvas, _SimCustomer cust, double x, double y) {
    if (cust.state == _CustomerState.entering) {
      // 剛進店：尋找心儀商品
      _paintBubble(canvas, x, y - 32, cust.targetItemIcon);
    } else if (cust.state == _CustomerState.shopping) {
      // 正在拿商品：開心的愛心/笑臉
      _paintBubble(canvas, x, y - 32, '😋');
    } else if (cust.state == _CustomerState.queuing) {
      // 排隊中：沙漏等待
      _paintBubble(canvas, x, y - 32, '⏳');
    } else if (cust.state == _CustomerState.leaving) {
      // 滿載而歸：滿滿購物袋
      _paintBubble(canvas, x, y - 32, '🛍️');
    }
  }

  void _paintBubble(Canvas canvas, double x, double y, String emoji) {
    final bubblePaint = Paint()..color = Colors.white;
    final strokePaint = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(x, y), width: 20, height: 16),
      const Radius.circular(5),
    );
    canvas.drawRRect(rect, bubblePaint);
    canvas.drawRRect(rect, strokePaint);

    // 小氣泡尾巴
    final tail = Path()
      ..moveTo(x - 2, y + 8)
      ..lineTo(x, y + 11)
      ..lineTo(x + 2, y + 8)
      ..close();
    canvas.drawPath(tail, bubblePaint);

    _drawEmoji(canvas, emoji, x - 5.5, y - 6, 11);
  }

  void _drawCashierStaff(Canvas canvas, Offset pos) {
    // 執勤員工穿超商制服綠色背心
    final uniformPaint = Paint()..color = const Color(0xFF047857);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(pos.dx - 5, pos.dy - 14, 10, 10), const Radius.circular(2)),
      uniformPaint,
    );
    _drawEmoji(canvas, '🧑‍💼', pos.dx - 8, pos.dy - 26, 16);
  }

  void _drawSteam(Canvas canvas, double cx, double cy) {
    final steamPaint = Paint()
      ..style = PaintingStyle.fill;

    for (final s in steamParticles) {
      final basePos = _isoToScreen(s.gridX, s.gridY, cx, cy);
      final alpha = (1.0 - s.age).clamp(0.0, 0.7);
      steamPaint.color = Colors.white.withValues(alpha: alpha);

      canvas.drawCircle(
        Offset(basePos.dx + math.sin(s.age * 6) * 3, basePos.dy - (s.offsetZ * 60)),
        2.5 + (s.age * 3),
        steamPaint,
      );
    }
  }

  void _drawTimeAtmosphere(Canvas canvas, Size size) {
    // 依小時疊加微妙自然光暈 (6~17 白天明亮，18~20 黃昏暖橙，21~5 大夜深藍微光)
    Color atmosColor;
    if (gameHour >= 6 && gameHour <= 16) {
      atmosColor = Colors.transparent;
    } else if (gameHour >= 17 && gameHour <= 19) {
      atmosColor = const Color(0xFFEA580C).withValues(alpha: 0.08); // 黃昏暖光
    } else {
      atmosColor = const Color(0xFF1E1B4B).withValues(alpha: 0.16); // 夜間冷色光
    }

    if (atmosColor != Colors.transparent) {
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = atmosColor);
    }
  }

  void _drawEmoji(Canvas canvas, String emoji, double x, double y, double size) {
    final tp = TextPainter(
      text: TextSpan(text: emoji, style: TextStyle(fontSize: size)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(x, y));
  }

  @override
  bool shouldRepaint(covariant _PixelStorePainter oldDelegate) => true;
}

class _RenderableEntity {
  final double sortDepth;
  final void Function(Canvas) render;

  _RenderableEntity({
    required this.sortDepth,
    required this.render,
  });
}

enum _CustomerType { student, salaryman, auntie, casual }
enum _CustomerState { entering, shopping, queuing, leaving }

class _SimCustomer {
  final String id;
  final _CustomerType type;
  final String targetItemIcon;
  final String targetItemName;
  final int price;
  final double shelfX;
  final double shelfY;
  final double speed;
  _CustomerState state = _CustomerState.entering;
  double progress = 0.0;

  _SimCustomer({
    required this.id,
    required this.type,
    required this.targetItemIcon,
    required this.targetItemName,
    required this.price,
    required this.shelfX,
    required this.shelfY,
    required this.speed,
  });
}

class _SteamParticle {
  final double gridX;
  final double gridY;
  final double speed;
  double offsetZ = 0.0;
  double age = 0.0;

  _SteamParticle({
    required this.gridX,
    required this.gridY,
    required this.speed,
  });
}

class _FloatingToast {
  final String text;
  final Color color;
  final double gridX;
  final double gridY;
  double age = 0.0;
  double offsetY = 0.0;

  _FloatingToast({
    required this.text,
    required this.color,
    required this.gridX,
    required this.gridY,
  });
}
