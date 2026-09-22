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

/// 2.5D Isometric 實體模擬經營主畫面 (Urban Ambition Act 1)
/// 具備真實 2.5D 等角投影地圖、WASD/虛擬搖桿角色操控、3 大無縫進出房間與實體搬箱/睡覺/收銀操作
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

class _UrbanGameScreenState extends State<UrbanGameScreen> with TickerProviderStateMixin {
  Ticker? _ticker;
  Timer? _gameClockTimer;
  final FocusNode _focusNode = FocusNode();
  final NumberFormat _currency = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

  // 當前房間
  late GameRoom _currentRoom;

  // 主角網格坐標 (Grid Coordinates gx, gy)
  double _gx = 4.0;
  double _gy = 5.0;
  double _facingAngle = math.pi / 4; // 面向東南 (2.5D 預設朝向)
  double _walkCycle = 0.0;
  bool _isMoving = false;
  late PlayerCarryState _carryState;

  // 搖桿輸入
  Offset _joystickOffset = Offset.zero;
  bool _isDraggingJoystick = false;

  // 鍵盤輸入
  final Set<LogicalKeyboardKey> _pressedKeys = {};

  // 動態情境互動
  String _activeActionLabel = '';
  IconData _activeActionIcon = Icons.touch_app_rounded;
  Color _activeActionColor = const Color(0xFF38BDF8);
  VoidCallback? _onActiveAction;

  // 睡眠遮罩動畫
  double _sleepOverlayOpacity = 0.0;

