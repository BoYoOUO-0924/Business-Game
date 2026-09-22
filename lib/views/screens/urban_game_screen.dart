import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../models/player_life_state.dart';
import '../../services/audio_service.dart';
import '../components/smart_phone_modal.dart';

enum GameRoom { street, apartment, store }
enum PlayerCarryState { suitcase, empty, box }

/// 2.5D 低多邊形微縮景觀 (Low-Poly Isometric Diorama) 實體模擬經營主畫面
/// 融合頂級 3D Diorama 視覺、點擊移動 (Click-to-Move)、多空間無縫進出與實體搬箱/睡覺/收銀操作
class UrbanGameScreen extends StatefulWidget {
  final PlayerLifeState playerLife;
  final GameRoom initialRoom;
  final bool autoStartTicker;

  const UrbanGameScreen({
    super.key,
    required this.playerLife,
    this.initialRoom = GameRoom.street,
    this.autoStartTicker = true,
  });

  @override
  State<UrbanGameScreen> createState() => _UrbanGameScreenState();
}

class _ClickRipple {
  final Offset position;
  double progress; // 0.0 ~ 1.0
  final Color color;

  _ClickRipple({
    required this.position,
    this.color = const Color(0xFF38BDF8),
  }) : progress = 0.0;
}

class _UrbanGameScreenState extends State<UrbanGameScreen> with TickerProviderStateMixin {
  Ticker? _ticker;
  Timer? _gameClockTimer;
  final FocusNode _focusNode = FocusNode();
  final NumberFormat _currency = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

  // 當前房間
  late GameRoom _currentRoom;

  // 主角歸一化坐標 (0.0 ~ 1.0，適配 9:16 微縮容器)
  double _normX = 0.45;
  double _normY = 0.65;
  Offset? _targetNormPos;
  VoidCallback? _pendingArrivalAction;
  double _facingAngle = math.pi / 4;
  double _walkCycle = 0.0;
  bool _isMoving = false;
  late PlayerCarryState _carryState;

  // 點擊水波光圈清單
  final List<_ClickRipple> _ripples = [];

  // 動態情境互動
  String _activeActionLabel = '';
  IconData _activeActionIcon = Icons.touch_app_rounded;
  Color _activeActionColor = const Color(0xFF38BDF8);
  VoidCallback? _onActiveAction;

  // 睡眠過場
  double _sleepOverlayOpacity = 0.0;

  // 鍵盤輸入
  final Set<LogicalKeyboardKey> _pressedKeys = {};

