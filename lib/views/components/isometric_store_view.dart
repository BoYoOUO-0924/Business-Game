import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/store_fixture.dart';
import '../../providers/game_state.dart';

class IsometricStoreView extends StatefulWidget {
  final VoidCallback? onOpenBuildMode;

  const IsometricStoreView({super.key, this.onOpenBuildMode});

  @override
  State<IsometricStoreView> createState() => _IsometricStoreViewState();
}

class _IsometricStoreViewState extends State<IsometricStoreView> with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  bool isBuildMode = false;

  // 動態小人顧客 (Isometric Customers)
  final List<_SimCustomer> _activeCustomers = [];
  final List<_FloatingToast> _floatingTexts = [];
  final Random _rng = Random();

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

    // 定期生成顧客走進超商
    if (_activeCustomers.length < 4 && _rng.nextDouble() < 0.02) {
      _spawnCustomer();
    }

    // 更新顧客位置與動作
    for (int i = _activeCustomers.length - 1; i >= 0; i--) {
      final c = _activeCustomers[i];
      c.progress += 0.006 * c.speed;

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
          // 結帳完成，冒出金幣與笑臉，走出店門
          c.state = _CustomerState.leaving;
          c.progress = 0.0;
          _triggerCheckoutFx(c);
        } else if (c.state == _CustomerState.leaving) {
          _activeCustomers.removeAt(i);
        }
      }
    }

    // 更新飄字特效
    for (int i = _floatingTexts.length - 1; i >= 0; i--) {
      final f = _floatingTexts[i];
      f.age += 0.02;
      f.offsetY -= 0.6;
      if (f.age >= 1.0) {
        _floatingTexts.removeAt(i);
      }
    }

    setState(() {});
  }

  void _spawnCustomer() {
    final customerAvatars = ['🧑', '👩', '👨‍💼', '👩‍🎓', '🧑‍🦳', '🏃‍♂️', '🚶‍♀️'];
    final shoppingTargets = [
      {'name': '義美小泡芙', 'icon': '🥐', 'x': 4.0, 'y': 2.0},
      {'name': '麥香奶茶', 'icon': '🧋', 'x': 4.0, 'y': 2.5},
      {'name': '茶裏王', 'icon': '🍵', 'x': 1.0, 'y': 1.0},
      {'name': '奮起湖便當', 'icon': '🍱', 'x': 5.0, 'y': 3.0},
      {'name': '茶葉蛋', 'icon': '🥚', 'x': 5.0, 'y': 3.5},
      {'name': '現煮熱拿鐵', 'icon': '☕', 'x': 1.0, 'y': 3.0},
    ];

    final target = shoppingTargets[_rng.nextInt(shoppingTargets.length)];

    _activeCustomers.add(
      _SimCustomer(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        avatar: customerAvatars[_rng.nextInt(customerAvatars.length)],
        targetItemIcon: target['icon'] as String,
        targetItemName: target['name'] as String,
        shelfX: target['x'] as double,
        shelfY: target['y'] as double,
        speed: 0.8 + _rng.nextDouble() * 0.5,
      ),
    );
  }

  void _triggerCheckoutFx(_SimCustomer c) {
    _floatingTexts.add(
      _FloatingToast(
        text: '+ \$${c.targetItemName.contains("便當") ? 95 : (c.targetItemName.contains("拿鐵") ? 55 : 38)}',
        color: const Color(0xFF10B981),
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

    return Container(
      height: 290,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.3), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0284C7).withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            // 1. 等角透視 2.5D 店景 Canvas
            CustomPaint(
              size: const Size(double.infinity, 290),
              painter: _IsometricStorePainter(
                fixtures: state.fixtures,
                customers: _activeCustomers,
                floatingTexts: _floatingTexts,
                onDutyStaff: onDutyStaff,
                isBuildMode: isBuildMode,
              ),
            ),

            // 2. 頂部狀態與模式切換 Bar
            Positioned(
              top: 10,
              left: 12,
              right: 12,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 門市即時狀態燈
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: onDutyStaff.isNotEmpty ? const Color(0xFF10B981) : Colors.redAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          onDutyStaff.isNotEmpty
                              ? '🟢 營運中 · 店員 ${onDutyStaff.first.name}'
                              : '🔴 櫃台空缺 · 結帳緩慢',
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

                  // 裝潢模式切換按鈕
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 手動快速服務按鈕
                      InkWell(
                        onTap: () {
                          state.serveManualCustomer();
                          _floatingTexts.add(
                            _FloatingToast(
                              text: '⚡ 手動快速結帳 +1',
                              color: const Color(0xFF06B6D4),
                              gridX: 2.0,
                              gridY: 4.0,
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF0284C7), Color(0xFF0EA5E9)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white30),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.flash_on_rounded, color: Colors.yellowAccent, size: 14),
                              SizedBox(width: 2),
                              Text('店長親收', style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // 裝潢模式開關
                      InkWell(
                        onTap: () => setState(() => isBuildMode = !isBuildMode),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: isBuildMode ? Colors.amberAccent : Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isBuildMode ? Colors.amber : Colors.white24,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.architecture_rounded,
                                color: isBuildMode ? Colors.black : Colors.white70,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isBuildMode ? '完成佈局' : '裝潢設備',
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
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B).withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    children: [
                      const Text(
                        '設備工坊：',
                        style: TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: state.fixtures.map((f) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 6.0),
                                child: InkWell(
                                  onTap: () => _handleFixtureTap(state, f),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: f.isPurchased
                                          ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                          : Colors.white.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: f.isPurchased
                                            ? const Color(0xFF10B981).withValues(alpha: 0.6)
                                            : Colors.white24,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Text(f.icon, style: const TextStyle(fontSize: 14)),
                                        const SizedBox(width: 4),
                                        Text(
                                          f.isPurchased ? '${f.name} (Lv.${f.level})' : '${f.name} \$${f.cost.toInt()}',
                                          style: TextStyle(
                                            color: f.isPurchased ? const Color(0xFF10B981) : Colors.white,
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
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
  }

  void _handleFixtureTap(GameState state, StoreFixture fixture) {
    if (!fixture.isPurchased) {
      final success = state.purchaseFixture(fixture.id);
      if (success) {
        _floatingTexts.add(
          _FloatingToast(
            text: '✨ 添購成功！${fixture.name}',
            color: Colors.amberAccent,
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
// 等角投影 CustomPainter (2.5D Isometric Rendering)
// -----------------------------------------------------------------------------
class _IsometricStorePainter extends CustomPainter {
  final List<StoreFixture> fixtures;
  final List<_SimCustomer> customers;
  final List<_FloatingToast> floatingTexts;
  final List<dynamic> onDutyStaff;
  final bool isBuildMode;

  _IsometricStorePainter({
    required this.fixtures,
    required this.customers,
    required this.floatingTexts,
    required this.onDutyStaff,
    required this.isBuildMode,
  });

  // 等角轉換公式
  static const double tileW = 44.0;
  static const double tileH = 22.0;
  static const int gridSize = 6; // 6x6 實體超商網格

  Offset _isoToScreen(double gx, double gy, double cx, double cy) {
    final x = cx + (gx - gy) * (tileW / 2);
    final y = cy + (gx + gy) * (tileH / 2);
    return Offset(x, y);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = 60.0;

    // 1. 繪製店面磁磚地板 (Checkerboard Floor)
    final floorPaint1 = Paint()..color = const Color(0xFF1E293B);
    final floorPaint2 = Paint()..color = const Color(0xFF334155);
    final gridLinePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
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

        canvas.drawPath(path, (gx + gy) % 2 == 0 ? floorPaint1 : floorPaint2);
        canvas.drawPath(path, gridLinePaint);
      }
    }

    // 2. 玻璃自動推門 (大門入口於 (0, 4) ~ (0, 5))
    final doorPos = _isoToScreen(0.0, 4.5, cx, cy);
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    textPainter.text = const TextSpan(
      text: '🚪 自動推門',
      style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10, fontWeight: FontWeight.bold),
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(doorPos.dx - 22, doorPos.dy - 12));

    // 3. 收集所有實體對象進行深度排序 (Y-Sorting: 保證遮擋自然)
    final List<_RenderableEntity> entities = [];

    // 加入家具設備
    for (final f in fixtures) {
      if (f.isPurchased || isBuildMode) {
        entities.add(
          _RenderableEntity(
            gx: f.gridX.toDouble(),
            gy: f.gridY.toDouble(),
            sortDepth: f.gridX + f.gridY + 0.1,
            render: (c) => _drawFixture(c, f, cx, cy),
          ),
        );
      }
    }

    // 加入值班收銀員 (站在收銀櫃台後方 (2, 3.5))
    if (onDutyStaff.isNotEmpty) {
      final staffAvatar = onDutyStaff.first.avatar as String? ?? '👩‍💼';
      entities.add(
        _RenderableEntity(
          gx: 2.0,
          gy: 3.5,
          sortDepth: 2.0 + 3.5,
          render: (c) {
            final pos = _isoToScreen(2.0, 3.5, cx, cy);
            _drawSprite(c, staffAvatar, pos.dx - 12, pos.dy - 24, fontSize: 18);
          },
        ),
      );
    }

    // 加入活生生走動的顧客
    for (final cust in customers) {
      double curGx = 0.0;
      double curGy = 4.5; // 從門口出發

      if (cust.state == _CustomerState.entering) {
        // 從門口走到目標貨架
        curGx = 0.0 + (cust.shelfX - 0.0) * cust.progress;
        curGy = 4.5 + (cust.shelfY - 4.5) * cust.progress;
      } else if (cust.state == _CustomerState.shopping) {
        // 停留在貨架前
        curGx = cust.shelfX;
        curGy = cust.shelfY;
      } else if (cust.state == _CustomerState.queuing) {
        // 從貨架走到收銀櫃台排隊 (2.0, 4.5)
        curGx = cust.shelfX + (2.0 - cust.shelfX) * cust.progress;
        curGy = cust.shelfY + (4.5 - cust.shelfY) * cust.progress;
      } else if (cust.state == _CustomerState.leaving) {
        // 從櫃台走回門口離開
        curGx = 2.0 + (0.0 - 2.0) * cust.progress;
        curGy = 4.5 + (5.5 - 4.5) * cust.progress;
      }

      entities.add(
        _RenderableEntity(
          gx: curGx,
          gy: curGy,
          sortDepth: curGx + curGy + 0.2,
          render: (c) => _drawCustomer(c, cust, curGx, curGy, cx, cy),
        ),
      );
    }

    // 按深度由遠到近排序渲染
    entities.sort((a, b) => a.sortDepth.compareTo(b.sortDepth));
    for (final entity in entities) {
      entity.render(canvas);
    }

    // 4. 繪製浮動金幣文字特效 (Top overlay)
    for (final ft in floatingTexts) {
      final pos = _isoToScreen(ft.gridX, ft.gridY, cx, cy);
      final alpha = (1.0 - ft.age).clamp(0.0, 1.0);
      final toastPainter = TextPainter(
        text: TextSpan(
          text: ft.text,
          style: TextStyle(
            color: ft.color.withValues(alpha: alpha),
            fontSize: 12,
            fontWeight: FontWeight.bold,
            shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      toastPainter.paint(canvas, Offset(pos.dx - toastPainter.width / 2, pos.dy + ft.offsetY - 30));
    }
  }

  void _drawFixture(Canvas canvas, StoreFixture f, double cx, double cy) {
    final pos = _isoToScreen(f.gridX.toDouble(), f.gridY.toDouble(), cx, cy);

    if (!f.isPurchased) {
      // 裝潢模式下的虛擬未購置預覽框 (Ghost Blueprint)
      final blueprintPaint = Paint()
        ..color = Colors.amber.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawCircle(Offset(pos.dx, pos.dy), 14, blueprintPaint);
      _drawSprite(canvas, '➕', pos.dx - 7, pos.dy - 12, fontSize: 13);
      return;
    }

    // 實體家具投影
    final fixtureBg = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawOval(Rect.fromCenter(center: Offset(pos.dx, pos.dy + 4), width: 28, height: 14), fixtureBg);

    // 繪製設備圖示與光澤
    _drawSprite(canvas, f.icon, pos.dx - 12, pos.dy - 22, fontSize: 22);

    // 標籤銘牌 (例如：Lv.1)
    final labelPainter = TextPainter(
      text: TextSpan(
        text: f.name.substring(0, min(4, f.name.length)),
        style: const TextStyle(color: Colors.white70, fontSize: 8.5, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    labelPainter.paint(canvas, Offset(pos.dx - labelPainter.width / 2, pos.dy + 6));
  }

  void _drawCustomer(Canvas canvas, _SimCustomer cust, double gx, double gy, double cx, double cy) {
    final pos = _isoToScreen(gx, gy, cx, cy);

    // 腳下影子
    final shadowPaint = Paint()..color = Colors.black.withValues(alpha: 0.35);
    canvas.drawOval(Rect.fromCenter(center: Offset(pos.dx, pos.dy + 2), width: 14, height: 6), shadowPaint);

    // 小人頭像
    _drawSprite(canvas, cust.avatar, pos.dx - 9, pos.dy - 18, fontSize: 16);

    // 頭頂購物氣泡 (挑選中或結帳後提袋)
    if (cust.state == _CustomerState.shopping || cust.state == _CustomerState.queuing) {
      // 冒出購物想法氣泡
      final bubblePaint = Paint()..color = Colors.white;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(pos.dx - 2, pos.dy - 34, 18, 14), const Radius.circular(4)),
        bubblePaint,
      );
      _drawSprite(canvas, cust.targetItemIcon, pos.dx - 1, pos.dy - 34, fontSize: 10);
    } else if (cust.state == _CustomerState.leaving) {
      // 提著購物袋滿載而歸
      _drawSprite(canvas, '🛍️', pos.dx + 4, pos.dy - 12, fontSize: 11);
    }
  }

  void _drawSprite(Canvas canvas, String emoji, double x, double y, {double fontSize = 16}) {
    final tp = TextPainter(
      text: TextSpan(text: emoji, style: TextStyle(fontSize: fontSize)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(x, y));
  }

  @override
  bool shouldRepaint(covariant _IsometricStorePainter oldDelegate) => true;
}

class _RenderableEntity {
  final double gx;
  final double gy;
  final double sortDepth;
  final void Function(Canvas) render;

  _RenderableEntity({
    required this.gx,
    required this.gy,
    required this.sortDepth,
    required this.render,
  });
}

enum _CustomerState { entering, shopping, queuing, leaving }

class _SimCustomer {
  final String id;
  final String avatar;
  final String targetItemIcon;
  final String targetItemName;
  final double shelfX;
  final double shelfY;
  final double speed;
  _CustomerState state = _CustomerState.entering;
  double progress = 0.0;

  _SimCustomer({
    required this.id,
    required this.avatar,
    required this.targetItemIcon,
    required this.targetItemName,
    required this.shelfX,
    required this.shelfY,
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