  @override
  void initState() {
    super.initState();
    _currentRoom = widget.initialRoom;
    _carryState = widget.playerLife.isCarryingSuitcase ? PlayerCarryState.suitcase : PlayerCarryState.empty;

    // 依初始房間放置角色
    _setInitialPlayerPosForRoom(_currentRoom);

    // 60 FPS 物理與輸入遊戲循環
    if (widget.autoStartTicker) {
      _ticker = createTicker(_onGameTick)..start();

      // 獨立真實時間時鐘 (每 3 秒推進遊戲內 1 分鐘)
      _gameClockTimer = Timer.periodic(const Duration(seconds: 3), (_) {
        if (mounted) widget.playerLife.tick();
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
      AudioService().playDoorChime();
    });
  }

  void _setInitialPlayerPosForRoom(GameRoom room) {
    switch (room) {
      case GameRoom.street:
        _gx = 4.5;
        _gy = 6.0;
        break;
      case GameRoom.apartment:
        _gx = 3.0;
        _gy = 4.5;
        break;
      case GameRoom.store:
        _gx = 4.0;
        _gy = 5.5;
        break;
    }
  }

  @override
  void dispose() {
    if (_ticker != null) {
      if (_ticker!.isActive) {
        _ticker!.stop();
      }
      _ticker!.dispose();
    }
    _gameClockTimer?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  void _onGameTick(Duration elapsed) {
    if (!mounted) return;

    // 1. 計算輸入向量 (鍵盤 + 虛擬搖桿)
    double inputX = 0.0;
    double inputY = 0.0;

    if (_pressedKeys.contains(LogicalKeyboardKey.keyW) || _pressedKeys.contains(LogicalKeyboardKey.arrowUp)) inputY -= 1.0;
    if (_pressedKeys.contains(LogicalKeyboardKey.keyS) || _pressedKeys.contains(LogicalKeyboardKey.arrowDown)) inputY += 1.0;
    if (_pressedKeys.contains(LogicalKeyboardKey.keyA) || _pressedKeys.contains(LogicalKeyboardKey.arrowLeft)) inputX -= 1.0;
    if (_pressedKeys.contains(LogicalKeyboardKey.keyD) || _pressedKeys.contains(LogicalKeyboardKey.arrowRight)) inputX += 1.0;

    if (_joystickOffset != Offset.zero) {
      inputX += _joystickOffset.dx;
      inputY += _joystickOffset.dy;
    }

    final mag = math.sqrt(inputX * inputX + inputY * inputY);
    if (mag > 0.05) {
      _isMoving = true;
      final normX = inputX / (mag > 1.0 ? mag : 1.0);
      final normY = inputY / (mag > 1.0 ? mag : 1.0);

      // 移動速度 (約每秒 3.5 格)
      final speed = _pressedKeys.contains(LogicalKeyboardKey.shiftLeft) ? 0.08 : 0.05;

      final nextGx = _gx + normX * speed;
      final nextGy = _gy + normY * speed;

      // 邊界碰撞檢測
      final bounds = _getRoomBounds(_currentRoom);
      if (nextGx >= bounds.left && nextGx <= bounds.right) _gx = nextGx;
      if (nextGy >= bounds.top && nextGy <= bounds.bottom) _gy = nextGy;

      _facingAngle = math.atan2(normY, normX);
      _walkCycle += 0.25;
    } else {
      _isMoving = false;
    }

    // 2. 檢測可互動實體 (Contextual Action Detection)
    _checkInteractables();

    setState(() {});
  }

  Rect _getRoomBounds(GameRoom room) {
    switch (room) {
      case GameRoom.street:
        return const Rect.fromLTWH(0.8, 1.2, 8.4, 7.6);
      case GameRoom.apartment:
        return const Rect.fromLTWH(1.2, 1.2, 4.6, 4.6);
      case GameRoom.store:
        return const Rect.fromLTWH(1.2, 1.2, 5.6, 5.6);
    }
  }

  void _checkInteractables() {
    _activeActionLabel = '';
    _onActiveAction = null;

    if (_currentRoom == GameRoom.street) {
      // 靠近老公寓大門 (gx: 2.0, gy: 1.5)
      final distApt = _dist(_gx, _gy, 2.0, 1.5);
      if (distApt < 1.2) {
        _activeActionLabel = '進入出租套房';
        _activeActionIcon = Icons.door_front_door_rounded;
        _activeActionColor = const Color(0xFF38BDF8);
        _onActiveAction = () => _transitionToRoom(GameRoom.apartment);
        return;
      }

      // 靠近 CITY MART 大門 (gx: 7.0, gy: 1.5)
      final distStore = _dist(_gx, _gy, 7.0, 1.5);
      if (distStore < 1.2) {
        _activeActionLabel = '進入超商門市';
        _activeActionIcon = Icons.storefront_rounded;
        _activeActionColor = const Color(0xFFF97316);
        _onActiveAction = () => _transitionToRoom(GameRoom.store);
        return;
      }

      // 靠近計程車 (gx: 5.0, gy: 7.0)
      final distTaxi = _dist(_gx, _gy, 5.0, 7.0);
      if (distTaxi < 1.4) {
        _activeActionLabel = '大都會計程車';
        _activeActionIcon = Icons.local_taxi_rounded;
        _activeActionColor = const Color(0xFFFACC15);
        _onActiveAction = _showTaxiDialog;
        return;
      }
    } else if (_currentRoom == GameRoom.apartment) {
      // 靠近折疊床 (gx: 4.0, gy: 2.0)
      final distBed = _dist(_gx, _gy, 4.0, 2.0);
      if (distBed < 1.3) {
        _activeActionLabel = '在折疊床睡覺';
        _activeActionIcon = Icons.bed_rounded;
        _activeActionColor = const Color(0xFF38BDF8);
        _onActiveAction = _sleepInBedAction;
        return;
      }

      // 靠近套房房門出口 (gx: 3.0, gy: 5.5)
      final distDoor = _dist(_gx, _gy, 3.0, 5.5);
      if (distDoor < 1.2) {
        _activeActionLabel = '返回街道';
        _activeActionIcon = Icons.exit_to_app_rounded;
        _activeActionColor = Colors.white70;
        _onActiveAction = () => _transitionToRoom(GameRoom.street);
        return;
      }
    } else if (_currentRoom == GameRoom.store) {
      // 靠近進貨紙箱棧板 (gx: 1.8, gy: 5.0)
      final distBox = _dist(_gx, _gy, 1.8, 5.0);
      if (distBox < 1.3 && _carryState != PlayerCarryState.box) {
        _activeActionLabel = '搬起補貨紙箱';
        _activeActionIcon = Icons.inventory_2_rounded;
        _activeActionColor = const Color(0xFFD97706);
        _onActiveAction = () {
          _carryState = PlayerCarryState.box;
          AudioService().playRestock();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Color(0xFFD97706),
              content: Text('📦 抱起了滿箱的零食！請走到中間貨架前拆箱補貨。'),
              duration: Duration(seconds: 2),
            ),
          );
        };
        return;
      }

      // 靠近商品貨架 (gx: 3.5, gy: 3.2)
      final distShelf = _dist(_gx, _gy, 3.5, 3.2);
      if (distShelf < 1.4 && _carryState == PlayerCarryState.box) {
        _activeActionLabel = '拆箱上架補貨';
        _activeActionIcon = Icons.shopping_cart_rounded;
        _activeActionColor = const Color(0xFF10B981);
        _onActiveAction = () {
          _carryState = PlayerCarryState.empty;
          AudioService().playRestock();
          AudioService().playFanfare();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Color(0xFF10B981),
              content: Text('🛒 成功補滿零食展示架！顧客可以開始挑選購買了！'),
              duration: Duration(seconds: 2),
            ),
          );
        };
        return;
      }