  @override
  void initState() {
    super.initState();
    _currentRoom = widget.initialRoom;
    _carryState = widget.playerLife.isCarryingSuitcase ? PlayerCarryState.suitcase : PlayerCarryState.empty;

    _setInitialPosForRoom(_currentRoom);

    if (widget.autoStartTicker) {
      _ticker = createTicker(_onGameTick)..start();
      _gameClockTimer = Timer.periodic(const Duration(seconds: 3), (_) {
        if (mounted) widget.playerLife.tick();
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
      AudioService().playDoorChime();
    });
  }

  void _setInitialPosForRoom(GameRoom room) {
    switch (room) {
      case GameRoom.street:
        _normX = 0.45;
        _normY = 0.65;
        break;
      case GameRoom.apartment:
        _normX = 0.42;
        _normY = 0.70;
        break;
      case GameRoom.store:
        _normX = 0.32;
        _normY = 0.55;
        break;
    }
    _targetNormPos = null;
    _isMoving = false;
  }

  @override
  void dispose() {
    if (_ticker != null) {
      if (_ticker!.isActive) _ticker!.stop();
      _ticker!.dispose();
    }
    _gameClockTimer?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  // --- 遊戲物理與移動更新迴圈 (60 FPS) ---
  void _onGameTick(Duration elapsed) {
    if (!mounted) return;

    // 1. 更新點擊水波環進度
    if (_ripples.isNotEmpty) {
      for (final r in _ripples) {
        r.progress += 0.055;
      }
      _ripples.removeWhere((r) => r.progress >= 1.0);
    }

    // 2. 鍵盤輸入向量 (WASD / 方向鍵)
    double keyDx = 0.0;
    double keyDy = 0.0;
    if (_pressedKeys.contains(LogicalKeyboardKey.keyW) || _pressedKeys.contains(LogicalKeyboardKey.arrowUp)) keyDy -= 1.0;
    if (_pressedKeys.contains(LogicalKeyboardKey.keyS) || _pressedKeys.contains(LogicalKeyboardKey.arrowDown)) keyDy += 1.0;
    if (_pressedKeys.contains(LogicalKeyboardKey.keyA) || _pressedKeys.contains(LogicalKeyboardKey.arrowLeft)) keyDx -= 1.0;
    if (_pressedKeys.contains(LogicalKeyboardKey.keyD) || _pressedKeys.contains(LogicalKeyboardKey.arrowRight)) keyDx += 1.0;

    if (keyDx != 0.0 || keyDy != 0.0) {
      final mag = math.sqrt(keyDx * keyDx + keyDy * keyDy);
      final speed = _pressedKeys.contains(LogicalKeyboardKey.shiftLeft) ? 0.012 : 0.007;
      _normX = (_normX + (keyDx / mag) * speed).clamp(0.12, 0.88);
      _normY = (_normY + (keyDy / mag) * speed).clamp(0.35, 0.88);
      _facingAngle = math.atan2(keyDy, keyDx);
      _walkCycle += 0.22;
      _isMoving = true;
      _targetNormPos = null;
      _pendingArrivalAction = null;
    } else if (_targetNormPos != null) {
      // 3. 點擊導航移動 (Click-to-Move Path Interpolation)
      final dx = _targetNormPos!.dx - _normX;
      final dy = _targetNormPos!.dy - _normY;
      final dist = math.sqrt(dx * dx + dy * dy);

      if (dist > 0.012) {
        final speed = 0.0085;
        final step = math.min(speed, dist);
        _normX += (dx / dist) * step;
        _normY += (dy / dist) * step;
        _facingAngle = math.atan2(dy, dx);
        _walkCycle += 0.22;
        _isMoving = true;
      } else {
        _normX = _targetNormPos!.dx;
        _normY = _targetNormPos!.dy;
        _targetNormPos = null;
        _isMoving = false;
        final action = _pendingArrivalAction;
        _pendingArrivalAction = null;
        action?.call();
      }
    } else {
      _isMoving = false;
    }

    // 4. 更新情境互動
    _updateContextualAction();
    setState(() {});
  }

  // --- 點擊移動與智慧互動分發 ---
  void _handleScreenTap(Offset localPos, Size containerSize) {
    final normTapX = (localPos.dx / containerSize.width).clamp(0.0, 1.0);
    final normTapY = (localPos.dy / containerSize.height).clamp(0.0, 1.0);

    // 生成水波漣漪光圈
    _ripples.add(_ClickRipple(position: localPos, color: const Color(0xFF38BDF8)));

    // 檢查是否點擊特定互動熱區
    final hotspot = _findTappedHotspot(normTapX, normTapY);
    if (hotspot != null) {
      _targetNormPos = hotspot.walkTarget;
      _pendingArrivalAction = hotspot.onArrive;
      AudioService().playScanBeep();
      // 若已在目標點附近 (< 0.03)，直接立即觸發互動
      final dx = hotspot.walkTarget.dx - _normX;
      final dy = hotspot.walkTarget.dy - _normY;
      if (math.sqrt(dx * dx + dy * dy) < 0.03) {
        _targetNormPos = null;
        _isMoving = false;
        _pendingArrivalAction = null;
        hotspot.onArrive();
      }
    } else {
      // 點擊地面正常巡航
      _targetNormPos = Offset(normTapX.clamp(0.12, 0.88), normTapY.clamp(0.35, 0.88));
      _pendingArrivalAction = null;
      AudioService().playFootstep();
    }
  }

  _DioramaHotspot? _findTappedHotspot(double nx, double ny) {
    if (_currentRoom == GameRoom.street) {
      // 1. 公寓大門
      if (nx >= 0.40 && nx <= 0.56 && ny >= 0.56 && ny <= 0.72) {
        return _DioramaHotspot(
          walkTarget: const Offset(0.48, 0.66),
          onArrive: () => _transitionToRoom(GameRoom.apartment),
        );
      }
      // 2. CITY MART 超商門面
      if (nx >= 0.20 && nx <= 0.44 && ny >= 0.32 && ny <= 0.54) {
        return _DioramaHotspot(
          walkTarget: const Offset(0.36, 0.46),
          onArrive: () => _transitionToRoom(GameRoom.store),
        );
      }
      // 3. 計程車
      if (nx >= 0.54 && nx <= 0.74 && ny >= 0.46 && ny <= 0.58) {
        return _DioramaHotspot(
          walkTarget: const Offset(0.62, 0.54),
          onArrive: _showTaxiDialog,
        );
      }
    } else if (_currentRoom == GameRoom.apartment) {
      // 1. 折疊床
      if (nx >= 0.28 && nx <= 0.58 && ny >= 0.48 && ny <= 0.66) {
        return _DioramaHotspot(
          walkTarget: const Offset(0.44, 0.58),
          onArrive: _sleepInBedAction,
        );
      }
      // 2. 出口迎賓地墊
      if (nx >= 0.30 && nx <= 0.52 && ny >= 0.66 && ny <= 0.82) {
        return _DioramaHotspot(
          walkTarget: const Offset(0.42, 0.72),
          onArrive: () => _transitionToRoom(GameRoom.street),
        );
      }
    } else if (_currentRoom == GameRoom.store) {
      // 1. 進貨棧板紙箱
      if (nx >= 0.40 && nx <= 0.65 && ny >= 0.60 && ny <= 0.76) {
        return _DioramaHotspot(
          walkTarget: const Offset(0.52, 0.68),
          onArrive: _palletAction,
        );
      }
      // 2. 零食展示架
      if (nx >= 0.34 && nx <= 0.54 && ny >= 0.44 && ny <= 0.60) {
        return _DioramaHotspot(
          walkTarget: const Offset(0.44, 0.54),
          onArrive: _shelfAction,
        );
      }
      // 3. 收銀櫃台
      if (nx >= 0.62 && nx <= 0.88 && ny >= 0.48 && ny <= 0.66) {
        return _DioramaHotspot(
          walkTarget: const Offset(0.72, 0.58),
          onArrive: _counterAction,
        );
      }
      // 4. 出口大門
      if (nx >= 0.15 && nx <= 0.32 && ny >= 0.38 && ny <= 0.54) {
        return _DioramaHotspot(
          walkTarget: const Offset(0.25, 0.48),
          onArrive: () => _transitionToRoom(GameRoom.street),
        );
      }
    }
    return null;
  }

  // --- 動態情境動作判定 ---
  void _updateContextualAction() {
    _activeActionLabel = '';
    _onActiveAction = null;

    if (_currentRoom == GameRoom.street) {
      // 靠近公寓大門
      if (_dist(_normX, _normY, 0.48, 0.66) < 0.09) {
        _activeActionLabel = '進入出租套房';
        _activeActionIcon = Icons.door_front_door_rounded;
        _activeActionColor = const Color(0xFF38BDF8);
        _onActiveAction = () => _transitionToRoom(GameRoom.apartment);
        return;
      }
      // 靠近超商大門
      if (_dist(_normX, _normY, 0.36, 0.46) < 0.09) {
        _activeActionLabel = '走進 CITY MART';
        _activeActionIcon = Icons.storefront_rounded;
        _activeActionColor = const Color(0xFFF97316);
        _onActiveAction = () => _transitionToRoom(GameRoom.store);
        return;
      }
      // 靠近計程車
      if (_dist(_normX, _normY, 0.62, 0.54) < 0.09) {
        _activeActionLabel = '呼叫計程車';
        _activeActionIcon = Icons.local_taxi_rounded;
        _activeActionColor = const Color(0xFFFBBF24);
        _onActiveAction = _showTaxiDialog;
        return;
      }
    } else if (_currentRoom == GameRoom.apartment) {
      // 靠近折疊床
      if (_dist(_normX, _normY, 0.44, 0.58) < 0.09) {
        _activeActionLabel = '在折疊床睡覺';
        _activeActionIcon = Icons.bed_rounded;
        _activeActionColor = const Color(0xFF0284C7);
        _onActiveAction = _sleepInBedAction;
        return;
      }
      // 靠近出口
      if (_dist(_normX, _normY, 0.42, 0.72) < 0.08) {
        _activeActionLabel = '走出套房';
        _activeActionIcon = Icons.exit_to_app_rounded;
        _activeActionColor = Colors.white70;
        _onActiveAction = () => _transitionToRoom(GameRoom.street);
        return;
      }
    } else if (_currentRoom == GameRoom.store) {
      // 靠近棧板紙箱
      if (_dist(_normX, _normY, 0.52, 0.68) < 0.09) {
        _activeActionLabel = '搬起補貨紙箱';
        _activeActionIcon = Icons.inventory_2_rounded;
        _activeActionColor = const Color(0xFFD97706);
        _onActiveAction = _palletAction;
        return;
      }
      // 靠近商品貨架
      if (_dist(_normX, _normY, 0.44, 0.54) < 0.09) {
        _activeActionLabel = '拆箱上架補貨';
        _activeActionIcon = Icons.shopping_cart_rounded;
        _activeActionColor = const Color(0xFF10B981);
        _onActiveAction = _shelfAction;
        return;
      }
      // 靠近收銀櫃台
      if (_dist(_normX, _normY, 0.72, 0.58) < 0.09) {
        _activeActionLabel = '收銀台打工結帳';
        _activeActionIcon = Icons.point_of_sale_rounded;
        _activeActionColor = const Color(0xFFFBBF24);
        _onActiveAction = _counterAction;
        return;
      }
      // 靠近出口
      if (_dist(_normX, _normY, 0.25, 0.48) < 0.08) {
        _activeActionLabel = '走出超商';
        _activeActionIcon = Icons.exit_to_app_rounded;
        _activeActionColor = Colors.white70;
        _onActiveAction = () => _transitionToRoom(GameRoom.street);
        return;
      }
    }
  }

  void _palletAction() {
    setState(() => _carryState = PlayerCarryState.box);
    AudioService().playRestock();
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: Color(0xFFD97706),
        content: Text('📦 已抱起補貨紙箱！請走到零食陳列架前補貨。'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _shelfAction() {
    setState(() => _carryState = PlayerCarryState.empty);
    AudioService().playRestock();
    AudioService().playFanfare();
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: Color(0xFF10B981),
        content: Text('🛒 成功補滿零食架！顧客可以開始挑選購買了！'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _counterAction() {
    AudioService().playScanBeep();
    AudioService().playCashRegister();
    widget.playerLife.takePartTimeShift(hours: 1, hourlyWage: 150);
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: Color(0xFFF59E0B),
        content: Text('嗶！結帳完成，現領打工現金 +NT\$ 150 入帳！'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  double _dist(double x1, double y1, double x2, double y2) {
    final dx = x1 - x2;
    final dy = y1 - y2;
    return math.sqrt(dx * dx + dy * dy);
  }

  void _transitionToRoom(GameRoom target) {
    AudioService().playDoorChime();
    setState(() {
      _currentRoom = target;
      _setInitialPosForRoom(target);
    });
  }

  void _sleepInBedAction() {
    setState(() => _sleepOverlayOpacity = 1.0);
    AudioService().playFanfare();

    Future.delayed(const Duration(milliseconds: 600), () {
      widget.playerLife.sleepInApartment();
      _carryState = PlayerCarryState.empty;
      if (mounted) {
        setState(() => _sleepOverlayOpacity = 0.0);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF0284C7),
            content: Text('🛌 體力恢復至 100%，早晨 07:00 天亮了！皮箱已安放房內。'),
          ),
        );
      }
    });
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
          '目前您正位於「舊城幸福里」。\n\n隨著商業版圖擴展，後續章節將可搭乘計程車前往「中央金融 CBD」、「海濱商業區」與「高新科技園區」！',
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

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      _pressedKeys.add(event.logicalKey);
      if (event.logicalKey == LogicalKeyboardKey.space || event.logicalKey == LogicalKeyboardKey.keyE) {
        _onActiveAction?.call();
        return KeyEventResult.handled;
      }
    } else if (event is KeyUpEvent) {
      _pressedKeys.remove(event.logicalKey);
    }
    return KeyEventResult.ignored;
  }

  String _getRoomBackgroundAsset(GameRoom room) {
    switch (room) {
      case GameRoom.street:
        return 'assets/images/urban_diorama_clean.jpg';
      case GameRoom.apartment:
        return 'assets/images/apartment_diorama.jpg';
      case GameRoom.store:
        return 'assets/images/store_diorama.jpg';
    }
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: const Key('capture'),
      child: Focus(
        focusNode: _focusNode,
        onKeyEvent: _handleKeyEvent,
        autofocus: true,
        child: Scaffold(
          backgroundColor: const Color(0xFF0F0E17),
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // 鎖定 9:16 微縮容器（手機全螢幕貼合、電腦端居中）
                final maxW = constraints.maxWidth;
                final maxH = constraints.maxHeight;
                double containerW = maxW;
                double containerH = maxW * (16.0 / 9.0);

                if (containerH > maxH) {
                  containerH = maxH;
                  containerW = maxH * (9.0 / 16.0);
                }

                return Center(
                  child: SizedBox(
                    width: containerW,
                    height: containerH,
                    child: AnimatedBuilder(
                      animation: widget.playerLife,
                      builder: (context, _) {
                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            // 1. 頂級低多邊形微縮景觀 3D 視圖 (Diorama Render)
                            Positioned.fill(
                              child: Image.asset(
                                _getRoomBackgroundAsset(_currentRoom),
                                fit: BoxFit.cover,
                              ),
                            ),

                            // 2. 點擊移動與角色走動畫布
                            Positioned.fill(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTapDown: (details) => _handleScreenTap(details.localPosition, Size(containerW, containerH)),
                                child: CustomPaint(
                                  painter: _DioramaPlayerPainter(
                                    normX: _normX,
                                    normY: _normY,
                                    facingAngle: _facingAngle,
                                    walkCycle: _walkCycle,
                                    isMoving: _isMoving,
                                    carryState: _carryState,
                                    ripples: _ripples,
                                    targetPos: _targetNormPos != null ? Offset(_targetNormPos!.dx * containerW, _targetNormPos!.dy * containerH) : null,
                                  ),
                                ),
                              ),
                            ),

                            // 3. 睡眠過場
                            AnimatedOpacity(
                              opacity: _sleepOverlayOpacity,
                              duration: const Duration(milliseconds: 500),
                              child: IgnorePointer(
                                ignoring: _sleepOverlayOpacity == 0.0,
                                child: Container(
                                  color: Colors.black,
                                  child: const Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.bedtime_rounded, color: Color(0xFF38BDF8), size: 48),
                                        SizedBox(height: 16),
                                        Text('熟睡中...', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                        SizedBox(height: 6),
                                        Text('夜幕降臨 ➜ 晨曦 07:00', style: TextStyle(color: Colors.white70, fontSize: 13)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            // 4. 頂部 HUD (生命條、體力、現金)
                            Positioned(
                              top: 10,
                              left: 12,
                              right: 12,
                              child: _buildTopHud(),
                            ),

                            // 5. 右下角情境動作按鈕 (Contextual Action Button)
                            Positioned(
                              right: 16,
                              bottom: 24,
                              child: _buildActionButton(),
                            ),

                            // 6. 右側公務手機 SmartOS
                            Positioned(
                              top: 96,
                              right: 12,
                              child: _buildSmartPhoneWidget(),
                            ),

                            // 7. 左上角當前空間標籤
                            Positioned(
                              top: 86,
                              left: 12,
                              child: _buildRoomIndicator(),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // --- UI 元件 ---
  Widget _buildTopHud() {
    final life = widget.playerLife;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
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
            _buildCashPill(life.personalCash),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white24),
          ),
          child: Row(
            children: [
              const Text('📜 ', style: TextStyle(fontSize: 12)),
              Expanded(
                child: Text(
                  life.currentQuest,
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Text(life.timeFormatted, style: const TextStyle(color: Color(0xFFFBBF24), fontSize: 11)),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1B29).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: iconColor.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: iconColor, size: 12),
                    const SizedBox(width: 3),
                    Text(label, style: TextStyle(color: iconColor, fontSize: 9.0, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(width: 6),
                Text(valueText, style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 3),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: Stack(
              children: [
                Container(height: 4, color: Colors.white12),
                FractionallySizedBox(
                  widthFactor: ratio,
                  child: Container(height: 4, decoration: BoxDecoration(gradient: LinearGradient(colors: fillGradient))),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF2E2412),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFBBF24).withValues(alpha: 0.8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.monetization_on_rounded, color: Color(0xFFFBBF24), size: 15),
          const SizedBox(width: 4),
          Text(_currency.format(cash), style: const TextStyle(color: Color(0xFFFDE68A), fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildRoomIndicator() {
    String name = '舊城幸福里街道';
    IconData icon = Icons.location_city_rounded;
    Color col = Colors.white70;

    if (_currentRoom == GameRoom.apartment) {
      name = '街角出租套房 (頂樓)';
      icon = Icons.home_rounded;
      col = const Color(0xFF38BDF8);
    } else if (_currentRoom == GameRoom.store) {
      name = 'CITY MART 超商門市';
      icon = Icons.storefront_rounded;
      col = const Color(0xFFF97316);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: col.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: col, size: 14),
          const SizedBox(width: 5),
          Text(name, style: TextStyle(color: col, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildActionButton() {
    final hasAction = _activeActionLabel.isNotEmpty;

    return GestureDetector(
      onTap: () {
        if (hasAction) {
          AudioService().playScanBeep();
          _onActiveAction?.call();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: hasAction ? _activeActionColor : Colors.black.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: hasAction ? Colors.white : Colors.white24, width: hasAction ? 2.5 : 1.5),
          boxShadow: hasAction
              ? [
                  BoxShadow(
                    color: _activeActionColor.withValues(alpha: 0.6),
                    blurRadius: 18,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasAction ? _activeActionIcon : Icons.navigation_rounded,
              color: hasAction ? Colors.black : Colors.white38,
              size: 22,
            ),
            if (hasAction) ...[
              const SizedBox(width: 8),
              Text(
                '$_activeActionLabel (Space/E)',
                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSmartPhoneWidget() {
    final hasUnread = !widget.playerLife.hasReadUncleMessage;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasUnread)
          GestureDetector(
            onTap: () => SmartPhoneModal.show(context, widget.playerLife),
            child: Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF38BDF8)),
              ),
              child: const Text('叔叔發來新簡訊！點擊查看', style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold)),
            ),
          ),
        GestureDetector(
          onTap: () => SmartPhoneModal.show(context, widget.playerLife),
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFF18181B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF71717A), width: 2),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(Icons.smartphone_rounded, color: Colors.white, size: 24),
                if (hasUnread)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      width: 16,
                      height: 16,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEF4444),
                        shape: BoxShape.circle,
                      ),
                      child: const Text(
                        '1',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
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

class _DioramaHotspot {
  final Offset walkTarget;
  final VoidCallback onArrive;

  _DioramaHotspot({required this.walkTarget, required this.onArrive});
}

// ============================================================================
// 角色與點擊游標 CustomPainter
// ============================================================================
class _DioramaPlayerPainter extends CustomPainter {
  final double normX;
  final double normY;
  final double facingAngle;
  final double walkCycle;
  final bool isMoving;
  final PlayerCarryState carryState;
  final List<_ClickRipple> ripples;
  final Offset? targetPos;

  _DioramaPlayerPainter({
    required this.normX,
    required this.normY,
    required this.facingAngle,
    required this.walkCycle,
    required this.isMoving,
    required this.carryState,
    required this.ripples,
    required this.targetPos,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final px = normX * size.width;
    final py = normY * size.height;

    // 1. 點擊水波環
    for (final ripple in ripples) {
      final prog = ripple.progress.clamp(0.0, 1.0);
      final alpha = (1.0 - prog);
      final r = 4.0 + prog * 30.0;

      canvas.drawOval(
        Rect.fromCenter(center: ripple.position, width: r * 2.0, height: r),
        Paint()
          ..color = ripple.color.withValues(alpha: (alpha * 0.85).clamp(0.0, 1.0))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0 * (1.0 - prog * 0.5),
      );
    }

    // 2. 目標點指引光標
    if (targetPos != null) {
      final pulse = 0.5 + 0.5 * (math.sin(walkCycle * 2.5).abs());
      canvas.drawOval(
        Rect.fromCenter(center: targetPos!, width: 20, height: 10),
        Paint()
          ..color = const Color(0xFF38BDF8).withValues(alpha: pulse * 0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8,
      );
      canvas.drawCircle(targetPos!, 2.5, Paint()..color = Colors.white.withValues(alpha: pulse));
    }

    // 3. 角色腳底陰影
    canvas.drawOval(
      Rect.fromCenter(center: Offset(px, py + 2), width: 22, height: 10),
      Paint()..color = Colors.black.withValues(alpha: 0.45),
    );

    // 4. 角色立體模型
    _drawPlayerModel(canvas, Offset(px, py));
  }

  void _drawPlayerModel(Canvas canvas, Offset p) {
    final bob = isMoving ? math.sin(walkCycle) * 2.2 : 0.0;
    final legSwing = isMoving ? math.sin(walkCycle) * 5.0 : 0.0;

    // 腿部與 Oxford 皮鞋
    final legPaint = Paint()..color = const Color(0xFF1E293B)..strokeWidth = 3.2..strokeCap = StrokeCap.round;
    // 左腿
    canvas.drawLine(Offset(p.dx - 3, p.dy - 10), Offset(p.dx - 3 - legSwing * 0.5, p.dy + legSwing), legPaint);
    // 右腿
    canvas.drawLine(Offset(p.dx + 3, p.dy - 10), Offset(p.dx + 3 + legSwing * 0.5, p.dy - legSwing), legPaint);
    // 鞋子
    canvas.drawCircle(Offset(p.dx - 3 - legSwing * 0.5, p.dy + legSwing), 2.2, Paint()..color = Colors.black);
    canvas.drawCircle(Offset(p.dx + 3 + legSwing * 0.5, p.dy - legSwing), 2.2, Paint()..color = Colors.black);

    // 風衣軀幹 (Trench Coat)
    final coatRect = Rect.fromCenter(center: Offset(p.dx, p.dy - 18 + bob), width: 14, height: 15);
    canvas.drawRRect(
      RRect.fromRectAndRadius(coatRect, const Radius.circular(3)),
      Paint()..color = const Color(0xFFB45309), // 駝色風衣
    );
    // 領子
    canvas.drawRect(Rect.fromLTWH(p.dx - 2, p.dy - 25 + bob, 4, 6), Paint()..color = const Color(0xFF78350F));

    // 頭部與髮型
    final headCenter = Offset(p.dx, p.dy - 28 + bob);
    // 頭部皮膚
    canvas.drawCircle(headCenter, 6.0, Paint()..color = const Color(0xFFFED7AA));
    // 黑色短髮
    final hairPath = Path()
      ..addArc(Rect.fromCircle(center: headCenter, radius: 6.2), math.pi, math.pi)
      ..close();
    canvas.drawPath(hairPath, Paint()..color = const Color(0xFF1C1917));
    // 眼睛
    canvas.drawCircle(Offset(headCenter.dx + 2, headCenter.dy - 0.5), 1.0, Paint()..color = Colors.black);

    // 手持物
    if (carryState == PlayerCarryState.suitcase) {
      // 旅行皮箱 (隨步伐微擺動)
      final caseCenter = Offset(p.dx + 10, p.dy - 14 + bob - legSwing * 0.3);
      final caseRect = Rect.fromCenter(center: caseCenter, width: 10, height: 8);
      canvas.drawRRect(
        RRect.fromRectAndRadius(caseRect, const Radius.circular(2)),
        Paint()..color = const Color(0xFF78350F), // 皮革棕
      );
      // 黃銅包角
      canvas.drawRect(Rect.fromLTWH(caseCenter.dx - 5, caseCenter.dy - 4, 2, 2), Paint()..color = const Color(0xFFFBBF24));
      canvas.drawRect(Rect.fromLTWH(caseCenter.dx + 3, caseCenter.dy - 4, 2, 2), Paint()..color = const Color(0xFFFBBF24));
    } else if (carryState == PlayerCarryState.box) {
      // 雙手高高抱起黃色物流紙箱
      final boxCenter = Offset(p.dx, p.dy - 22 + bob);
      final boxRect = Rect.fromCenter(center: boxCenter, width: 16, height: 13);
      canvas.drawRRect(
        RRect.fromRectAndRadius(boxRect, const Radius.circular(2)),
        Paint()..color = const Color(0xFFD97706),
      );
      // 封箱膠帶
      canvas.drawLine(Offset(boxCenter.dx - 8, boxCenter.dy), Offset(boxCenter.dx + 8, boxCenter.dy), Paint()..color = const Color(0xFFB45309)..strokeWidth = 2);
    }
  }

  @override
  bool shouldRepaint(covariant _DioramaPlayerPainter oldDelegate) => true;
}