      // 靠近收銀櫃台 (gx: 5.0, gy: 2.8)
      final distCounter = _dist(_gx, _gy, 5.0, 2.8);
      if (distCounter < 1.4) {
        _activeActionLabel = '收銀台打工結帳';
        _activeActionIcon = Icons.point_of_sale_rounded;
        _activeActionColor = const Color(0xFFFBBF24);
        _onActiveAction = () {
          AudioService().playScanBeep();
          AudioService().playCashRegister();
          widget.playerLife.takePartTimeShift(hours: 1, hourlyWage: 150);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Color(0xFFF59E0B),
              content: Text('嗶！顧客結帳完成，現領打工現金 +NT\$ 150 入帳！'),
              duration: Duration(seconds: 2),
            ),
          );
        };
        return;
      }

      // 靠近超商出口 (gx: 4.0, gy: 6.5)
      final distDoor = _dist(_gx, _gy, 4.0, 6.5);
      if (distDoor < 1.2) {
        _activeActionLabel = '走出超商';
        _activeActionIcon = Icons.exit_to_app_rounded;
        _activeActionColor = Colors.white70;
        _onActiveAction = () => _transitionToRoom(GameRoom.street);
        return;
      }
    }
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
      _setInitialPlayerPosForRoom(target);
    });
  }

  void _sleepInBedAction() {
    setState(() => _sleepOverlayOpacity = 1.0);
    AudioService().playFanfare();

    Future.delayed(const Duration(milliseconds: 600), () {
      widget.playerLife.sleepInApartment();
      _carryState = PlayerCarryState.empty; // 皮箱放在套房床邊了
      if (mounted) {
        setState(() => _sleepOverlayOpacity = 0.0);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF0284C7),
            content: Text('🛌 睡了一個好覺！體力恢復至 100%，早晨 07:00 天亮了！皮箱已安放在房內。'),
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
          '目前您正位於「舊城幸福里」。\n\n隨著主線商業擴展，後續章節將可搭乘計程車前往「中央金融 CBD」、「海濱商業區」與「高新科技園區」簽署新門市店租！',
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

  // --- 鍵盤輸入事件 ---
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
                // 滿版 2.5D Isometric 畫布
                final screenW = constraints.maxWidth;
                final screenH = constraints.maxHeight;

                return AnimatedBuilder(
                  animation: widget.playerLife,
                  builder: (context, _) {
                    return Stack(
                      children: [
                        // 1. 2.5D Isometric 核心空間畫布
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _IsometricWorldPainter(
                              room: _currentRoom,
                              playerGx: _gx,
                              playerGy: _gy,
                              facingAngle: _facingAngle,
                              walkCycle: _walkCycle,
                              isMoving: _isMoving,
                              carryState: _carryState,
                              screenWidth: screenW,
                              screenHeight: screenH,
                            ),
                          ),
                        ),

                        // 2. 睡眠過場暗化層
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

                        // 3. 頂部 1:1 概念圖風格 HUD
                        Positioned(
                          top: 10,
                          left: 14,
                          right: 14,
                          child: _buildTopHud(),
                        ),

                        // 4. 左下角虛擬類比搖桿 (Virtual Joystick)
                        Positioned(
                          left: 24,
                          bottom: 28,
                          child: _buildVirtualJoystick(),
                        ),

                        // 5. 右下角情境動作按鈕 (Contextual Action Button)
                        Positioned(
                          right: 24,
                          bottom: 28,
                          child: _buildActionButton(),
                        ),

                        // 6. 右側懸浮公務手機 SmartOS 按鈕
                        Positioned(
                          top: 100,
                          right: 14,
                          child: _buildSmartPhoneWidget(),
                        ),

                        // 7. 左上角當前空間標籤
                        Positioned(
                          top: 86,
                          left: 16,
                          child: _buildRoomIndicator(),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // --- UI 子元件建置 ---

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
        color: const Color(0xFF181724).withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: iconColor.withValues(alpha: 0.4)),
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
                  Icon(icon, color: iconColor, size: 13),
                  const SizedBox(width: 3),
                  Text(label, style: TextStyle(color: iconColor, fontSize: 9.5, fontWeight: FontWeight.bold)),
                ],
              ),
              Text(valueText, style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold)),
            ],
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
    String name = '旧城幸福里街道';
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

  /// 虛擬類比搖桿 (Virtual Analog Joystick)
  Widget _buildVirtualJoystick() {
    return GestureDetector(
      onPanStart: (details) {
        setState(() => _isDraggingJoystick = true);
      },
      onPanUpdate: (details) {
        final local = details.localPosition - const Offset(55, 55);
        final dist = local.distance;
        final maxR = 40.0;
        final clamped = dist > maxR ? Offset(local.dx / dist * maxR, local.dy / dist * maxR) : local;
        setState(() {
          _joystickOffset = Offset(clamped.dx / maxR, clamped.dy / maxR);
        });
      },
      onPanEnd: (_) {
        setState(() {
          _isDraggingJoystick = false;
          _joystickOffset = Offset.zero;
        });
      },
      child: Container(
        width: 110,
        height: 110,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: 0.55),
          border: Border.all(color: Colors.white30, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 10,
            ),
          ],
        ),
        child: Center(
          child: Transform.translate(
            offset: _joystickOffset * 35.0,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: _isDraggingJoystick
                      ? [const Color(0xFF38BDF8), const Color(0xFF0284C7)]
                      : [const Color(0xFF52525B), const Color(0xFF27272A)],
                ),
                border: Border.all(color: Colors.white70, width: 1.5),
              ),
              child: const Icon(Icons.gamepad_rounded, color: Colors.white70, size: 22),
            ),
          ),
        ),
      ),
    );
  }

  /// 右下角情境動作按鈕
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

// ============================================================================
// 2.5D Isometric World CustomPainter
// ============================================================================
class _IsometricWorldPainter extends CustomPainter {
  final GameRoom room;
  final double playerGx;
  final double playerGy;
  final double facingAngle;
  final double walkCycle;
  final bool isMoving;
  final PlayerCarryState carryState;
  final double screenWidth;
  final double screenHeight;

  // 2.5D 等角比例常數
  static const double tileW = 84.0;
  static const double tileH = 42.0;

  _IsometricWorldPainter({
    required this.room,
    required this.playerGx,
    required this.playerGy,
    required this.facingAngle,
    required this.walkCycle,
    required this.isMoving,
    required this.carryState,
    required this.screenWidth,
    required this.screenHeight,
  });

  Offset _iso(double gx, double gy, double originX, double originY) {
    final x = originX + (gx - gy) * (tileW / 2);
    final y = originY + (gx + gy) * (tileH / 2);
    return Offset(x, y);
  }

  @override
  void paint(Canvas canvas, Size size) {
    // 依據房間與主角位置計算相機原點，讓場景飽滿居中
    final originX = size.width / 2;
    double originY = size.height * 0.16;
    if (room == GameRoom.apartment) {
      originY = size.height * 0.22;
    } else if (room == GameRoom.store) {
      originY = size.height * 0.18;
    }

    switch (room) {
      case GameRoom.street:
        _paintStreet(canvas, originX, originY);
        break;
      case GameRoom.apartment:
        _paintApartment(canvas, originX, originY);
        break;
      case GameRoom.store:
        _paintStore(canvas, originX, originY);
        break;
    }

    // 繪製 2.5D 主角模型
    _paintPlayer(canvas, originX, originY);
  }

  // --- 空間 1: 幸福里街道 (Street) ---
  void _paintStreet(Canvas canvas, double ox, double oy) {
    const cols = 10;
    const rows = 10;

    // 瀝青地面與人行道地磚
    for (int gy = 0; gy < rows; gy++) {
      for (int gx = 0; gx < cols; gx++) {
        final p = _iso(gx.toDouble(), gy.toDouble(), ox, oy);
        final isSidewalk = (gy <= 2) || (gx <= 1);
        final tileColor = isSidewalk ? const Color(0xFF334155) : const Color(0xFF1E293B);

        _drawDiamondTile(canvas, p, tileColor, isSidewalk ? Colors.white12 : Colors.black26);

        // 斑馬線
        if (gx >= 3 && gx <= 6 && gy == 4) {
          _drawDiamondStripe(canvas, p, Colors.white30);
        }
      }
    }

    // 街角老公寓大門立體建物 (gx: 2, gy: 0)
    _drawBuildingBlock(canvas, _iso(2.0, 0.5, ox, oy), 80, 110, const Color(0xFF7F1D1D), const Color(0xFF991B1B), '🏠 出租套房');

    // CITY MART 超商立體門面 (gx: 7, gy: 0)
    _drawBuildingBlock(canvas, _iso(7.0, 0.5, ox, oy), 90, 120, const Color(0xFF0F172A), const Color(0xFF1E293B), '🏪 CITY MART');

    // 黃色計程車 (gx: 5, gy: 7)
    _drawTaxi(canvas, _iso(5.0, 7.0, ox, oy));

    // 暖黃路燈光暈
    _drawStreetLamp(canvas, _iso(1.0, 4.0, ox, oy));
    _drawStreetLamp(canvas, _iso(8.0, 4.0, ox, oy));
  }

  // --- 空間 2: 出租套房室內 (Apartment) ---
  void _paintApartment(Canvas canvas, double ox, double oy) {
    const size = 7;

    // 木紋地板網格
    for (int gy = 0; gy < size; gy++) {
      for (int gx = 0; gx < size; gx++) {
        final p = _iso(gx.toDouble(), gy.toDouble(), ox, oy);
        final woodColor = ((gx + gy) % 2 == 0) ? const Color(0xFF78350F) : const Color(0xFF92400E);
        _drawDiamondTile(canvas, p, woodColor, const Color(0xFF451A03));
      }
    }

    // 牆面立體邊緣 (後牆與左牆)
    _drawRoomWalls(canvas, ox, oy, size, const Color(0xFF3F3F46), const Color(0xFF27272A));

    // 立體折疊床 (gx: 4.0, gy: 2.0)
    _drawIsometricBed(canvas, _iso(4.0, 2.0, ox, oy));

    // 小冰箱 (gx: 1.5, gy: 1.5)
    _drawIsometricFridge(canvas, _iso(1.5, 1.5, ox, oy));

    // 鑰匙迎賓地墊 (gx: 3.0, gy: 5.0)
    _drawDoormat(canvas, _iso(3.0, 5.0, ox, oy));
  }

  // --- 空間 3: CITY MART 超商內部 (Store) ---
  void _paintStore(Canvas canvas, double ox, double oy) {
    const size = 8;

    // 拋光白色磁磚地
    for (int gy = 0; gy < size; gy++) {
      for (int gx = 0; gx < size; gx++) {
        final p = _iso(gx.toDouble(), gy.toDouble(), ox, oy);
        final tileColor = ((gx + gy) % 2 == 0) ? const Color(0xFFF1F5F9) : const Color(0xFFE2E8F0);
        _drawDiamondTile(canvas, p, tileColor, Colors.black12);
      }
    }

    // 超商牆面與藍橘裝飾線
    _drawRoomWalls(canvas, ox, oy, size, const Color(0xFF1E293B), const Color(0xFF0F172A));

    // 立體收銀櫃台與 POS 機 (gx: 5.0, gy: 2.5)
    _drawIsometricCounter(canvas, _iso(5.0, 2.5, ox, oy));

    // 雙門冷藏飲料展示櫃 (gx: 1.5, gy: 1.5)
    _drawIsometricCooler(canvas, _iso(1.5, 1.5, ox, oy));

    // 三層零食陳列島架 (gx: 3.5, gy: 3.0)
    _drawIsometricShelf(canvas, _iso(3.5, 3.0, ox, oy));

    // 進貨紙箱棧板 (gx: 1.5, gy: 5.0)
    _drawIsometricPallet(canvas, _iso(1.5, 5.0, ox, oy));
  }

  // --- 繪圖幾何輔助函式 ---

  void _drawDiamondTile(Canvas canvas, Offset p, Color fill, Color border) {
    final path = Path()
      ..moveTo(p.dx, p.dy - tileH / 2)
      ..lineTo(p.dx + tileW / 2, p.dy)
      ..lineTo(p.dx, p.dy + tileH / 2)
      ..lineTo(p.dx - tileW / 2, p.dy)
      ..close();

    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(path, Paint()..color = border..style = PaintingStyle.stroke..strokeWidth = 1.0);
  }

  void _drawDiamondStripe(Canvas canvas, Offset p, Color col) {
    final path = Path()
      ..moveTo(p.dx, p.dy - tileH / 4)
      ..lineTo(p.dx + tileW / 4, p.dy)
      ..lineTo(p.dx, p.dy + tileH / 4)
      ..lineTo(p.dx - tileW / 4, p.dy)
      ..close();
    canvas.drawPath(path, Paint()..color = col);
  }

  void _drawBuildingBlock(Canvas canvas, Offset p, double width, double height, Color leftCol, Color rightCol, String label) {
    // 頂面
    final topPath = Path()
      ..moveTo(p.dx, p.dy - height - tileH / 2)
      ..lineTo(p.dx + width / 2, p.dy - height)
      ..lineTo(p.dx, p.dy - height + tileH / 2)
      ..lineTo(p.dx - width / 2, p.dy - height)
      ..close();
    canvas.drawPath(topPath, Paint()..color = rightCol.withValues(alpha: 0.9));

    // 左側面
    final leftPath = Path()
      ..moveTo(p.dx - width / 2, p.dy - height)
      ..lineTo(p.dx, p.dy - height + tileH / 2)
      ..lineTo(p.dx, p.dy + tileH / 2)
      ..lineTo(p.dx - width / 2, p.dy)
      ..close();
    canvas.drawPath(leftPath, Paint()..color = leftCol);

    // 右側面
    final rightPath = Path()
      ..moveTo(p.dx, p.dy - height + tileH / 2)
      ..lineTo(p.dx + width / 2, p.dy - height)
      ..lineTo(p.dx + width / 2, p.dy)
      ..lineTo(p.dx, p.dy + tileH / 2)
      ..close();
    canvas.drawPath(rightPath, Paint()..color = rightCol);

    // 招牌文字
    final tp = TextPainter(
      text: TextSpan(text: label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(p.dx - tp.width / 2, p.dy - height + 10));
  }

  void _drawRoomWalls(Canvas canvas, double ox, double oy, int size, Color col1, Color col2) {
    // 房間後牆高 80px
    final leftCorner = _iso(0, 0, ox, oy);
    final backRight = _iso(size.toDouble(), 0, ox, oy);
    final frontLeft = _iso(0, size.toDouble(), ox, oy);

    final leftWall = Path()
      ..moveTo(frontLeft.dx, frontLeft.dy)
      ..lineTo(leftCorner.dx, leftCorner.dy)
      ..lineTo(leftCorner.dx, leftCorner.dy - 75)
      ..lineTo(frontLeft.dx, frontLeft.dy - 75)
      ..close();
    canvas.drawPath(leftWall, Paint()..color = col1);

    final rightWall = Path()
      ..moveTo(leftCorner.dx, leftCorner.dy)
      ..lineTo(backRight.dx, backRight.dy)
      ..lineTo(backRight.dx, backRight.dy - 75)
      ..lineTo(leftCorner.dx, leftCorner.dy - 75)
      ..close();
    canvas.drawPath(rightWall, Paint()..color = col2);
  }

  void _drawIsometricBed(Canvas canvas, Offset p) {
    // 床框 (3D 藍色折疊床)
    _draw3DBox(canvas, p, 48, 70, 20, const Color(0xFF0369A1), const Color(0xFF0284C7), const Color(0xFF38BDF8));
    // 白色枕頭
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(p.dx, p.dy - 22), width: 24, height: 12), const Radius.circular(3)),
      Paint()..color = Colors.white,
    );
  }

  void _drawIsometricFridge(Canvas canvas, Offset p) {
    // 小冰箱 (銀灰金屬)
    _draw3DBox(canvas, p, 32, 32, 50, const Color(0xFF475569), const Color(0xFF64748B), const Color(0xFF94A3B8));
  }

  void _drawDoormat(Canvas canvas, Offset p) {
    // 綠色 Welcome 踏墊
    _drawDiamondTile(canvas, p, const Color(0xFF15803D), const Color(0xFF166534));
  }

  void _drawIsometricCounter(Canvas canvas, Offset p) {
    // 木質收銀櫃台
    _draw3DBox(canvas, p, 50, 36, 32, const Color(0xFF78350F), const Color(0xFF92400E), const Color(0xFFB45309));
    // POS 機藍色亮屏
    canvas.drawRect(Rect.fromLTWH(p.dx - 8, p.dy - 45, 16, 12), Paint()..color = const Color(0xFF38BDF8));
  }

  void _drawIsometricCooler(Canvas canvas, Offset p) {
    // 雙門冷藏櫃 (冰藍透光)
    _draw3DBox(canvas, p, 44, 30, 65, const Color(0xFF1E3A8A), const Color(0xFF1D4ED8), const Color(0xFF60A5FA));
  }

  void _drawIsometricShelf(Canvas canvas, Offset p) {
    // 零食三層架 (橘金)
    _draw3DBox(canvas, p, 50, 28, 42, const Color(0xFFC2410C), const Color(0xFFEA580C), const Color(0xFFFB923C));
  }

  void _drawIsometricPallet(Canvas canvas, Offset p) {
    // 木棧板
    _draw3DBox(canvas, p, 44, 44, 8, const Color(0xFF78350F), const Color(0xFF92400E), const Color(0xFFB45309));
    // 堆疊的紙箱
    _draw3DBox(canvas, Offset(p.dx, p.dy - 8), 30, 30, 24, const Color(0xFFB45309), const Color(0xFFD97706), const Color(0xFFF59E0B));
  }

  void _drawTaxi(Canvas canvas, Offset p) {
    // 黃色計程車
    _draw3DBox(canvas, p, 44, 28, 20, const Color(0xFFCA8A04), const Color(0xFFEAB308), const Color(0xFFFDE047));
    // 車頂 Taxi 燈
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(p.dx, p.dy - 24), width: 14, height: 6), const Radius.circular(2)),
      Paint()..color = Colors.white,
    );
  }

  void _drawStreetLamp(Canvas canvas, Offset p) {
    // 燈柱
    canvas.drawLine(p, Offset(p.dx, p.dy - 55), Paint()..color = const Color(0xFF475569)..strokeWidth = 3);
    // 暖黃光暈
    canvas.drawCircle(Offset(p.dx, p.dy - 55), 14, Paint()..color = const Color(0xFFFDE047).withValues(alpha: 0.35));
    canvas.drawCircle(Offset(p.dx, p.dy - 55), 5, Paint()..color = Colors.white);
  }

  void _draw3DBox(Canvas canvas, Offset p, double w, double h, double z, Color leftCol, Color rightCol, Color topCol) {
    final topP = Offset(p.dx, p.dy - z);

    // 頂面
    final topPath = Path()
      ..moveTo(topP.dx, topP.dy - h / 4)
      ..lineTo(topP.dx + w / 2, topP.dy)
      ..lineTo(topP.dx, topP.dy + h / 4)
      ..lineTo(topP.dx - w / 2, topP.dy)
      ..close();
    canvas.drawPath(topPath, Paint()..color = topCol);

    // 左側面
    final leftPath = Path()
      ..moveTo(topP.dx - w / 2, topP.dy)
      ..lineTo(topP.dx, topP.dy + h / 4)
      ..lineTo(p.dx, p.dy + h / 4)
      ..lineTo(p.dx - w / 2, p.dy)
      ..close();
    canvas.drawPath(leftPath, Paint()..color = leftCol);

    // 右側面
    final rightPath = Path()
      ..moveTo(topP.dx, topP.dy + h / 4)
      ..lineTo(topP.dx + w / 2, topP.dy)
      ..lineTo(p.dx + w / 2, p.dy)
      ..lineTo(p.dx, p.dy + h / 4)
      ..close();
    canvas.drawPath(rightPath, Paint()..color = rightCol);
  }

  // --- 2.5D 主角渲染 ---
  void _paintPlayer(Canvas canvas, double ox, double oy) {
    final p = _iso(playerGx, playerGy, ox, oy);

    // 腳下真實橢圓投影陰影
    canvas.drawOval(
      Rect.fromCenter(center: Offset(p.dx, p.dy + 4), width: 24, height: 10),
      Paint()..color = Colors.black45,
    );

    // 邁步動畫偏移 (Bobbing & Leg swing)
    final legSwing = isMoving ? math.sin(walkCycle) * 4.0 : 0.0;
    final bobbing = isMoving ? (math.cos(walkCycle * 2) * 1.5).abs() : 0.0;

    final bodyY = p.dy - 22 - bobbing;

    // 雙腿
    final legPaint = Paint()..color = const Color(0xFF1E293B)..strokeWidth = 3.5..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(p.dx - 3, p.dy - 12), Offset(p.dx - 3 - legSwing, p.dy), legPaint);
    canvas.drawLine(Offset(p.dx + 3, p.dy - 12), Offset(p.dx + 3 + legSwing, p.dy), legPaint);

    // 軀幹 (穿著風衣外套)
    final bodyPaint = Paint()..color = const Color(0xFFB45309);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(p.dx - 7, bodyY - 14, 14, 18), const Radius.circular(4)),
      bodyPaint,
    );

    // 頭部
    canvas.drawCircle(Offset(p.dx, bodyY - 22), 7, Paint()..color = const Color(0xFFFED7AA));
    // 頭髮
    canvas.drawArc(
      Rect.fromCircle(center: Offset(p.dx, bodyY - 23), radius: 7),
      math.pi,
      math.pi,
      true,
      Paint()..color = const Color(0xFF451A03),
    );

    // 五官朝向小黑點
    final eyeOffsetX = math.cos(facingAngle) * 3.0;
    final eyeOffsetY = math.sin(facingAngle) * 2.0;
    canvas.drawCircle(Offset(p.dx + eyeOffsetX, bodyY - 22 + eyeOffsetY), 1.2, Paint()..color = Colors.black87);

    // 手持物狀態
    if (carryState == PlayerCarryState.suitcase) {
      // 右手提咖啡色旅行皮箱 (隨行走前後擺動)
      final caseSwing = math.sin(walkCycle) * 3.0;
      final caseP = Offset(p.dx + 11, bodyY - 4 + caseSwing);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: caseP, width: 14, height: 10), const Radius.circular(2)),
        Paint()..color = const Color(0xFF78350F),
      );
      // 金屬提把
      canvas.drawLine(Offset(caseP.dx - 4, caseP.dy - 5), Offset(caseP.dx + 4, caseP.dy - 5), Paint()..color = const Color(0xFFFBBF24)..strokeWidth = 1.5);
    } else if (carryState == PlayerCarryState.box) {
      // 雙手高舉 2.5D 紙箱
      final boxP = Offset(p.dx, bodyY - 38);
      _draw3DBox(canvas, boxP, 22, 22, 16, const Color(0xFFB45309), const Color(0xFFD97706), const Color(0xFFFBBF24));
    }
  }

  @override
  bool shouldRepaint(covariant _IsometricWorldPainter oldDelegate) => true;
}
