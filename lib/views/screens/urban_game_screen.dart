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

class _ClickRipple {
  final double gx;
  final double gy;
  double progress; // 0.0 ~ 1.0
  final Color color;

  _ClickRipple({
    required this.gx,
    required this.gy,
    this.color = const Color(0xFF38BDF8),
  }) : progress = 0.0;
}

enum _SmartInteractType {
  apartmentDoor,
  storeDoor,
  taxi,
  bed,
  apartmentExit,
  pallet,
  shelf,
  counter,
  storeExit,
}

class _SmartInteractTarget {
  final _SmartInteractType type;
  final Offset walkTarget;
  final double interactRadius;
  final VoidCallback action;
  final Color rippleColor;

  const _SmartInteractTarget({
    required this.type,
    required this.walkTarget,
    required this.interactRadius,
    required this.action,
    required this.rippleColor,
  });
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

  // 點擊移動 (Click-to-Move) 與智慧互動 (Smart Tap-to-Interact)
  Offset? _targetGridPos;
  _SmartInteractTarget? _pendingSmartTarget;
  final List<_ClickRipple> _ripples = [];
  int _lastStepPhase = 0;

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

  static Offset _iso(double gx, double gy, double originX, double originY) {
    final x = originX + (gx - gy) * (_IsometricWorldPainter.tileW / 2);
    final y = originY + (gx + gy) * (_IsometricWorldPainter.tileH / 2);
    return Offset(x, y);
  }

  Offset? _screenToIsoGrid(Offset screenPos, Size size) {
    final originX = size.width / 2;
    double originY = size.height * 0.16;
    if (_currentRoom == GameRoom.apartment) {
      originY = size.height * 0.22;
    } else if (_currentRoom == GameRoom.store) {
      originY = size.height * 0.18;
    }
    final dx = (screenPos.dx - originX) / (_IsometricWorldPainter.tileW / 2);
    final dy = (screenPos.dy - originY) / (_IsometricWorldPainter.tileH / 2);
    final gx = (dx + dy) / 2;
    final gy = (dy - dx) / 2;
    return Offset(gx, gy);
  }

  double _quantizeTo8Directions(double angle) {
    const step = math.pi / 4;
    return (angle / step).round() * step;
  }

  void _checkFootstepAudio() {
    final phase = (_walkCycle / math.pi).floor();
    if (phase != _lastStepPhase) {
      _lastStepPhase = phase;
      AudioService().playFootstep();
    }
  }

  void _onGameTick(Duration elapsed) {
    if (!mounted) return;

    // 1. 鍵盤輸入 (WASD / 方向鍵作為桌面快捷操作)
    double inputX = 0.0;
    double inputY = 0.0;

    if (_pressedKeys.contains(LogicalKeyboardKey.keyW) || _pressedKeys.contains(LogicalKeyboardKey.arrowUp)) inputY -= 1.0;
    if (_pressedKeys.contains(LogicalKeyboardKey.keyS) || _pressedKeys.contains(LogicalKeyboardKey.arrowDown)) inputY += 1.0;
    if (_pressedKeys.contains(LogicalKeyboardKey.keyA) || _pressedKeys.contains(LogicalKeyboardKey.arrowLeft)) inputX -= 1.0;
    if (_pressedKeys.contains(LogicalKeyboardKey.keyD) || _pressedKeys.contains(LogicalKeyboardKey.arrowRight)) inputX += 1.0;

    final keyboardMag = math.sqrt(inputX * inputX + inputY * inputY);

    if (keyboardMag > 0.05) {
      // 鍵盤操控即刻取消自動尋路
      _targetGridPos = null;
      _pendingSmartTarget = null;
      _isMoving = true;

      final normX = inputX / (keyboardMag > 1.0 ? keyboardMag : 1.0);
      final normY = inputY / (keyboardMag > 1.0 ? keyboardMag : 1.0);
      final speed = _pressedKeys.contains(LogicalKeyboardKey.shiftLeft) ? 0.08 : 0.055;

      final nextGx = _gx + normX * speed;
      final nextGy = _gy + normY * speed;

      final bounds = _getRoomBounds(_currentRoom);
      if (nextGx >= bounds.left && nextGx <= bounds.right) _gx = nextGx;
      if (nextGy >= bounds.top && nextGy <= bounds.bottom) _gy = nextGy;

      _facingAngle = _quantizeTo8Directions(math.atan2(normY, normX));
      _walkCycle += 0.25;
      _checkFootstepAudio();
    } else if (_targetGridPos != null) {
      // 2. 點擊移動平滑步進尋路 (Click-to-Move Smooth Stepping)
      final dx = _targetGridPos!.dx - _gx;
      final dy = _targetGridPos!.dy - _gy;
      final dist = math.sqrt(dx * dx + dy * dy);

      // 檢查是否已抵達智慧互動目標之有效互動半徑
      if (_pendingSmartTarget != null && dist <= _pendingSmartTarget!.interactRadius) {
        _isMoving = false;
        _targetGridPos = null;
        final action = _pendingSmartTarget!.action;
        _pendingSmartTarget = null;
        action();
      } else if (dist > 0.06) {
        _isMoving = true;
        final normX = dx / dist;
        final normY = dy / dist;
        final speed = _pressedKeys.contains(LogicalKeyboardKey.shiftLeft) ? 0.08 : 0.055;
        final step = math.min(speed, dist);

        final nextGx = _gx + normX * step;
        final nextGy = _gy + normY * step;
        final bounds = _getRoomBounds(_currentRoom);
        final clampedGx = nextGx.clamp(bounds.left, bounds.right);
        final clampedGy = nextGy.clamp(bounds.top, bounds.bottom);

        // 若撞邊界受阻且已接近目標
        if ((clampedGx - _gx).abs() < 0.001 && (clampedGy - _gy).abs() < 0.001 && dist < 0.2) {
          _targetGridPos = null;
          _isMoving = false;
          if (_pendingSmartTarget != null) {
            final action = _pendingSmartTarget!.action;
            _pendingSmartTarget = null;
            action();
          }
        } else {
          _gx = clampedGx;
          _gy = clampedGy;
        }

        _facingAngle = _quantizeTo8Directions(math.atan2(normY, normX));
        _walkCycle += 0.25;
        _checkFootstepAudio();
      } else {
        // 精確抵達目標點
        _gx = _targetGridPos!.dx;
        _gy = _targetGridPos!.dy;
        _targetGridPos = null;
        _isMoving = false;
        if (_pendingSmartTarget != null) {
          final action = _pendingSmartTarget!.action;
          _pendingSmartTarget = null;
          action();
        }
      }
    } else {
      _isMoving = false;
    }

    // 3. 更新動態水波光圈動畫進度
    for (final r in _ripples) {
      r.progress += 0.045;
    }
    _ripples.removeWhere((r) => r.progress >= 1.0);

    // 4. 檢測可互動實體 (Contextual Action Detection)
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

  void _handleScreenTap(Offset screenPos, Size size) {
    final gridPos = _screenToIsoGrid(screenPos, size);
    if (gridPos == null) return;

    final originX = size.width / 2;
    double originY = size.height * 0.16;
    if (_currentRoom == GameRoom.apartment) {
      originY = size.height * 0.22;
    } else if (_currentRoom == GameRoom.store) {
      originY = size.height * 0.18;
    }

    final smartTarget = _findInteractableAt(screenPos, gridPos, originX, originY);
    if (smartTarget != null) {
      _triggerSmartInteract(smartTarget);
    } else {
      // 點擊地面：自動巡航尋路
      _pendingSmartTarget = null;
      final bounds = _getRoomBounds(_currentRoom);
      final clampedGx = gridPos.dx.clamp(bounds.left, bounds.right);
      final clampedGy = gridPos.dy.clamp(bounds.top, bounds.bottom);
      _targetGridPos = Offset(clampedGx, clampedGy);

      // 動態擴散霓虹淡藍水波環
      _ripples.add(_ClickRipple(
        gx: clampedGx,
        gy: clampedGy,
        color: const Color(0xFF38BDF8),
      ));
      AudioService().playScanBeep();
    }
  }

  void _triggerSmartInteract(_SmartInteractTarget target) {
    final currentDist = _dist(_gx, _gy, target.walkTarget.dx, target.walkTarget.dy);

    // 激發點擊目標水波光圈
    _ripples.add(_ClickRipple(
      gx: target.walkTarget.dx,
      gy: target.walkTarget.dy,
      color: target.rippleColor,
    ));
    AudioService().playScanBeep();

    if (currentDist <= target.interactRadius) {
      // 角色已在有效互動範圍內，直接轉向並執行
      final dx = target.walkTarget.dx - _gx;
      final dy = target.walkTarget.dy - _gy;
      if (dx != 0 || dy != 0) {
        _facingAngle = _quantizeTo8Directions(math.atan2(dy, dx));
      }
      _targetGridPos = null;
      _pendingSmartTarget = null;
      _isMoving = false;
      target.action();
    } else {
      // 自動巡航前往目標點
      _targetGridPos = target.walkTarget;
      _pendingSmartTarget = target;
    }
  }

  _SmartInteractTarget? _findInteractableAt(Offset screenPos, Offset gridPos, double ox, double oy) {
    if (_currentRoom == GameRoom.street) {
      // 1. 公寓大門 / 建築體 (gx: 2.0, gy: 0.5 ~ 1.5)
      final aptBase = _iso(2.0, 0.5, ox, oy);
      final aptRect = Rect.fromLTWH(aptBase.dx - 50, aptBase.dy - 120, 100, 130);
      if (aptRect.contains(screenPos) || (gridPos.dx >= 0.6 && gridPos.dx <= 3.4 && gridPos.dy >= 0.0 && gridPos.dy <= 2.2)) {
        return _SmartInteractTarget(
          type: _SmartInteractType.apartmentDoor,
          walkTarget: const Offset(2.0, 1.5),
          interactRadius: 1.2,
          action: () => _transitionToRoom(GameRoom.apartment),
          rippleColor: const Color(0xFF38BDF8),
        );
      }

      // 2. 超商大門 / 建築體 (gx: 7.0, gy: 0.5 ~ 1.5)
      final storeBase = _iso(7.0, 0.5, ox, oy);
      final storeRect = Rect.fromLTWH(storeBase.dx - 55, storeBase.dy - 130, 110, 140);
      if (storeRect.contains(screenPos) || (gridPos.dx >= 5.6 && gridPos.dx <= 8.4 && gridPos.dy >= 0.0 && gridPos.dy <= 2.2)) {
        return _SmartInteractTarget(
          type: _SmartInteractType.storeDoor,
          walkTarget: const Offset(7.0, 1.5),
          interactRadius: 1.2,
          action: () => _transitionToRoom(GameRoom.store),
          rippleColor: const Color(0xFFF97316),
        );
      }

      // 3. 計程車 (gx: 5.0, gy: 7.0)
      final taxiBase = _iso(5.0, 7.0, ox, oy);
      final taxiRect = Rect.fromLTWH(taxiBase.dx - 35, taxiBase.dy - 35, 70, 50);
      if (taxiRect.contains(screenPos) || _dist(gridPos.dx, gridPos.dy, 5.0, 7.0) < 1.4) {
        return _SmartInteractTarget(
          type: _SmartInteractType.taxi,
          walkTarget: const Offset(5.0, 6.8),
          interactRadius: 1.4,
          action: _showTaxiDialog,
          rippleColor: const Color(0xFFFACC15),
        );
      }
    } else if (_currentRoom == GameRoom.apartment) {
      // 1. 折疊床 (gx: 4.0, gy: 2.0)
      final bedBase = _iso(4.0, 2.0, ox, oy);
      final bedRect = Rect.fromLTWH(bedBase.dx - 35, bedBase.dy - 40, 70, 55);
      if (bedRect.contains(screenPos) || _dist(gridPos.dx, gridPos.dy, 4.0, 2.0) < 1.4) {
        return _SmartInteractTarget(
          type: _SmartInteractType.bed,
          walkTarget: const Offset(3.6, 2.0),
          interactRadius: 1.3,
          action: _sleepInBedAction,
          rippleColor: const Color(0xFF38BDF8),
        );
      }

      // 2. 套房出口 / 迎賓地墊 (gx: 3.0, gy: 5.0 ~ 5.5)
      final doorBase = _iso(3.0, 5.0, ox, oy);
      final doorRect = Rect.fromLTWH(doorBase.dx - 35, doorBase.dy - 25, 70, 45);
      if (doorRect.contains(screenPos) || _dist(gridPos.dx, gridPos.dy, 3.0, 5.2) < 1.3 || (gridPos.dx >= 2.2 && gridPos.dx <= 3.8 && gridPos.dy >= 4.5 && gridPos.dy <= 6.0)) {
        return _SmartInteractTarget(
          type: _SmartInteractType.apartmentExit,
          walkTarget: const Offset(3.0, 5.2),
          interactRadius: 1.2,
          action: () => _transitionToRoom(GameRoom.street),
          rippleColor: Colors.white70,
        );
      }
    } else if (_currentRoom == GameRoom.store) {
      // 1. 進貨棧板紙箱 (gx: 1.8, gy: 5.0)
      final palletBase = _iso(1.5, 5.0, ox, oy);
      final palletRect = Rect.fromLTWH(palletBase.dx - 30, palletBase.dy - 40, 60, 55);
      if (palletRect.contains(screenPos) || _dist(gridPos.dx, gridPos.dy, 1.8, 5.0) < 1.3) {
        return _SmartInteractTarget(
          type: _SmartInteractType.pallet,
          walkTarget: const Offset(1.8, 5.0),
          interactRadius: 1.3,
          action: _palletAction,
          rippleColor: const Color(0xFFD97706),
        );
      }

      // 2. 商品貨架 (gx: 3.5, gy: 3.2)
      final shelfBase = _iso(3.5, 3.0, ox, oy);
      final shelfRect = Rect.fromLTWH(shelfBase.dx - 35, shelfBase.dy - 50, 70, 65);
      if (shelfRect.contains(screenPos) || _dist(gridPos.dx, gridPos.dy, 3.5, 3.2) < 1.4) {
        return _SmartInteractTarget(
          type: _SmartInteractType.shelf,
          walkTarget: const Offset(3.5, 3.2),
          interactRadius: 1.4,
          action: _shelfAction,
          rippleColor: const Color(0xFF10B981),
        );
      }

      // 3. 收銀櫃台 (gx: 5.0, gy: 2.8)
      final counterBase = _iso(5.0, 2.5, ox, oy);
      final counterRect = Rect.fromLTWH(counterBase.dx - 35, counterBase.dy - 50, 70, 65);
      if (counterRect.contains(screenPos) || _dist(gridPos.dx, gridPos.dy, 5.0, 2.8) < 1.4) {
        return _SmartInteractTarget(
          type: _SmartInteractType.counter,
          walkTarget: const Offset(5.0, 2.8),
          interactRadius: 1.4,
          action: _counterAction,
          rippleColor: const Color(0xFFFBBF24),
        );
      }

      // 4. 超商出口 (gx: 4.0, gy: 6.5)
      final exitBase = _iso(4.0, 6.5, ox, oy);
      final exitRect = Rect.fromLTWH(exitBase.dx - 35, exitBase.dy - 25, 70, 45);
      if (exitRect.contains(screenPos) || _dist(gridPos.dx, gridPos.dy, 4.0, 6.2) < 1.3 || (gridPos.dx >= 3.0 && gridPos.dx <= 5.0 && gridPos.dy >= 5.5 && gridPos.dy <= 7.0)) {
        return _SmartInteractTarget(
          type: _SmartInteractType.storeExit,
          walkTarget: const Offset(4.0, 6.2),
          interactRadius: 1.2,
          action: () => _transitionToRoom(GameRoom.street),
          rippleColor: Colors.white70,
        );
      }
    }
    return null;
  }

  void _palletAction() {
    if (_carryState != PlayerCarryState.box) {
      _carryState = PlayerCarryState.box;
      AudioService().playRestock();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFFD97706),
          content: Text('📦 抱起了滿箱的零食！請走到中間貨架前拆箱補貨。'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _shelfAction() {
    if (_carryState == PlayerCarryState.box) {
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
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF64748B),
          content: Text('📦 請先到左下進貨棧板抱起補貨紙箱！'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _counterAction() {
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
      _targetGridPos = null;
      _pendingSmartTarget = null;
      _ripples.clear();
      _setInitialPlayerPosForRoom(target);
    });
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
        _onActiveAction = _palletAction;
        return;
      }

      // 靠近商品貨架 (gx: 3.5, gy: 3.2)
      final distShelf = _dist(_gx, _gy, 3.5, 3.2);
      if (distShelf < 1.4 && _carryState == PlayerCarryState.box) {
        _activeActionLabel = '拆箱上架補貨';
        _activeActionIcon = Icons.shopping_cart_rounded;
        _activeActionColor = const Color(0xFF10B981);
        _onActiveAction = _shelfAction;
        return;
      }

      // 靠近收銀櫃台 (gx: 5.0, gy: 2.8)
      final distCounter = _dist(_gx, _gy, 5.0, 2.8);
      if (distCounter < 1.4) {
        _activeActionLabel = '收銀台打工結帳';
        _activeActionIcon = Icons.point_of_sale_rounded;
        _activeActionColor = const Color(0xFFFBBF24);
        _onActiveAction = _counterAction;
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
                        // 1. 2.5D Isometric 核心空間畫布 (包覆 GestureDetector 接收點擊移動與物件互動)
                        Positioned.fill(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTapDown: (details) => _handleScreenTap(details.localPosition, Size(screenW, screenH)),
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
                                ripples: _ripples,
                                targetPos: _targetGridPos,
                              ),
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

                        // 4. 右下角情境動作按鈕 (Contextual Action Button)
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
  final List<_ClickRipple> ripples;
  final Offset? targetPos;

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
    this.ripples = const [],
    this.targetPos,
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

    // 繪製點擊水波光圈與目標導引游標 (Click Ripple & Target Reticle)
    _paintRipplesAndTarget(canvas, originX, originY);

    // 繪製 2.5D 主角模型
    _paintPlayer(canvas, originX, originY);
  }

  void _paintRipplesAndTarget(Canvas canvas, double ox, double oy) {
    // 1. 移動目標點的霓虹導引游標 (Target Reticle)
    if (targetPos != null) {
      final destP = _iso(targetPos!.dx, targetPos!.dy, ox, oy);
      final pulse = 0.55 + 0.35 * (math.sin(walkCycle * 2.5).abs());

      // 外層等角菱形瞄準框
      final diamondPath = Path()
        ..moveTo(destP.dx, destP.dy - 8)
        ..lineTo(destP.dx + 16, destP.dy)
        ..lineTo(destP.dx, destP.dy + 8)
        ..lineTo(destP.dx - 16, destP.dy)
        ..close();

      canvas.drawPath(
        diamondPath,
        Paint()
          ..color = const Color(0xFF38BDF8).withValues(alpha: pulse)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );

      // 菱形四角瞄準刻度線
      final tickPaint = Paint()
        ..color = Colors.white.withValues(alpha: pulse)
        ..strokeWidth = 1.5;
      canvas.drawLine(Offset(destP.dx - 18, destP.dy), Offset(destP.dx - 12, destP.dy), tickPaint);
      canvas.drawLine(Offset(destP.dx + 12, destP.dy), Offset(destP.dx + 18, destP.dy), tickPaint);
      canvas.drawLine(Offset(destP.dx, destP.dy - 10), Offset(destP.dx, destP.dy - 6), tickPaint);
      canvas.drawLine(Offset(destP.dx, destP.dy + 6), Offset(destP.dx, destP.dy + 10), tickPaint);

      // 中心發光指示橢圓
      canvas.drawOval(
        Rect.fromCenter(center: destP, width: 8, height: 4),
        Paint()..color = const Color(0xFF38BDF8).withValues(alpha: pulse * 0.85),
      );
    }

    // 2. 動態向外擴散淡出的霓虹水波環 (Click Ripple)
    for (final ripple in ripples) {
      final p = _iso(ripple.gx, ripple.gy, ox, oy);
      final prog = ripple.progress.clamp(0.0, 1.0);
      final alpha = (1.0 - prog);
      final r = 6.0 + prog * 36.0;

      // 主水波環 (符合 2:1 等角投影之橢圓)
      final ovalRect = Rect.fromCenter(center: p, width: r * 2.0, height: r);
      canvas.drawOval(
        ovalRect,
        Paint()
          ..color = ripple.color.withValues(alpha: (alpha * 0.9).clamp(0.0, 1.0))
          ..style = PaintingStyle.stroke
          ..strokeWidth = (2.4 * (1.0 - prog * 0.6)).clamp(0.5, 3.0),
      );

      // 次層內回音波紋
      if (prog > 0.15) {
        final prog2 = (prog - 0.15) / 0.85;
        final r2 = 3.0 + prog2 * 26.0;
        final alpha2 = (1.0 - prog2) * 0.6;
        final ovalRect2 = Rect.fromCenter(center: p, width: r2 * 2.0, height: r2);
        canvas.drawOval(
          ovalRect2,
          Paint()
            ..color = ripple.color.withValues(alpha: (alpha2 * 0.8).clamp(0.0, 1.0))
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6 * (1.0 - prog2 * 0.5),
        );
      }

      // 點擊瞬間的中心高亮白光
      if (prog < 0.35) {
        final flashAlpha = (1.0 - prog / 0.35);
        canvas.drawOval(
          Rect.fromCenter(center: p, width: 8.0 * (1.0 - prog), height: 4.0 * (1.0 - prog)),
          Paint()..color = Colors.white.withValues(alpha: (flashAlpha * 0.85).clamp(0.0, 1.0)),
        );
      }
    }
  }

  // ============================================================================
  // 空間 1: 幸福里街道 (Street Diorama)
  // ============================================================================
  void _paintStreet(Canvas canvas, double ox, double oy) {
    const cols = 10;
    const rows = 10;

    // --- 1. 地面與人行道基底 (含 3D 道緣石 Curb 立體高度差) ---
    // 先畫車道與人行道水平地面
    for (int gy = 0; gy < rows; gy++) {
      for (int gx = 0; gx < cols; gx++) {
        final p = _iso(gx.toDouble(), gy.toDouble(), ox, oy);
        final isSidewalk = (gy <= 2) || (gx <= 1);

        if (isSidewalk) {
          // 人行道抬高 4px 立體高度 (z = 4)
          final sidewalkP = Offset(p.dx, p.dy - 4.0);
          final tileColor = ((gx + gy) % 2 == 0) ? const Color(0xFF334155) : const Color(0xFF3B485A);
          _drawDiamondTile(canvas, sidewalkP, tileColor, const Color(0xFF475569));

          // 人行道精細人字拼/方塊防滑磚線條
          final subPaint = Paint()..color = Colors.white.withValues(alpha: 0.05)..strokeWidth = 1.0;
          canvas.drawLine(Offset(sidewalkP.dx - 14, sidewalkP.dy), Offset(sidewalkP.dx, sidewalkP.dy - 7), subPaint);
          canvas.drawLine(Offset(sidewalkP.dx, sidewalkP.dy + 7), Offset(sidewalkP.dx + 14, sidewalkP.dy), subPaint);
        } else {
          // 柏油馬路 (深沉瀝青帶細緻雜色質感)
          final roadColor = ((gx + gy) % 2 == 0) ? const Color(0xFF18202E) : const Color(0xFF1E2838);
          _drawDiamondTile(canvas, p, roadColor, const Color(0xFF0F172A));
        }
      }
    }

    // 繪製 3D 立體道緣石 (Curb Stones) - 連接人行道 (z=4) 與車道 (z=0) 的立體石階面
    _drawStreetCurbs(canvas, ox, oy);

    // --- 2. 街道地面細節：透視斑馬線、雨水倒影水窪、鑄鐵人孔蓋 ---
    // 透視斑馬線 (gx: 3~6, gy: 4)
    for (double gx = 3.1; gx <= 6.3; gx += 0.55) {
      final p1 = _iso(gx, 3.85, ox, oy);
      final p2 = _iso(gx + 0.32, 3.85, ox, oy);
      final p3 = _iso(gx + 0.32, 4.35, ox, oy);
      final p4 = _iso(gx, 4.35, ox, oy);
      final stripePath = Path()
        ..moveTo(p1.dx, p1.dy)
        ..lineTo(p2.dx, p2.dy)
        ..lineTo(p3.dx, p3.dy)
        ..lineTo(p4.dx, p4.dy)
        ..close();
      canvas.drawPath(stripePath, Paint()..color = Colors.white.withValues(alpha: 0.65));
      // 斑馬線微磨損質感
      canvas.drawPath(
        stripePath,
        Paint()
          ..color = const Color(0xFFCBD5E1).withValues(alpha: 0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
      );
    }

    // 柏油路雨水倒影反光水窪 (Rain Puddles)
    _drawRainPuddle(canvas, _iso(3.2, 5.2, ox, oy), 26, 14);
    _drawRainPuddle(canvas, _iso(6.6, 6.2, ox, oy), 32, 16);

    // 金屬鑄鐵人孔蓋 (Manhole Cover)
    _drawManhole(canvas, _iso(4.2, 5.8, ox, oy));

    // --- 3. 路燈與計程車前方地面真實半透明光池 / 光束 (先投射於地面) ---
    // 復古路燈暖黃光池 (Ground Light Pools)
    _drawLampLightPool(canvas, _iso(1.0, 4.0, ox, oy));
    _drawLampLightPool(canvas, _iso(8.0, 4.0, ox, oy));

    // 計程車前方扇形暖白車燈光束 (Headlight Cones)
    _drawTaxiHeadlightBeams(canvas, _iso(5.0, 7.0, ox, oy));

    // --- 4. 深度排序繪製立體微縮建物與環境景物 (Painter's Algorithm) ---
    // 街角出租老公寓 (gx: 2.0, gy: 0.5) - 頂級英倫紅磚多層結構
    _drawApartmentBuilding(canvas, ox, oy);

    // CITY MART 超商雙層旗艦門市 (gx: 7.0, gy: 0.5) - 大面積透光櫥窗、發光霓虹燈箱、二樓板條窗、屋頂 HVAC
    _drawCityMartBuilding(canvas, ox, oy);

    // 低多邊形幾何行道樹 (多面體翠綠樹冠、砌石樹穴)
    _drawLowPolyTree(canvas, _iso(0.8, 2.2, ox, oy));
    _drawLowPolyTree(canvas, _iso(0.8, 7.0, ox, oy));
    _drawLowPolyTree(canvas, _iso(9.0, 2.2, ox, oy));

    // 維多利亞復古黑色鑄鐵路燈 (六角玻璃燈籠、造型燈桿)
    _drawRetroStreetLamp(canvas, _iso(1.0, 4.0, ox, oy));
    _drawRetroStreetLamp(canvas, _iso(8.0, 4.0, ox, oy));

    // 大都會黃色計程車 (Yellow Taxi) (gx: 5.0, gy: 7.0) - 低多邊形轎車、黑白棋盤條紋、4 個車輪、TAXI 燈箱
    _drawYellowTaxi(canvas, _iso(5.0, 7.0, ox, oy));
  }

  // --- 繪製道緣石 (Curb Stones) 立體高度差 ---
  void _drawStreetCurbs(Canvas canvas, double ox, double oy) {
    const curbHeight = 4.0;

    // 沿著 gy = 2.0 (從 gx = 2 到 10) 的橫向道緣石
    for (int gx = 2; gx < 10; gx++) {
      final pLeft = _iso(gx.toDouble(), 2.0, ox, oy);
      final pRight = _iso((gx + 1).toDouble(), 2.0, ox, oy);

      final curbPath = Path()
        ..moveTo(pLeft.dx, pLeft.dy - curbHeight)
        ..lineTo(pRight.dx, pRight.dy - curbHeight)
        ..lineTo(pRight.dx, pRight.dy)
        ..lineTo(pLeft.dx, pLeft.dy)
        ..close();

      canvas.drawPath(curbPath, Paint()..color = const Color(0xFF475569));
      // 石材分界刻線
      canvas.drawLine(Offset(pRight.dx, pRight.dy - curbHeight), Offset(pRight.dx, pRight.dy), Paint()..color = const Color(0xFF1E293B)..strokeWidth = 1.0);
      // 頂部高光邊緣
      canvas.drawLine(Offset(pLeft.dx, pLeft.dy - curbHeight), Offset(pRight.dx, pRight.dy - curbHeight), Paint()..color = const Color(0xFF94A3B8)..strokeWidth = 1.0);
    }

    // 沿著 gx = 1.0 (從 gy = 3 到 10) 的縱向道緣石
    for (int gy = 3; gy < 10; gy++) {
      final pTop = _iso(1.0, gy.toDouble(), ox, oy);
      final pBottom = _iso(1.0, (gy + 1).toDouble(), ox, oy);

      final curbPath = Path()
        ..moveTo(pTop.dx, pTop.dy - curbHeight)
        ..lineTo(pBottom.dx, pBottom.dy - curbHeight)
        ..lineTo(pBottom.dx, pBottom.dy)
        ..lineTo(pTop.dx, pTop.dy)
        ..close();

      canvas.drawPath(curbPath, Paint()..color = const Color(0xFF334155));
      canvas.drawLine(Offset(pBottom.dx, pBottom.dy - curbHeight), Offset(pBottom.dx, pBottom.dy), Paint()..color = const Color(0xFF1E293B)..strokeWidth = 1.0);
      canvas.drawLine(Offset(pTop.dx, pTop.dy - curbHeight), Offset(pBottom.dx, pBottom.dy - curbHeight), Paint()..color = const Color(0xFF64748B)..strokeWidth = 1.0);
    }
  }

  // --- 柏油路雨水倒影反光水窪 (Rain Puddle) ---
  void _drawRainPuddle(Canvas canvas, Offset p, double width, double height) {
    // 橢圓深藍水窪
    final puddleRect = Rect.fromCenter(center: p, width: width, height: height);
    canvas.drawOval(
      puddleRect,
      Paint()..color = const Color(0xFF0F172A).withValues(alpha: 0.85),
    );
    // 水面倒影藍天高光
    canvas.drawOval(
      Rect.fromCenter(center: Offset(p.dx - 2, p.dy - 1), width: width * 0.65, height: height * 0.55),
      Paint()..color = const Color(0xFF38BDF8).withValues(alpha: 0.35),
    );
    // 高光反光點
    canvas.drawOval(
      Rect.fromCenter(center: Offset(p.dx - 3, p.dy - 2), width: width * 0.3, height: height * 0.25),
      Paint()..color = Colors.white.withValues(alpha: 0.5),
    );
  }

  // --- 鑄鐵人孔蓋 (Manhole) ---
  void _drawManhole(Canvas canvas, Offset p) {
    // 依 2:1 等角投影畫圓盤
    canvas.drawOval(Rect.fromCenter(center: p, width: 22, height: 11), Paint()..color = const Color(0xFF0F172A));
    canvas.drawOval(Rect.fromCenter(center: p, width: 18, height: 9), Paint()..color = const Color(0xFF334155));
    canvas.drawOval(
      Rect.fromCenter(center: p, width: 18, height: 9),
      Paint()
        ..color = const Color(0xFF475569)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
    // 人孔蓋同心紋與十字防滑筋
    canvas.drawLine(Offset(p.dx - 5, p.dy), Offset(p.dx + 5, p.dy), Paint()..color = const Color(0xFF1E293B)..strokeWidth = 1.2);
    canvas.drawLine(Offset(p.dx, p.dy - 2.5), Offset(p.dx, p.dy + 2.5), Paint()..color = const Color(0xFF1E293B)..strokeWidth = 1.2);
  }

  // --- 復古路燈地面柔和光池 (Lamp Light Pool) ---
  void _drawLampLightPool(Canvas canvas, Offset p) {
    // 外層微弱暖黃光圈
    canvas.drawOval(
      Rect.fromCenter(center: Offset(p.dx, p.dy + 2), width: 78, height: 39),
      Paint()..color = const Color(0xFFFDE047).withValues(alpha: 0.12),
    );
    // 中層柔和暖金光暈
    canvas.drawOval(
      Rect.fromCenter(center: Offset(p.dx, p.dy + 2), width: 50, height: 25),
      Paint()..color = const Color(0xFFFBBF24).withValues(alpha: 0.22),
    );
    // 核心明亮光核
    canvas.drawOval(
      Rect.fromCenter(center: Offset(p.dx, p.dy + 2), width: 24, height: 12),
      Paint()..color = const Color(0xFFFEF08A).withValues(alpha: 0.38),
    );
  }

  // --- 計程車前方扇形暖白車燈光束 (Headlight Cones) ---
  void _drawTaxiHeadlightBeams(Canvas canvas, Offset taxiP) {
    // 計程車朝向東南 (gx 軸正向，朝右下方)
    // 兩盞大燈向右下方柏油路投射出兩道真實半透明扇形暖白光錐
    final light1Origin = Offset(taxiP.dx + 16, taxiP.dy + 2);
    final light2Origin = Offset(taxiP.dx + 26, taxiP.dy - 3);

    void drawCone(Offset origin, double spread) {
      final conePath = Path()
        ..moveTo(origin.dx, origin.dy)
        ..lineTo(origin.dx + 55, origin.dy + 24 - spread)
        ..lineTo(origin.dx + 65, origin.dy + 34 + spread)
        ..close();

      canvas.drawPath(
        conePath,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFFFFFBEB).withValues(alpha: 0.45),
              const Color(0xFFFEF08A).withValues(alpha: 0.22),
              const Color(0xFFFDE047).withValues(alpha: 0.0),
            ],
            stops: const [0.0, 0.4, 1.0],
          ).createShader(Rect.fromLTWH(origin.dx, origin.dy, 70, 45)),
      );
    }

    drawCone(light1Origin, 6);
    drawCone(light2Origin, 6);
  }

  // ============================================================================
  // 物件 1: 【CITY MART 超商雙層旗艦門市 (gx: 7.0, gy: 0.5)】
  // ============================================================================
  void _drawCityMartBuilding(Canvas canvas, double ox, double oy) {
    final p = _iso(7.0, 0.5, ox, oy);
    const double bWidth = 96.0;
    const double bDepth = 56.0;
    const double bHeight = 138.0;

    // 建物地面柔和陰影
    final shadowPath = Path()
      ..moveTo(p.dx - bWidth / 2 - 10, p.dy + 4)
      ..lineTo(p.dx + bWidth / 2 + 18, p.dy - 8)
      ..lineTo(p.dx + bWidth / 2 + 28, p.dy + 12)
      ..lineTo(p.dx, p.dy + 24)
      ..close();
    canvas.drawPath(shadowPath, Paint()..color = Colors.black.withValues(alpha: 0.45));

    // 1. 建築立體主結構 (右側面、左正面、頂面)
    // 右側面 (面向東南方，深灰冷色現代牆面)
    final rightWall = Path()
      ..moveTo(p.dx, p.dy + 14)
      ..lineTo(p.dx + bWidth / 2, p.dy - 12)
      ..lineTo(p.dx + bWidth / 2, p.dy - 12 - bHeight)
      ..lineTo(p.dx, p.dy + 14 - bHeight)
      ..close();
    canvas.drawPath(rightWall, Paint()..color = const Color(0xFF0F172A));

    // 右側外牆裝飾條紋與檢修直梯 (Service Ladder)
    final ladderX = p.dx + bWidth / 2 - 12;
    final ladderTopY = p.dy - 12 - bHeight + 16;
    final ladderBottomY = p.dy - 12;
    canvas.drawLine(Offset(ladderX - 4, ladderTopY), Offset(ladderX - 4, ladderBottomY), Paint()..color = const Color(0xFF64748B)..strokeWidth = 1.5);
    canvas.drawLine(Offset(ladderX + 4, ladderTopY + 4), Offset(ladderX + 4, ladderBottomY + 4), Paint()..color = const Color(0xFF64748B)..strokeWidth = 1.5);
    for (double ly = ladderTopY + 6; ly < ladderBottomY; ly += 7.0) {
      canvas.drawLine(Offset(ladderX - 4, ly), Offset(ladderX + 4, ly + 4), Paint()..color = const Color(0xFF94A3B8)..strokeWidth = 1.2);
    }

    // 左側面/正面 (面向西南方街景，重要主立面！)
    final leftWall = Path()
      ..moveTo(p.dx - bWidth / 2, p.dy - 12)
      ..lineTo(p.dx, p.dy + 14)
      ..lineTo(p.dx, p.dy + 14 - bHeight)
      ..lineTo(p.dx - bWidth / 2, p.dy - 12 - bHeight)
      ..close();
    canvas.drawPath(leftWall, Paint()..color = const Color(0xFF1E293B));

    // --- 一樓門市：落地大透光玻璃展示櫥窗與室內照明暖黃橘漸層 ---
    const double floor1H = 62.0;
    final windowPath = Path()
      ..moveTo(p.dx - bWidth / 2 + 5, p.dy - 12 + 6)
      ..lineTo(p.dx - 6, p.dy + 14 - 6)
      ..lineTo(p.dx - 6, p.dy + 14 - floor1H + 4)
      ..lineTo(p.dx - bWidth / 2 + 5, p.dy - 12 - floor1H + 16)
      ..close();

    // 落地窗內部暖色室內漸層照明 (半透明米黃/橘暖色)
    final windowGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        const Color(0xFFFEF3C7).withValues(alpha: 0.95), // 溫暖米黃
        const Color(0xFFFDE047).withValues(alpha: 0.85),
        const Color(0xFFF59E0B).withValues(alpha: 0.90), // 橘暖色
      ],
      stops: const [0.0, 0.45, 1.0],
    );
    canvas.drawPath(
      windowPath,
      Paint()..shader = windowGradient.createShader(Rect.fromLTWH(p.dx - bWidth / 2, p.dy - floor1H, bWidth / 2, floor1H)),
    );

    // 窗內隱約勾勒的店內貨架陳列剪影 (Shelf Silhouettes)
    final shelfSilhouettePaint = Paint()..color = const Color(0xFF78350F).withValues(alpha: 0.45);
    canvas.drawRect(Rect.fromLTWH(p.dx - 38, p.dy - 22, 14, 18), shelfSilhouettePaint);
    canvas.drawRect(Rect.fromLTWH(p.dx - 22, p.dy - 16, 12, 16), shelfSilhouettePaint);
    // 飲料冷藏櫃的冰藍剪影
    canvas.drawRect(Rect.fromLTWH(p.dx - 48, p.dy - 32, 8, 22), Paint()..color = const Color(0xFF0284C7).withValues(alpha: 0.5));

    // 玻璃高光反光折線 (Diagonal Glass Glare)
    final glarePaint = Paint()..color = Colors.white.withValues(alpha: 0.35)..strokeWidth = 2.0;
    canvas.drawLine(Offset(p.dx - 42, p.dy - 10), Offset(p.dx - 26, p.dy - 38), glarePaint);
    canvas.drawLine(Offset(p.dx - 24, p.dy - 4), Offset(p.dx - 12, p.dy - 24), glarePaint);

    // 深灰鋁合金窗框 (Aluminum Mullions)
    final mullionPaint = Paint()..color = const Color(0xFF0F172A)..strokeWidth = 2.2;
    canvas.drawPath(windowPath, mullionPaint..style = PaintingStyle.stroke);
    // 窗框垂直分割線 (自動門分界)
    canvas.drawLine(Offset(p.dx - 22, p.dy + 3), Offset(p.dx - 22, p.dy - floor1H + 12), mullionPaint..strokeWidth = 1.8);
    // 水平橫梁
    canvas.drawLine(Offset(p.dx - bWidth / 2 + 5, p.dy - 28), Offset(p.dx - 6, p.dy - 20), mullionPaint..strokeWidth = 1.5);

    // 一樓外凸黑色門頭雨棚與立柱 (Awning Canopy)
    final canopyFront = Path()
      ..moveTo(p.dx - bWidth / 2 - 3, p.dy - floor1H + 4)
      ..lineTo(p.dx + 4, p.dy - floor1H + 24)
      ..lineTo(p.dx + 4, p.dy - floor1H + 16)
      ..lineTo(p.dx - bWidth / 2 - 3, p.dy - floor1H - 4)
      ..close();
    canvas.drawPath(canopyFront, Paint()..color = const Color(0xFF0F172A));
    // 雨棚頂部深色平面
    final canopyTop = Path()
      ..moveTo(p.dx - bWidth / 2 - 3, p.dy - floor1H - 4)
      ..lineTo(p.dx + 4, p.dy - floor1H + 16)
      ..lineTo(p.dx, p.dy + 14 - floor1H)
      ..lineTo(p.dx - bWidth / 2 + 5, p.dy - 12 - floor1H + 16)
      ..close();
    canvas.drawPath(canopyTop, Paint()..color = const Color(0xFF334155));

    // 雨棚支撐黑色鋼柱 (Canopy Support Pillars)
    canvas.drawLine(Offset(p.dx - bWidth / 2 + 1, p.dy - floor1H + 2), Offset(p.dx - bWidth / 2 + 1, p.dy - 10), Paint()..color = const Color(0xFF0F172A)..strokeWidth = 2.5);
    canvas.drawLine(Offset(p.dx + 2, p.dy - floor1H + 22), Offset(p.dx + 2, p.dy + 12), Paint()..color = const Color(0xFF0F172A)..strokeWidth = 2.5);

    // --- 發光霓虹招牌：外掛發光燈箱「🏪 CITY MART - 24HR」---
    final signCenter = Offset(p.dx - 22, p.dy - floor1H + 9);
    const signW = 76.0;
    const signH = 18.0;

    // 外發光藍白光暈 (Multiple Glow Halos)
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: signCenter, width: signW + 16, height: signH + 12), const Radius.circular(8)),
      Paint()..color = const Color(0xFF38BDF8).withValues(alpha: 0.18),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: signCenter, width: signW + 8, height: signH + 6), const Radius.circular(6)),
      Paint()..color = const Color(0xFF0284C7).withValues(alpha: 0.35),
    );

    // 招牌燈箱底板 (藍底高亮)
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: signCenter, width: signW, height: signH), const Radius.circular(4)),
      Paint()..color = const Color(0xFF0284C7),
    );
    // 招牌邊框白高光
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: signCenter, width: signW, height: signH), const Radius.circular(4)),
      Paint()
        ..color = const Color(0xFF38BDF8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );

    // 招牌文字
    final signTp = TextPainter(
      text: const TextSpan(
        text: '🏪 CITY MART - 24HR',
        style: TextStyle(
          color: Colors.white,
          fontSize: 8.0,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.2,
          shadows: [
            Shadow(color: Color(0xFF38BDF8), blurRadius: 6),
            Shadow(color: Colors.black, blurRadius: 2, offset: Offset(0.5, 0.5)),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    signTp.paint(canvas, Offset(signCenter.dx - signTp.width / 2, signCenter.dy - signTp.height / 2));

    // --- 二樓建築：現代橫條紋外牆板與 2 扇透出溫暖鵝黃光芒的四格木框窗 ---
    final sidingPaint = Paint()..color = const Color(0xFF334155)..strokeWidth = 1.2;
    for (double sy = p.dy - floor1H - 8; sy > p.dy - bHeight + 14; sy -= 6.0) {
      canvas.drawLine(Offset(p.dx - bWidth / 2 + 4, sy - 14), Offset(p.dx - 2, sy + 6), sidingPaint);
    }

    // 2 扇二樓窗戶
    _drawGlowingWindow(canvas, Offset(p.dx - 36, p.dy - floor1H - 24), 16, 20);
    _drawGlowingWindow(canvas, Offset(p.dx - 16, p.dy - floor1H - 14), 16, 20);

    // --- 屋頂結構：外凸水泥女兒牆、立體 HVAC 空調排風機組、排氣管道 ---
    final roofCenter = Offset(p.dx, p.dy - bHeight + 14);

    // 女兒牆邊框 (Parapet)
    final parapetTop = Path()
      ..moveTo(p.dx, roofCenter.dy - bDepth / 2 - 3)
      ..lineTo(p.dx + bWidth / 2 + 3, roofCenter.dy)
      ..lineTo(p.dx, roofCenter.dy + bDepth / 2 + 3)
      ..lineTo(p.dx - bWidth / 2 - 3, roofCenter.dy)
      ..close();
    canvas.drawPath(parapetTop, Paint()..color = const Color(0xFF475569));

    // 凹陷屋頂平台 (Dark Roof Deck)
    final roofDeck = Path()
      ..moveTo(p.dx, roofCenter.dy - bDepth / 2 + 3)
      ..lineTo(p.dx + bWidth / 2 - 4, roofCenter.dy)
      ..lineTo(p.dx, roofCenter.dy + bDepth / 2 - 3)
      ..lineTo(p.dx - bWidth / 2 + 4, roofCenter.dy)
      ..close();
    canvas.drawPath(roofDeck, Paint()..color = const Color(0xFF1E293B));

    // 立體 HVAC 空調排風機組 (Metal HVAC Unit)
    final hvacPos = Offset(p.dx - 10, roofCenter.dy - 6);
    _draw3DBox(canvas, hvacPos, 22, 18, 14, const Color(0xFF475569), const Color(0xFF334155), const Color(0xFF64748B));
    // HVAC 頂部圓形排風扇孔與扇葉
    canvas.drawOval(
      Rect.fromCenter(center: Offset(hvacPos.dx, hvacPos.dy - 14), width: 12, height: 6),
      Paint()..color = const Color(0xFF0F172A),
    );
    canvas.drawLine(Offset(hvacPos.dx - 4, hvacPos.dy - 14), Offset(hvacPos.dx + 4, hvacPos.dy - 14), Paint()..color = const Color(0xFF94A3B8)..strokeWidth = 1.2);
    canvas.drawLine(Offset(hvacPos.dx, hvacPos.dy - 16), Offset(hvacPos.dx, hvacPos.dy - 12), Paint()..color = const Color(0xFF94A3B8)..strokeWidth = 1.2);

    // 排氣管道 (Industrial Vent Pipe)
    final pipeBase = Offset(p.dx + 16, roofCenter.dy - 2);
    canvas.drawLine(pipeBase, Offset(pipeBase.dx, pipeBase.dy - 16), Paint()..color = const Color(0xFF94A3B8)..strokeWidth = 3.5..strokeCap = StrokeCap.round);
    canvas.drawLine(Offset(pipeBase.dx, pipeBase.dy - 16), Offset(pipeBase.dx - 6, pipeBase.dy - 19), Paint()..color = const Color(0xFF94A3B8)..strokeWidth = 3.0..strokeCap = StrokeCap.round);

    // 通訊天線 (Antenna with red warning beacon)
    final antennaPos = Offset(p.dx + 26, roofCenter.dy - 8);
    canvas.drawLine(antennaPos, Offset(antennaPos.dx, antennaPos.dy - 28), Paint()..color = const Color(0xFFCBD5E1)..strokeWidth = 1.5);
    canvas.drawCircle(Offset(antennaPos.dx, antennaPos.dy - 28), 2.2, Paint()..color = const Color(0xFFEF4444));
  }

  // --- 二樓四格木框暖光窗戶輔助繪製 ---
  void _drawGlowingWindow(Canvas canvas, Offset center, double width, double height) {
    final winRect = Rect.fromCenter(center: center, width: width, height: height);

    // 立體深灰外框與窗台 (Windowsill)
    canvas.drawRect(Rect.fromCenter(center: Offset(center.dx, center.dy + height / 2 + 1), width: width + 4, height: 3), Paint()..color = const Color(0xFF64748B));
    canvas.drawRect(Rect.fromCenter(center: center, width: width + 2, height: height + 2), Paint()..color = const Color(0xFF0F172A));

    // 溫暖鵝黃光芒玻璃
    canvas.drawRect(
      winRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFEF08A), Color(0xFFFBBF24)],
        ).createShader(winRect),
    );

    // 窗戶外發光微暈
    canvas.drawRect(
      Rect.fromCenter(center: center, width: width + 6, height: height + 6),
      Paint()..color = const Color(0xFFFDE047).withValues(alpha: 0.15),
    );

    // 深色四格木框十字筋
    final mullionPaint = Paint()..color = const Color(0xFF451A03)..strokeWidth = 1.5;
    canvas.drawLine(Offset(center.dx - width / 2, center.dy), Offset(center.dx + width / 2, center.dy), mullionPaint);
    canvas.drawLine(Offset(center.dx, center.dy - height / 2), Offset(center.dx, center.dy + height / 2), mullionPaint);
  }

  // ============================================================================
  // 物件 2: 【街角出租老公寓 (gx: 2.0, gy: 0.5)】
  // ============================================================================
  void _drawApartmentBuilding(Canvas canvas, double ox, double oy) {
    final p = _iso(2.0, 0.5, ox, oy);
    const double bWidth = 88.0;
    const double bDepth = 52.0;
    const double bHeight = 126.0;

    // 建物地面柔和陰影
    final shadowPath = Path()
      ..moveTo(p.dx - bWidth / 2 - 8, p.dy + 4)
      ..lineTo(p.dx + bWidth / 2 + 16, p.dy - 6)
      ..lineTo(p.dx + bWidth / 2 + 24, p.dy + 12)
      ..lineTo(p.dx, p.dy + 22)
      ..close();
    canvas.drawPath(shadowPath, Paint()..color = Colors.black.withValues(alpha: 0.45));

    // 1. 建築體主面 (右側面陰影磚紅、左側面經典英倫紅磚主立面)
    final rightWall = Path()
      ..moveTo(p.dx, p.dy + 12)
      ..lineTo(p.dx + bWidth / 2, p.dy - 10)
      ..lineTo(p.dx + bWidth / 2, p.dy - 10 - bHeight)
      ..lineTo(p.dx, p.dy + 12 - bHeight)
      ..close();
    canvas.drawPath(rightWall, Paint()..color = const Color(0xFF5C1D1D));

    final leftWall = Path()
      ..moveTo(p.dx - bWidth / 2, p.dy - 10)
      ..lineTo(p.dx, p.dy + 12)
      ..lineTo(p.dx, p.dy + 12 - bHeight)
      ..lineTo(p.dx - bWidth / 2, p.dy - 10 - bHeight)
      ..close();
    canvas.drawPath(leftWall, Paint()..color = const Color(0xFF991B1B));

    // 經典紅磚立面紋理疊加 (Staggered Brick Texture & Mortar)
    final mortarPaint = Paint()..color = const Color(0xFF7F1D1D)..strokeWidth = 1.0;
    for (double by = p.dy + 6; by > p.dy - bHeight + 16; by -= 7.0) {
      canvas.drawLine(Offset(p.dx - bWidth / 2 + 4, by - 20), Offset(p.dx - 2, by), mortarPaint);
    }
    // 錯落的淺磚色塊突顯低多邊形立體感
    final brickHighlight = Paint()..color = const Color(0xFFB91C1C);
    canvas.drawRect(Rect.fromLTWH(p.dx - 38, p.dy - 40, 10, 4), brickHighlight);
    canvas.drawRect(Rect.fromLTWH(p.dx - 22, p.dy - 68, 12, 4), brickHighlight);
    canvas.drawRect(Rect.fromLTWH(p.dx - 32, p.dy - 92, 10, 4), brickHighlight);

    // 外牆轉角裝飾石塊 (Quoins)
    final quoinPaint = Paint()..color = const Color(0xFFD6D3D1);
    for (double qy = p.dy + 6; qy > p.dy - bHeight + 20; qy -= 14.0) {
      canvas.drawRect(Rect.fromLTWH(p.dx - bWidth / 2, qy - 22, 5, 5), quoinPaint);
      canvas.drawRect(Rect.fromLTWH(p.dx - 3, qy, 4, 5), quoinPaint);
    }

    // --- 門前 3 階入戶立體階梯 (3-tier Entry Steps) ---
    for (int step = 0; step < 3; step++) {
      final stepOffset = step * 3.5;
      final stepP = Offset(p.dx - 18 + stepOffset * 0.8, p.dy + 4 + stepOffset);
      _draw3DBox(canvas, stepP, 26 - step * 2.0, 14, 3.5, const Color(0xFF64748B), const Color(0xFF475569), const Color(0xFF94A3B8));
    }

    // --- 雙扇木質公寓大門、金屬門把、上方半圓氣窗、門牌 ---
    final doorCenter = Offset(p.dx - 16, p.dy - 16);
    const doorW = 20.0;
    const doorH = 34.0;

    // 門框
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: doorCenter, width: doorW + 4, height: doorH + 6), const Radius.circular(2)),
      Paint()..color = const Color(0xFF292524),
    );
    // 實木深色雙扇大門
    canvas.drawRect(Rect.fromCenter(center: doorCenter, width: doorW, height: doorH), Paint()..color = const Color(0xFF451A03));
    // 雙門中縫
    canvas.drawLine(Offset(doorCenter.dx, doorCenter.dy - doorH / 2), Offset(doorCenter.dx, doorCenter.dy + doorH / 2), Paint()..color = const Color(0xFF1C1917)..strokeWidth = 1.5);
    // 門片內嵌線板飾紋
    final panelPaint = Paint()..color = const Color(0xFF78350F);
    canvas.drawRect(Rect.fromLTWH(doorCenter.dx - 8, doorCenter.dy - 12, 6, 10), panelPaint);
    canvas.drawRect(Rect.fromLTWH(doorCenter.dx + 2, doorCenter.dy - 12, 6, 10), panelPaint);
    canvas.drawRect(Rect.fromLTWH(doorCenter.dx - 8, doorCenter.dy + 3, 6, 10), panelPaint);
    canvas.drawRect(Rect.fromLTWH(doorCenter.dx + 2, doorCenter.dy + 3, 6, 10), panelPaint);

    // 金屬門把 (雙側黃銅把手)
    canvas.drawCircle(Offset(doorCenter.dx - 2.5, doorCenter.dy + 2), 1.2, Paint()..color = const Color(0xFFFBBF24));
    canvas.drawCircle(Offset(doorCenter.dx + 2.5, doorCenter.dy + 2), 1.2, Paint()..color = const Color(0xFFFBBF24));

    // 門頭半圓氣窗 (Fanlight Transom with warm yellow glow)
    final fanlightRect = Rect.fromCenter(center: Offset(doorCenter.dx, doorCenter.dy - doorH / 2 - 2), width: doorW, height: 12);
    canvas.drawArc(fanlightRect, math.pi, math.pi, true, Paint()..color = const Color(0xFFFEF08A));
    canvas.drawArc(fanlightRect, math.pi, math.pi, false, Paint()..color = const Color(0xFF292524)..style = PaintingStyle.stroke..strokeWidth = 1.2);
    // 扇骨
    canvas.drawLine(Offset(doorCenter.dx, doorCenter.dy - doorH / 2 - 2), Offset(doorCenter.dx, doorCenter.dy - doorH / 2 - 7), Paint()..color = const Color(0xFF292524)..strokeWidth = 1.0);

    // 精緻門牌「No. 201」
    final plateRect = Rect.fromCenter(center: Offset(doorCenter.dx + doorW / 2 + 5, doorCenter.dy - 4), width: 8, height: 5);
    canvas.drawRect(plateRect, Paint()..color = const Color(0xFFFBBF24));

    // 門口招牌「🏠 幸福公寓」
    final signCenter = Offset(p.dx - 18, p.dy - 44);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: signCenter, width: 44, height: 13), const Radius.circular(3)),
      Paint()..color = const Color(0xFF451A03),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: signCenter, width: 44, height: 13), const Radius.circular(3)),
      Paint()..color = const Color(0xFFFBBF24)..style = PaintingStyle.stroke..strokeWidth = 1.0,
    );
    final signTp = TextPainter(
      text: const TextSpan(
        text: '🏠 幸福公寓',
        style: TextStyle(color: Color(0xFFFEF08A), fontSize: 7.5, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    signTp.paint(canvas, Offset(signCenter.dx - signTp.width / 2, signCenter.dy - signTp.height / 2));

    // --- 4 扇鑲嵌式復古窗戶 (深綠色百葉窗、白色窗框、透出生活暖光) ---
    // 一樓窗戶 (左)
    _drawRetroApartmentWindow(canvas, Offset(p.dx - 36, p.dy - 22));
    // 二樓窗戶 (左、中、右)
    _drawRetroApartmentWindow(canvas, Offset(p.dx - 36, p.dy - 68));
    _drawRetroApartmentWindow(canvas, Offset(p.dx - 18, p.dy - 78));
    _drawRetroApartmentWindow(canvas, Offset(p.dx - 4, p.dy - 56));

    // --- 側牆外掛金屬冷氣室外壓縮機 (AC Outdoor Compressor) ---
    final acPos = Offset(p.dx + 22, p.dy - 35);
    // 三角支架
    canvas.drawLine(Offset(acPos.dx - 6, acPos.dy + 8), Offset(acPos.dx + 6, acPos.dy + 8), Paint()..color = const Color(0xFF1E293B)..strokeWidth = 1.5);
    canvas.drawLine(Offset(acPos.dx, acPos.dy + 8), Offset(acPos.dx - 4, acPos.dy + 14), Paint()..color = const Color(0xFF1E293B)..strokeWidth = 1.5);
    // 壓縮機金屬箱體
    _draw3DBox(canvas, acPos, 16, 12, 12, const Color(0xFF64748B), const Color(0xFF475569), const Color(0xFF94A3B8));
    // 圓形散熱葉片罩
    canvas.drawCircle(Offset(acPos.dx + 3, acPos.dy - 4), 3.5, Paint()..color = const Color(0xFF1E293B));
    canvas.drawCircle(Offset(acPos.dx + 3, acPos.dy - 4), 1.5, Paint()..color = const Color(0xFFCBD5E1));

    // --- 屋簷凸出線腳 (Cornice Molding) 與屋頂結構 ---
    final roofCenter = Offset(p.dx, p.dy - bHeight + 12);
    // 凸出線腳
    final cornice = Path()
      ..moveTo(p.dx, roofCenter.dy - bDepth / 2 - 4)
      ..lineTo(p.dx + bWidth / 2 + 4, roofCenter.dy)
      ..lineTo(p.dx, roofCenter.dy + bDepth / 2 + 4)
      ..lineTo(p.dx - bWidth / 2 - 4, roofCenter.dy)
      ..close();
    canvas.drawPath(cornice, Paint()..color = const Color(0xFF475569));
    // 線腳下裝飾齒狀飾塊 (Dentils)
    canvas.drawLine(Offset(p.dx - bWidth / 2 - 4, roofCenter.dy), Offset(p.dx, roofCenter.dy + bDepth / 2 + 4), Paint()..color = const Color(0xFF334155)..strokeWidth = 2.0);

    // 屋頂平台 (Roof Deck)
    final roofDeck = Path()
      ..moveTo(p.dx, roofCenter.dy - bDepth / 2 + 2)
      ..lineTo(p.dx + bWidth / 2 - 3, roofCenter.dy)
      ..lineTo(p.dx, roofCenter.dy + bDepth / 2 - 2)
      ..lineTo(p.dx - bWidth / 2 + 3, roofCenter.dy)
      ..close();
    canvas.drawPath(roofDeck, Paint()..color = const Color(0xFF334155));

    // 磚造小煙囪 (Brick Chimney)
    final chimneyPos = Offset(p.dx - 18, roofCenter.dy - 4);
    _draw3DBox(canvas, chimneyPos, 12, 10, 14, const Color(0xFF7F1D1D), const Color(0xFF991B1B), const Color(0xFFB91C1C));
  }

  // --- 公寓復古窗戶 (深綠色木百葉窗 + 白色窗框 + 溫暖生活光) ---
  void _drawRetroApartmentWindow(Canvas canvas, Offset center) {
    const w = 12.0;
    const h = 16.0;

    // 白色突出窗台與窗楣
    canvas.drawRect(Rect.fromCenter(center: Offset(center.dx, center.dy + h / 2 + 1), width: w + 12, height: 2.5), Paint()..color = const Color(0xFFF1F5F9));
    canvas.drawRect(Rect.fromCenter(center: Offset(center.dx, center.dy - h / 2 - 1), width: w + 10, height: 2.0), Paint()..color = const Color(0xFFE2E8F0));

    // 深綠色木百葉窗 (兩側百葉門板)
    final shutterPaint = Paint()..color = const Color(0xFF14532D);
    canvas.drawRect(Rect.fromCenter(center: Offset(center.dx - w / 2 - 3.5, center.dy), width: 5, height: h), shutterPaint);
    canvas.drawRect(Rect.fromCenter(center: Offset(center.dx + w / 2 + 3.5, center.dy), width: 5, height: h), shutterPaint);
    // 百葉橫紋
    final louverPaint = Paint()..color = const Color(0xFF166534)..strokeWidth = 0.8;
    for (double ly = center.dy - h / 2 + 2; ly < center.dy + h / 2; ly += 2.8) {
      canvas.drawLine(Offset(center.dx - w / 2 - 5.5, ly), Offset(center.dx - w / 2 - 1.5, ly), louverPaint);
      canvas.drawLine(Offset(center.dx + w / 2 + 1.5, ly), Offset(center.dx + w / 2 + 5.5, ly), louverPaint);
    }

    // 白色窗框
    canvas.drawRect(Rect.fromCenter(center: center, width: w, height: h), Paint()..color = Colors.white);

    // 窗內溫暖生活燈光
    final lightRect = Rect.fromCenter(center: center, width: w - 2, height: h - 2);
    canvas.drawRect(
      lightRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFEF08A), Color(0xFFF59E0B)],
        ).createShader(lightRect),
    );

    // 白色四格窗十字筋
    final mullion = Paint()..color = Colors.white..strokeWidth = 1.0;
    canvas.drawLine(Offset(center.dx - w / 2 + 1, center.dy), Offset(center.dx + w / 2 - 1, center.dy), mullion);
    canvas.drawLine(Offset(center.dx, center.dy - h / 2 + 1), Offset(center.dx, center.dy + h / 2 - 1), mullion);
  }

  // ============================================================================
  // 物件 3: 【大都會黃色計程車 (Yellow Taxi) (gx: 5.0, gy: 7.0)】
  // ============================================================================
  void _drawYellowTaxi(Canvas canvas, Offset p) {
    // 絕不是黃色方塊！經典低多邊形轎車 (Sedan) 幾何造型，朝向東南方 (gx 軸正向)
    // 1. 車底地面柔和投影
    canvas.drawOval(
      Rect.fromCenter(center: Offset(p.dx + 4, p.dy + 8), width: 56, height: 26),
      Paint()..color = Colors.black.withValues(alpha: 0.55),
    );

    // 2. 4 個黑色橡膠輪胎與金屬銀色輪圈 (立體前後四輪)
    void drawWheel(Offset wp) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: wp, width: 8, height: 11), const Radius.circular(2.5)),
        Paint()..color = const Color(0xFF0F172A),
      );
      canvas.drawCircle(wp, 2.8, Paint()..color = const Color(0xFFE2E8F0));
      canvas.drawCircle(wp, 1.2, Paint()..color = const Color(0xFF475569));
    }

    // 左後輪、右後輪、左前輪、右前輪
    drawWheel(Offset(p.dx - 16, p.dy + 3));
    drawWheel(Offset(p.dx - 4, p.dy - 6));
    drawWheel(Offset(p.dx + 15, p.dy + 12));
    drawWheel(Offset(p.dx + 27, p.dy + 3));

    // 3. 轎車下車身底盤與防撞保險桿 (Lower Bumper & Chassis)
    final chassisFront = Path()
      ..moveTo(p.dx + 28, p.dy - 2)
      ..lineTo(p.dx + 35, p.dy + 3)
      ..lineTo(p.dx + 26, p.dy + 14)
      ..lineTo(p.dx + 19, p.dy + 9)
      ..close();
    canvas.drawPath(chassisFront, Paint()..color = const Color(0xFFCBD5E1)); // 前保險桿鍍鉻銀

    // 4. 車身下層主體 (Lower Sedan Body - 前引擎蓋、車門側立面、車尾行李廂)
    // 側車身 (左側面面向玩家)
    final sideBody = Path()
      ..moveTo(p.dx - 22, p.dy - 1)
      ..lineTo(p.dx - 22, p.dy - 10)
      ..lineTo(p.dx - 10, p.dy - 14) // 後行李箱肩線
      ..lineTo(p.dx + 8, p.dy - 6)   // 引擎蓋接縫
      ..lineTo(p.dx + 31, p.dy + 4)  // 前水箱罩
      ..lineTo(p.dx + 26, p.dy + 13)
      ..lineTo(p.dx - 18, p.dy + 6)
      ..close();
    canvas.drawPath(sideBody, Paint()..color = const Color(0xFFEAB308)); // 計程車經典黃

    // 前引擎蓋 (Sloped Front Hood)
    final hoodTop = Path()
      ..moveTo(p.dx + 8, p.dy - 6)
      ..lineTo(p.dx + 16, p.dy - 12)
      ..lineTo(p.dx + 33, p.dy - 2)
      ..lineTo(p.dx + 25, p.dy + 4)
      ..close();
    canvas.drawPath(hoodTop, Paint()..color = const Color(0xFFFDE047)); // 受光高亮黃

    // 後行李箱蓋 (Rear Trunk Lid)
    final trunkTop = Path()
      ..moveTo(p.dx - 22, p.dy - 10)
      ..lineTo(p.dx - 14, p.dy - 15)
      ..lineTo(p.dx - 6, p.dy - 11)
      ..lineTo(p.dx - 10, p.dy - 6)
      ..close();
    canvas.drawPath(trunkTop, Paint()..color = const Color(0xFFFACC15));

    // 5. 車側經典黑白雙色西洋棋盤計程車條紋 (Checker Stripe)
    for (int i = 0; i < 7; i++) {
      final t = i / 6.0;
      final sx = p.dx - 16 + t * 38;
      final sy = p.dy + 3 - t * 4;
      final isWhite = (i % 2 == 0);
      canvas.drawRect(
        Rect.fromCenter(center: Offset(sx, sy), width: 3.5, height: 3.0),
        Paint()..color = isWhite ? Colors.white : Colors.black87,
      );
    }

    // 6. 前水箱罩、明亮車燈與紅色尾燈
    // 鍍鉻水箱罩
    canvas.drawRect(Rect.fromCenter(center: Offset(p.dx + 29, p.dy + 3), width: 4, height: 5), Paint()..color = const Color(0xFF475569));
    // 2 盞明亮車燈
    canvas.drawCircle(Offset(p.dx + 27, p.dy + 7), 2.2, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(p.dx + 31, p.dy), 2.2, Paint()..color = Colors.white);
    // 車尾紅寶石尾燈
    canvas.drawCircle(Offset(p.dx - 22, p.dy - 5), 1.8, Paint()..color = const Color(0xFFEF4444));

    // 7. 乘客座艙與傾斜擋風玻璃 (Cabin & Sloped Tinted Windshield)
    // 前擋風玻璃 (深色傾斜玻璃帶高光)
    final frontWindshield = Path()
      ..moveTo(p.dx + 8, p.dy - 6)
      ..lineTo(p.dx + 16, p.dy - 12)
      ..lineTo(p.dx + 10, p.dy - 20)
      ..lineTo(p.dx + 2, p.dy - 14)
      ..close();
    canvas.drawPath(frontWindshield, Paint()..color = const Color(0xFF0F172A));
    // 擋風玻璃青藍反光斜線
    canvas.drawLine(Offset(p.dx + 13, p.dy - 12), Offset(p.dx + 5, p.dy - 18), Paint()..color = const Color(0xFF38BDF8).withValues(alpha: 0.6)..strokeWidth = 1.2);

    // 座艙頂棚 (Cabin Roof)
    final roofTop = Path()
      ..moveTo(p.dx + 2, p.dy - 14)
      ..lineTo(p.dx + 10, p.dy - 20)
      ..lineTo(p.dx - 3, p.dy - 25)
      ..lineTo(p.dx - 9, p.dy - 19)
      ..close();
    canvas.drawPath(roofTop, Paint()..color = const Color(0xFFFDE047));

    // 側車窗 (深色透明座艙窗戶)
    final sideWindows = Path()
      ..moveTo(p.dx + 2, p.dy - 14)
      ..lineTo(p.dx - 9, p.dy - 19)
      ..lineTo(p.dx - 10, p.dy - 12)
      ..lineTo(p.dx + 4, p.dy - 6)
      ..close();
    canvas.drawPath(sideWindows, Paint()..color = const Color(0xFF1E293B));
    // B 柱銀飾隔線
    canvas.drawLine(Offset(p.dx - 3, p.dy - 16), Offset(p.dx - 2, p.dy - 9), Paint()..color = const Color(0xFFEAB308)..strokeWidth = 1.5);

    // 8. 車頂立體梯形黃白雙色「TAXI」發光燈箱
    final taxiSignCenter = Offset(p.dx + 1, p.dy - 23);
    // 燈箱底座
    canvas.drawRect(Rect.fromCenter(center: Offset(taxiSignCenter.dx, taxiSignCenter.dy + 2), width: 14, height: 2), Paint()..color = const Color(0xFF1E293B));
    // 梯形燈箱主體
    final signPath = Path()
      ..moveTo(taxiSignCenter.dx - 6, taxiSignCenter.dy + 1)
      ..lineTo(taxiSignCenter.dx + 6, taxiSignCenter.dy + 1)
      ..lineTo(taxiSignCenter.dx + 4, taxiSignCenter.dy - 5)
      ..lineTo(taxiSignCenter.dx - 4, taxiSignCenter.dy - 5)
      ..close();
    canvas.drawPath(signPath, Paint()..color = Colors.white);
    canvas.drawPath(signPath, Paint()..color = const Color(0xFFFACC15)..style = PaintingStyle.stroke..strokeWidth = 1.0);

    // 燈箱上的「TAXI」極小字
    final taxiTp = TextPainter(
      text: const TextSpan(
        text: 'TAXI',
        style: TextStyle(color: Colors.black, fontSize: 4.8, fontWeight: FontWeight.w900),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    taxiTp.paint(canvas, Offset(taxiSignCenter.dx - taxiTp.width / 2, taxiSignCenter.dy - taxiTp.height / 2 - 1));
  }

  // ============================================================================
  // 物件 4: 【維多利亞復古黑色鑄鐵路燈】
  // ============================================================================
  void _drawRetroStreetLamp(Canvas canvas, Offset p) {
    const lampHeight = 66.0;

    // 1. 多角形黑色鑄鐵階梯底座 (Stepped Cast-Iron Base)
    canvas.drawOval(Rect.fromCenter(center: p, width: 12, height: 6), Paint()..color = const Color(0xFF0F172A));
    canvas.drawOval(Rect.fromCenter(center: Offset(p.dx, p.dy - 3), width: 8, height: 4), Paint()..color = const Color(0xFF1E293B));

    // 2. 黑色立體錐形鑄鐵燈桿 (Tapered Cast-Iron Pole)
    final polePaint = Paint()..color = const Color(0xFF0F172A)..strokeWidth = 2.8..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(p.dx, p.dy - 3), Offset(p.dx, p.dy - lampHeight + 14), polePaint);
    // 燈桿中間的裝飾凸環節 (Ornamental Rings)
    canvas.drawCircle(Offset(p.dx, p.dy - 22), 2.2, Paint()..color = const Color(0xFF334155));
    canvas.drawCircle(Offset(p.dx, p.dy - 44), 2.0, Paint()..color = const Color(0xFF334155));

    // 3. 頂部懸挑花紋彎臂 (Curved Bracket Arm)
    final bracketPath = Path()
      ..moveTo(p.dx, p.dy - lampHeight + 18)
      ..quadraticBezierTo(p.dx + 4, p.dy - lampHeight + 12, p.dx + 6, p.dy - lampHeight + 8)
      ..quadraticBezierTo(p.dx + 7, p.dy - lampHeight + 4, p.dx + 5, p.dy - lampHeight);
    canvas.drawPath(bracketPath, Paint()..color = const Color(0xFF0F172A)..style = PaintingStyle.stroke..strokeWidth = 2.0);

    // 4. 六角玻璃燈籠 (Hexagonal Victorian Lantern)
    final lanternCenter = Offset(p.dx + 5, p.dy - lampHeight + 4);
    const double lanW = 12.0;
    const double lanH = 14.0;

    // 六角燈籠外頂尖錐帽 (Finial Cap)
    final capPath = Path()
      ..moveTo(lanternCenter.dx - lanW / 2 - 1, lanternCenter.dy - lanH / 2)
      ..lineTo(lanternCenter.dx, lanternCenter.dy - lanH / 2 - 5)
      ..lineTo(lanternCenter.dx + lanW / 2 + 1, lanternCenter.dy - lanH / 2)
      ..close();
    canvas.drawPath(capPath, Paint()..color = const Color(0xFF0F172A));
    // 頂尖小金屬球
    canvas.drawCircle(Offset(lanternCenter.dx, lanternCenter.dy - lanH / 2 - 5), 1.2, Paint()..color = const Color(0xFFFBBF24));

    // 發光六角玻璃燈室 (Glowing Warm Glass Chamber)
    final glassRect = Rect.fromCenter(center: lanternCenter, width: lanW, height: lanH);
    canvas.drawRect(
      glassRect,
      Paint()
        ..shader = const RadialGradient(
          colors: [Colors.white, Color(0xFFFEF08A), Color(0xFFF59E0B)],
          stops: [0.0, 0.45, 1.0],
        ).createShader(glassRect),
    );

    // 六角鑄鐵玻璃窗條肋線 (Iron Struts)
    final strutPaint = Paint()..color = const Color(0xFF0F172A)..strokeWidth = 1.0;
    canvas.drawRect(glassRect, strutPaint..style = PaintingStyle.stroke);
    canvas.drawLine(Offset(lanternCenter.dx - lanW / 4, lanternCenter.dy - lanH / 2), Offset(lanternCenter.dx - lanW / 4, lanternCenter.dy + lanH / 2), strutPaint);
    canvas.drawLine(Offset(lanternCenter.dx + lanW / 4, lanternCenter.dy - lanH / 2), Offset(lanternCenter.dx + lanW / 4, lanternCenter.dy + lanH / 2), strutPaint);

    // 燈籠底部收口基座
    canvas.drawRect(Rect.fromCenter(center: Offset(lanternCenter.dx, lanternCenter.dy + lanH / 2 + 1), width: 6, height: 2), Paint()..color = const Color(0xFF0F172A));

    // 放射狀柔和光暈 (Radiant Flare)
    canvas.drawCircle(lanternCenter, 16, Paint()..color = const Color(0xFFFDE047).withValues(alpha: 0.28));
    canvas.drawCircle(lanternCenter, 7, Paint()..color = const Color(0xFFFFFBEB).withValues(alpha: 0.45));
  }

  // ============================================================================
  // 物件 5: 【低多邊形行道樹 (Low-Poly Isometric Diorama Tree)】
  // ============================================================================
  void _drawLowPolyTree(Canvas canvas, Offset p) {
    // 1. 人行道圓形砌石樹穴 (Stone Planter Rim & Rich Dark Soil)
    canvas.drawOval(Rect.fromCenter(center: p, width: 28, height: 14), Paint()..color = const Color(0xFF475569));
    canvas.drawOval(Rect.fromCenter(center: p, width: 24, height: 12), Paint()..color = const Color(0xFF27272A));
    // 砌石塊狀紋理
    final stonePaint = Paint()..color = const Color(0xFF64748B)..strokeWidth = 1.0;
    for (int i = 0; i < 6; i++) {
      final angle = i * math.pi / 3;
      final sx = p.dx + math.cos(angle) * 12;
      final sy = p.dy + math.sin(angle) * 6;
      canvas.drawLine(Offset(sx, sy), Offset(p.dx + math.cos(angle) * 14, p.dy + math.sin(angle) * 7), stonePaint);
    }

    // 2. 深木色多面體立體樹幹 (Faceted Trunk & Branches)
    final trunkBottom = Offset(p.dx, p.dy - 1);
    final trunkFork = Offset(p.dx, p.dy - 28);

    // 樹幹左暗面與右受光面
    final trunkLeft = Path()
      ..moveTo(trunkBottom.dx - 3, trunkBottom.dy)
      ..lineTo(trunkFork.dx - 2, trunkFork.dy)
      ..lineTo(trunkFork.dx, trunkFork.dy)
      ..lineTo(trunkBottom.dx, trunkBottom.dy)
      ..close();
    canvas.drawPath(trunkLeft, Paint()..color = const Color(0xFF3E2718));

    final trunkRight = Path()
      ..moveTo(trunkBottom.dx, trunkBottom.dy)
      ..lineTo(trunkFork.dx, trunkFork.dy)
      ..lineTo(trunkFork.dx + 2, trunkFork.dy)
      ..lineTo(trunkBottom.dx + 3, trunkBottom.dy)
      ..close();
    canvas.drawPath(trunkRight, Paint()..color = const Color(0xFF573926));

    // 3. 幾何多面體翠綠樹冠 (Low-Poly Faceted Foliage Canopy)
    // 由 7 個不同朝向與明度的多邊形面拼合而成，呈現極致 Monument Valley 幾何美感
    final canopyCenter = Offset(p.dx, p.dy - 52);

    // 頂部頂光面 (明亮嫩綠)
    final facetTop = Path()
      ..moveTo(canopyCenter.dx, canopyCenter.dy - 24)
      ..lineTo(canopyCenter.dx + 16, canopyCenter.dy - 12)
      ..lineTo(canopyCenter.dx, canopyCenter.dy - 6)
      ..lineTo(canopyCenter.dx - 16, canopyCenter.dy - 12)
      ..close();
    canvas.drawPath(facetTop, Paint()..color = const Color(0xFF34D399));

    // 正前受光面 (翠綠)
    final facetFront = Path()
      ..moveTo(canopyCenter.dx, canopyCenter.dy - 6)
      ..lineTo(canopyCenter.dx + 16, canopyCenter.dy - 12)
      ..lineTo(canopyCenter.dx + 12, canopyCenter.dy + 12)
      ..lineTo(canopyCenter.dx, canopyCenter.dy + 18)
      ..close();
    canvas.drawPath(facetFront, Paint()..color = const Color(0xFF10B981));

    // 左正面 (清新綠)
    final facetFrontLeft = Path()
      ..moveTo(canopyCenter.dx, canopyCenter.dy - 6)
      ..lineTo(canopyCenter.dx, canopyCenter.dy + 18)
      ..lineTo(canopyCenter.dx - 12, canopyCenter.dy + 12)
      ..lineTo(canopyCenter.dx - 16, canopyCenter.dy - 12)
      ..close();
    canvas.drawPath(facetFrontLeft, Paint()..color = const Color(0xFF059669));

    // 右側陰影面 (深墨綠)
    final facetRight = Path()
      ..moveTo(canopyCenter.dx + 16, canopyCenter.dy - 12)
      ..lineTo(canopyCenter.dx + 22, canopyCenter.dy + 2)
      ..lineTo(canopyCenter.dx + 12, canopyCenter.dy + 12)
      ..close();
    canvas.drawPath(facetRight, Paint()..color = const Color(0xFF047857));

    // 左側陰影面 (濃蔭綠)
    final facetLeft = Path()
      ..moveTo(canopyCenter.dx - 16, canopyCenter.dy - 12)
      ..lineTo(canopyCenter.dx - 12, canopyCenter.dy + 12)
      ..lineTo(canopyCenter.dx - 22, canopyCenter.dy + 2)
      ..close();
    canvas.drawPath(facetLeft, Paint()..color = const Color(0xFF065F46));

    // 樹冠底層背光面 (深墨松綠)
    final facetBottom = Path()
      ..moveTo(canopyCenter.dx - 12, canopyCenter.dy + 12)
      ..lineTo(canopyCenter.dx, canopyCenter.dy + 18)
      ..lineTo(canopyCenter.dx + 12, canopyCenter.dy + 12)
      ..lineTo(canopyCenter.dx, canopyCenter.dy + 24)
      ..close();
    canvas.drawPath(facetBottom, Paint()..color = const Color(0xFF064E3B));

    // 多面體邊緣俐落低多邊形刻線 (Low-Poly Edges)
    final edgePaint = Paint()
      ..color = const Color(0xFF022C22).withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    canvas.drawPath(facetTop, edgePaint);
    canvas.drawPath(facetFront, edgePaint);
    canvas.drawPath(facetFrontLeft, edgePaint);
    canvas.drawPath(facetRight, edgePaint);
    canvas.drawPath(facetLeft, edgePaint);
  }

  // ============================================================================
  // 空間 2: 出租套房室內精細化 (Apartment Room Diorama)
  // ============================================================================
  void _paintApartment(Canvas canvas, double ox, double oy) {
    const size = 7;

    // --- 1. 交錯人字拼木地板紋理 (Herringbone Parquet Floor) ---
    for (int gy = 0; gy < size; gy++) {
      for (int gx = 0; gx < size; gx++) {
        final p = _iso(gx.toDouble(), gy.toDouble(), ox, oy);
        final baseWood = ((gx + gy) % 2 == 0) ? const Color(0xFF78350F) : const Color(0xFF854D0E);
        _drawDiamondTile(canvas, p, baseWood, const Color(0xFF451A03));

        // 人字拼木條板細緻交錯線
        final plankPaint = Paint()..color = const Color(0xFF451A03).withValues(alpha: 0.45)..strokeWidth = 1.0;
        final isEven = (gx + gy) % 2 == 0;
        if (isEven) {
          canvas.drawLine(Offset(p.dx - 18, p.dy - 4), Offset(p.dx + 2, p.dy + 6), plankPaint);
          canvas.drawLine(Offset(p.dx - 2, p.dy - 6), Offset(p.dx + 18, p.dy + 4), plankPaint);
        } else {
          canvas.drawLine(Offset(p.dx - 18, p.dy + 4), Offset(p.dx + 2, p.dy - 6), plankPaint);
          canvas.drawLine(Offset(p.dx - 2, p.dy + 6), Offset(p.dx + 18, p.dy - 4), plankPaint);
        }
      }
    }

    // --- 2. 踢腳線 (Skirting Boards) 與牆面立體結構 ---
    _drawRoomWalls(canvas, ox, oy, size, const Color(0xFF3F3F46), const Color(0xFF27272A));

    // 牆腳實木深色踢腳線 (Baseboards)
    final leftCorner = _iso(0, 0, ox, oy);
    final backRight = _iso(size.toDouble(), 0, ox, oy);
    final frontLeft = _iso(0, size.toDouble(), ox, oy);
    final baseboardPaint = Paint()..color = const Color(0xFF451A03)..strokeWidth = 4.0;
    canvas.drawLine(frontLeft, leftCorner, baseboardPaint);
    canvas.drawLine(leftCorner, backRight, baseboardPaint);

    // --- 3. 後牆高窗 (透出深藍夜空星光與大樓剪影) ---
    final winPos = _iso(size.toDouble() * 0.55, 0.0, ox, oy);
    final windowRect = Rect.fromCenter(center: Offset(winPos.dx, winPos.dy - 52), width: 32, height: 26);
    // 深灰木質凸出窗框
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: windowRect.center, width: 36, height: 30), const Radius.circular(2)), Paint()..color = const Color(0xFF18181B));
    // 深藍夜空
    canvas.drawRect(
      windowRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF020617), Color(0xFF0F172A), Color(0xFF1E1B4B)],
        ).createShader(windowRect),
    );
    // 夜空遠處摩天大樓剪影
    canvas.drawRect(Rect.fromLTWH(windowRect.left + 4, windowRect.bottom - 12, 8, 12), Paint()..color = const Color(0xFF0F172A));
    canvas.drawRect(Rect.fromLTWH(windowRect.left + 16, windowRect.bottom - 16, 10, 16), Paint()..color = const Color(0xFF090D16));
    // 遠處大樓黃色窗光小點
    canvas.drawCircle(Offset(windowRect.left + 8, windowRect.bottom - 8), 0.8, Paint()..color = const Color(0xFFFDE047));
    canvas.drawCircle(Offset(windowRect.left + 20, windowRect.bottom - 12), 0.8, Paint()..color = const Color(0xFFFDE047));
    canvas.drawCircle(Offset(windowRect.left + 22, windowRect.bottom - 6), 0.8, Paint()..color = const Color(0xFFFDE047));
    // 夜空星光 (Twinkling Stars)
    canvas.drawCircle(Offset(windowRect.left + 7, windowRect.top + 6), 0.9, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(windowRect.left + 25, windowRect.top + 5), 0.9, Paint()..color = const Color(0xFFFEF08A));
    canvas.drawCircle(Offset(windowRect.left + 16, windowRect.top + 10), 0.7, Paint()..color = Colors.white70);
    // 白色四格窗框十字
    final crossPaint = Paint()..color = Colors.white..strokeWidth = 1.2;
    canvas.drawLine(Offset(windowRect.left, windowRect.center.dy), Offset(windowRect.right, windowRect.center.dy), crossPaint);
    canvas.drawLine(Offset(windowRect.center.dx, windowRect.top), Offset(windowRect.center.dx, windowRect.bottom), crossPaint);

    // --- 4. 3D 藍色折疊床 (gx: 4.0, gy: 2.0) ---
    _drawIsometricBed(canvas, _iso(4.0, 2.0, ox, oy));

    // --- 5. 床頭置物櫃與暖色檯燈 (投射柔和光錐) ---
    _drawBedsideNightstandAndLamp(canvas, _iso(4.8, 1.3, ox, oy));

    // --- 6. 雙門拉絲金屬小冰箱 (gx: 1.5, gy: 1.5) ---
    _drawIsometricFridge(canvas, _iso(1.5, 1.5, ox, oy));

    // --- 7. 門口編織流蘇迎賓踏墊 (gx: 3.0, gy: 5.0) ---
    _drawDoormat(canvas, _iso(3.0, 5.0, ox, oy));
  }

  // --- 3D 藍色折疊床 (金屬管狀床架、厚床墊、自然垂墜摺痕被單、蓬鬆白色枕頭) ---
  void _drawIsometricBed(Canvas canvas, Offset p) {
    // 1. 金屬管狀床架 (Tubular Metallic Frame & Legs)
    final legPaint = Paint()..color = const Color(0xFF334155)..strokeWidth = 3.0..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(p.dx - 22, p.dy + 8), Offset(p.dx - 22, p.dy + 16), legPaint);
    canvas.drawLine(Offset(p.dx + 22, p.dy - 8), Offset(p.dx + 22, p.dy), legPaint);
    canvas.drawLine(Offset(p.dx, p.dy + 18), Offset(p.dx, p.dy + 26), legPaint);
    // 床頭金屬拱型護欄
    final headboardPath = Path()
      ..moveTo(p.dx - 24, p.dy - 12)
      ..lineTo(p.dx - 24, p.dy - 32)
      ..lineTo(p.dx + 2, p.dy - 44)
      ..lineTo(p.dx + 2, p.dy - 24);
    canvas.drawPath(headboardPath, Paint()..color = const Color(0xFF475569)..style = PaintingStyle.stroke..strokeWidth = 2.5);

    // 2. 厚床墊 (White Piped Mattress)
    _draw3DBox(canvas, Offset(p.dx, p.dy + 2), 46, 68, 10, const Color(0xFFCBD5E1), const Color(0xFF94A3B8), const Color(0xFFF1F5F9));

    // 3. 帶有自然垂墜摺痕的藍色被單 (Draped Sheets with Geometric Creases)
    final sheetPos = Offset(p.dx + 4, p.dy - 3);
    _draw3DBox(canvas, sheetPos, 42, 52, 9, const Color(0xFF0284C7), const Color(0xFF0369A1), const Color(0xFF38BDF8));

    // 被單摺痕低多邊形陰影線 (Quilt Facets)
    final creasePaint = Paint()..color = const Color(0xFF0C4A6E).withValues(alpha: 0.5)..strokeWidth = 1.2;
    canvas.drawLine(Offset(p.dx - 12, p.dy - 12), Offset(p.dx + 8, p.dy - 2), creasePaint);
    canvas.drawLine(Offset(p.dx - 4, p.dy - 16), Offset(p.dx + 16, p.dy - 6), creasePaint);
    // 翻摺的白色被邊 (Turn-down sheet edge)
    canvas.drawRect(Rect.fromCenter(center: Offset(p.dx - 4, p.dy - 16), width: 28, height: 4), Paint()..color = Colors.white);

    // 4. 蓬鬆白色枕頭 (Plump White Pillow with Center Crease)
    final pillowCenter = Offset(p.dx - 10, p.dy - 24);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: pillowCenter, width: 22, height: 12), const Radius.circular(4)),
      Paint()..color = const Color(0xFFE2E8F0),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(pillowCenter.dx, pillowCenter.dy - 1), width: 20, height: 10), const Radius.circular(3)),
      Paint()..color = Colors.white,
    );
    // 枕頭凹陷摺痕
    canvas.drawLine(Offset(pillowCenter.dx - 5, pillowCenter.dy - 1), Offset(pillowCenter.dx + 5, pillowCenter.dy - 1), Paint()..color = const Color(0xFFCBD5E1)..strokeWidth = 1.0);
  }

  // --- 床頭置物櫃與暖色檯燈 (Nightstand & Warm Lamp) ---
  void _drawBedsideNightstandAndLamp(Canvas canvas, Offset p) {
    // 1. 小木櫃床頭櫃
    _draw3DBox(canvas, p, 18, 18, 16, const Color(0xFF78350F), const Color(0xFF92400E), const Color(0xFFB45309));
    // 抽屜把手
    canvas.drawCircle(Offset(p.dx + 4, p.dy - 6), 1.2, Paint()..color = const Color(0xFFFBBF24));

    // 2. 暖色床頭小檯燈
    final lampPos = Offset(p.dx, p.dy - 18);
    // 檯燈底座與金屬彎頸
    canvas.drawCircle(Offset(lampPos.dx, lampPos.dy), 3.0, Paint()..color = const Color(0xFF334155));
    canvas.drawLine(lampPos, Offset(lampPos.dx, lampPos.dy - 10), Paint()..color = const Color(0xFF64748B)..strokeWidth = 1.5);
    // 溫暖燈罩
    final shadePath = Path()
      ..moveTo(lampPos.dx - 5, lampPos.dy - 8)
      ..lineTo(lampPos.dx + 5, lampPos.dy - 8)
      ..lineTo(lampPos.dx + 3, lampPos.dy - 14)
      ..lineTo(lampPos.dx - 3, lampPos.dy - 14)
      ..close();
    canvas.drawPath(shadePath, Paint()..color = const Color(0xFFFEF08A));

    // 投射向下的柔和暖黃光錐 (Warm Light Cone)
    final conePath = Path()
      ..moveTo(lampPos.dx, lampPos.dy - 8)
      ..lineTo(lampPos.dx - 18, lampPos.dy + 8)
      ..lineTo(lampPos.dx + 18, lampPos.dy + 8)
      ..close();
    canvas.drawPath(
      conePath,
      Paint()
        ..shader = RadialGradient(
          center: Alignment.topCenter,
          radius: 0.85,
          colors: [
            const Color(0xFFFEF08A).withValues(alpha: 0.45),
            const Color(0xFFFDE047).withValues(alpha: 0.15),
            const Color(0xFFF59E0B).withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(lampPos.dx - 18, lampPos.dy - 8, 36, 16)),
    );
  }

  // --- 雙門拉絲金屬小冰箱 (gx: 1.5, gy: 1.5) ---
  void _drawIsometricFridge(Canvas canvas, Offset p) {
    const w = 32.0;
    const d = 32.0;
    const h = 54.0;

    // 拉絲金屬冰箱主體 (上下分界線、鍍鉻門把、彩色便利貼)
    _draw3DBox(canvas, p, w, d, h, const Color(0xFF475569), const Color(0xFF334155), const Color(0xFF94A3B8));

    // 上下冷凍/冷藏門分界線
    final splitY = p.dy - 35;
    canvas.drawLine(Offset(p.dx - w / 2, splitY - 4), Offset(p.dx, splitY + 4), Paint()..color = const Color(0xFF1E293B)..strokeWidth = 2.0);

    // 鍍鉻長門把
    final handlePaint = Paint()..color = const Color(0xFFE2E8F0)..strokeWidth = 1.8..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(p.dx - 4, splitY - 12), Offset(p.dx - 4, splitY - 6), handlePaint);
    canvas.drawLine(Offset(p.dx - 4, splitY + 8), Offset(p.dx - 4, splitY + 22), handlePaint);

    // 冰箱上貼的彩色便利貼 (Post-it Notes & Round Magnet)
    canvas.drawRect(Rect.fromLTWH(p.dx - 12, splitY - 12, 4.5, 4.5), Paint()..color = const Color(0xFFFDE047)); // 黃便利貼
    canvas.drawRect(Rect.fromLTWH(p.dx - 7, splitY - 14, 4.0, 4.0), Paint()..color = const Color(0xFFF43F5E)); // 粉紅便利貼
    canvas.drawCircle(Offset(p.dx - 10, splitY - 13), 0.8, Paint()..color = const Color(0xFF0284C7)); // 圓形磁鐵
  }

  // --- 門口編織流蘇迎賓踏墊 (Doormat with Fringes) ---
  void _drawDoormat(Canvas canvas, Offset p) {
    // 踏墊主體 (橄欖綠編織菱格紋)
    _drawDiamondTile(canvas, p, const Color(0xFF15803D), const Color(0xFF166534));
    // 內嵌幾何菱形邊框
    final path = Path()
      ..moveTo(p.dx, p.dy - tileH / 3)
      ..lineTo(p.dx + tileW / 3, p.dy)
      ..lineTo(p.dx, p.dy + tileH / 3)
      ..lineTo(p.dx - tileW / 3, p.dy)
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xFF166534)..style = PaintingStyle.stroke..strokeWidth = 1.2);

    // 邊緣精細流蘇 (Fringes)
    final fringePaint = Paint()..color = const Color(0xFFFEF08A).withValues(alpha: 0.8)..strokeWidth = 1.0;
    for (double fx = p.dx - tileW / 2; fx <= p.dx; fx += 3.5) {
      final fy = p.dy + (fx - (p.dx - tileW / 2)) * (tileH / tileW);
      canvas.drawLine(Offset(fx, fy), Offset(fx - 2, fy + 2), fringePaint);
    }
  }

  // ============================================================================
  // 空間 3: CITY MART 超商內部精細化 (Store Diorama)
  // ============================================================================
  void _paintStore(Canvas canvas, double ox, double oy) {
    const size = 8;

    // --- 1. 拋光高光白色大磁磚地 (Polished High-Gloss Tiles) ---
    for (int gy = 0; gy < size; gy++) {
      for (int gx = 0; gx < size; gx++) {
        final p = _iso(gx.toDouble(), gy.toDouble(), ox, oy);
        final tileColor = ((gx + gy) % 2 == 0) ? const Color(0xFFF8FAFC) : const Color(0xFFF1F5F9);
        _drawDiamondTile(canvas, p, tileColor, const Color(0xFFE2E8F0));

        // 磁磚拋光高光環境反光折線 (Glossy Specular Highlights)
        if ((gx + gy) % 3 == 0) {
          final glarePaint = Paint()..color = Colors.white.withValues(alpha: 0.75)..strokeWidth = 1.5;
          canvas.drawLine(Offset(p.dx - 12, p.dy), Offset(p.dx, p.dy - 6), glarePaint);
        }
      }
    }

    // --- 2. 超商牆面 (藍橘速度裝飾線) ---
    _drawRoomWalls(canvas, ox, oy, size, const Color(0xFF1E293B), const Color(0xFF0F172A));

    // 牆面企業雙色裝飾飾條 (CITY MART 橘色與亮藍色彩帶)
    final leftCorner = _iso(0, 0, ox, oy);
    final backRight = _iso(size.toDouble(), 0, ox, oy);
    final frontLeft = _iso(0, size.toDouble(), ox, oy);

    const stripeYOffset = 42.0;
    final blueLine = Paint()..color = const Color(0xFF0284C7)..strokeWidth = 2.5;
    final orangeLine = Paint()..color = const Color(0xFFF97316)..strokeWidth = 2.5;

    canvas.drawLine(Offset(frontLeft.dx, frontLeft.dy - stripeYOffset), Offset(leftCorner.dx, leftCorner.dy - stripeYOffset), blueLine);
    canvas.drawLine(Offset(frontLeft.dx, frontLeft.dy - stripeYOffset + 3), Offset(leftCorner.dx, leftCorner.dy - stripeYOffset + 3), orangeLine);
    canvas.drawLine(Offset(leftCorner.dx, leftCorner.dy - stripeYOffset), Offset(backRight.dx, backRight.dy - stripeYOffset), blueLine);
    canvas.drawLine(Offset(leftCorner.dx, leftCorner.dy - stripeYOffset + 3), Offset(backRight.dx, backRight.dy - stripeYOffset + 3), orangeLine);

    // --- 3. 雙門透光飲料冷藏展示櫃 (gx: 1.5, gy: 1.5) ---
    _drawIsometricCooler(canvas, _iso(1.5, 1.5, ox, oy));

    // --- 4. 三層零食陳列島架 (gx: 3.5, gy: 3.0) ---
    _drawIsometricShelf(canvas, _iso(3.5, 3.0, ox, oy));

    // --- 5. 木質收銀櫃台與 POS 機 (gx: 5.0, gy: 2.5) ---
    _drawIsometricCounter(canvas, _iso(5.0, 2.5, ox, oy));

    // --- 6. 進貨紙箱棧板 (gx: 1.5, gy: 5.0) ---
    _drawIsometricPallet(canvas, _iso(1.5, 5.0, ox, oy));
  }

  // --- 雙門透光飲料冷藏展示櫃 (雙門透光、頂部 COLD DRINKS 燈箱、4 層繽紛飲料罐) ---
  void _drawIsometricCooler(Canvas canvas, Offset p) {
    const w = 46.0;
    const d = 32.0;
    const h = 72.0;

    // 櫃體外殼
    _draw3DBox(canvas, p, w, d, h, const Color(0xFF1E3A8A), const Color(0xFF0F172A), const Color(0xFF3B82F6));

    // 頂部藍色發光招牌「COLD DRINKS」
    final signCenter = Offset(p.dx - 6, p.dy - h + 10);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: signCenter, width: 34, height: 11), const Radius.circular(2)),
      Paint()..color = const Color(0xFF0284C7),
    );
    final coolerTp = TextPainter(
      text: const TextSpan(
        text: 'COLD DRINKS',
        style: TextStyle(color: Colors.white, fontSize: 5.2, fontWeight: FontWeight.w900, letterSpacing: 0.2),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    coolerTp.paint(canvas, Offset(signCenter.dx - coolerTp.width / 2, signCenter.dy - coolerTp.height / 2));

    // 雙門透明玻璃門展示區 (內有 4 層整齊陳列的繽紛飲料罐)
    final glassRect = Rect.fromLTWH(p.dx - 22, p.dy - h + 18, 32, 42);
    // 櫃內明亮冰藍底光
    canvas.drawRect(glassRect, Paint()..color = const Color(0xFFE0F2FE));

    // 4 層陳列架與各色飲料罐
    final drinkColors = [
      const Color(0xFFEF4444), // 紅色可樂 (Coca-Cola)
      const Color(0xFF10B981), // 綠色雪碧 (Sprite)
      const Color(0xFFF97316), // 橘色芬達 (Orange)
      const Color(0xFF0284C7), // 藍色運動飲料 (Pocari)
    ];

    for (int tier = 0; tier < 4; tier++) {
      final shelfY = glassRect.top + tier * 10.0 + 8.0;
      // 白色層架分隔線
      canvas.drawLine(Offset(glassRect.left, shelfY), Offset(glassRect.right, shelfY), Paint()..color = const Color(0xFF94A3B8)..strokeWidth = 1.0);

      // 整齊排列的小飲料罐
      final canCol = drinkColors[tier];
      for (double cx = glassRect.left + 3; cx < glassRect.right - 2; cx += 5.5) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx, shelfY - 3.5), width: 3.5, height: 6.5), const Radius.circular(1.0)),
          Paint()..color = canCol,
        );
        // 金屬銀色拉環頂蓋
        canvas.drawRect(Rect.fromLTWH(cx - 1.5, shelfY - 7.0, 3.0, 1.0), Paint()..color = const Color(0xFFCBD5E1));
      }
    }

    // 透明玻璃高光反光條 (Diagonal Glass Sheen)
    final glarePaint = Paint()..color = Colors.white.withValues(alpha: 0.45)..strokeWidth = 1.5;
    canvas.drawLine(Offset(glassRect.left + 5, glassRect.bottom - 4), Offset(glassRect.left + 16, glassRect.top + 2), glarePaint);
    canvas.drawLine(Offset(glassRect.left + 18, glassRect.bottom - 4), Offset(glassRect.right - 4, glassRect.top + 10), glarePaint);

    // 玻璃雙門銀色把手與門框
    canvas.drawRect(glassRect, Paint()..color = const Color(0xFF64748B)..style = PaintingStyle.stroke..strokeWidth = 1.5);
    canvas.drawLine(Offset(glassRect.center.dx, glassRect.top), Offset(glassRect.center.dx, glassRect.bottom), Paint()..color = const Color(0xFF64748B)..strokeWidth = 1.2);
    canvas.drawLine(Offset(glassRect.center.dx - 2, glassRect.center.dy - 6), Offset(glassRect.center.dx - 2, glassRect.center.dy + 6), Paint()..color = const Color(0xFFE2E8F0)..strokeWidth = 1.5);
    canvas.drawLine(Offset(glassRect.center.dx + 2, glassRect.center.dy - 6), Offset(glassRect.center.dx + 2, glassRect.center.dy + 6), Paint()..color = const Color(0xFFE2E8F0)..strokeWidth = 1.5);
  }

  // --- 三層零食陳列島架 (金屬側架、傾斜層板、彩色洋芋片包裝) ---
  void _drawIsometricShelf(Canvas canvas, Offset p) {
    const w = 52.0;
    const d = 30.0;
    const h = 46.0;

    // 金屬主結構黑框架
    _draw3DBox(canvas, p, w, d, h, const Color(0xFF1E293B), const Color(0xFF0F172A), const Color(0xFF334155));

    // 3 層傾斜壓克力層板與繽紛零食包 (紅/黃/紫/綠洋芋片)
    final snackColors = [
      [const Color(0xFFEF4444), const Color(0xFFFBBF24), const Color(0xFFA855F7), const Color(0xFF10B981)],
      [const Color(0xFFF97316), const Color(0xFF38BDF8), const Color(0xFFEF4444), const Color(0xFFFBBF24)],
      [const Color(0xFFA855F7), const Color(0xFF10B981), const Color(0xFFF97316), const Color(0xFFEF4444)],
    ];

    for (int tier = 0; tier < 3; tier++) {
      final shelfY = p.dy - h + 12 + tier * 11.0;
      // 橘金壓克力層板
      canvas.drawLine(Offset(p.dx - 22, shelfY - 4), Offset(p.dx + 12, shelfY + 8), Paint()..color = const Color(0xFFF97316)..strokeWidth = 2.0);

      // 陳列的立體幾何零食袋
      final rowColors = snackColors[tier];
      for (int i = 0; i < rowColors.length; i++) {
        final t = i / (rowColors.length - 1);
        final sx = p.dx - 18 + t * 24;
        final sy = shelfY - 5 + t * 9;
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(sx, sy), width: 6.0, height: 7.0), const Radius.circular(1.0)),
          Paint()..color = rowColors[i],
        );
      }
    }
  }

  // --- 木質收銀櫃台 (天然橡木櫃身、白色大理石檯面、立體 POS 螢幕與綠色介面) ---
  void _drawIsometricCounter(Canvas canvas, Offset p) {
    const w = 52.0;
    const d = 36.0;
    const h = 34.0;

    // 天然橡木櫃身 (Vertical Wood Slats)
    _draw3DBox(canvas, p, w, d, h, const Color(0xFF78350F), const Color(0xFF92400E), const Color(0xFFF1F5F9));

    // 白色大理石檯面高光與倒角 (Polished Marble Countertop)
    final marbleTop = Path()
      ..moveTo(p.dx, p.dy - h - d / 4)
      ..lineTo(p.dx + w / 2 + 1, p.dy - h)
      ..lineTo(p.dx, p.dy - h + d / 4 + 1)
      ..lineTo(p.dx - w / 2 - 1, p.dy - h)
      ..close();
    canvas.drawPath(marbleTop, Paint()..color = Colors.white);
    canvas.drawPath(marbleTop, Paint()..color = const Color(0xFFCBD5E1)..style = PaintingStyle.stroke..strokeWidth = 1.0);

    // 立體 POS 機與綠色收款界面螢幕
    final posBase = Offset(p.dx - 4, p.dy - h);
    // POS 機支架與黑色底座
    canvas.drawRect(Rect.fromCenter(center: Offset(posBase.dx, posBase.dy - 3), width: 8, height: 5), Paint()..color = const Color(0xFF0F172A));
    // POS 螢幕傾斜立體面
    final screenPath = Path()
      ..moveTo(posBase.dx - 9, posBase.dy - 6)
      ..lineTo(posBase.dx + 5, posBase.dy - 2)
      ..lineTo(posBase.dx + 5, posBase.dy - 17)
      ..lineTo(posBase.dx - 9, posBase.dy - 21)
      ..close();
    canvas.drawPath(screenPath, Paint()..color = const Color(0xFF1E293B));

    // 綠色收款結帳界面「PAY $150」
    final screenInner = Path()
      ..moveTo(posBase.dx - 8, posBase.dy - 8)
      ..lineTo(posBase.dx + 4, posBase.dy - 4)
      ..lineTo(posBase.dx + 4, posBase.dy - 16)
      ..lineTo(posBase.dx - 8, posBase.dy - 20)
      ..close();
    canvas.drawPath(screenInner, Paint()..color = const Color(0xFF10B981));
    // 螢幕數據線
    canvas.drawLine(Offset(posBase.dx - 6, posBase.dy - 16), Offset(posBase.dx + 2, posBase.dy - 13), Paint()..color = Colors.white..strokeWidth = 1.2);
    canvas.drawLine(Offset(posBase.dx - 6, posBase.dy - 12), Offset(posBase.dx, posBase.dy - 10), Paint()..color = const Color(0xFFD1FAE5)..strokeWidth = 1.0);

    // 條碼掃描槍與底座 (Barcode Scanner)
    canvas.drawCircle(Offset(posBase.dx + 12, posBase.dy - 4), 2.2, Paint()..color = const Color(0xFF0F172A));
    canvas.drawLine(Offset(posBase.dx + 12, posBase.dy - 4), Offset(posBase.dx + 15, posBase.dy - 9), Paint()..color = const Color(0xFF38BDF8)..strokeWidth = 1.8);
  }

  // --- 物流木棧板與紙箱 (實體木條縫隙、封箱膠帶條紋、白色條碼標籤) ---
  void _drawIsometricPallet(Canvas canvas, Offset p) {
    // 1. 實體木板條木棧板 (Wooden Pallet with visible slat gaps & forklift holes)
    const palletW = 46.0;
    const palletD = 46.0;
    const palletH = 7.0;

    // 棧板底座支撐木方 (Forklift Tunnels)
    _draw3DBox(canvas, p, palletW, palletD, palletH, const Color(0xFF78350F), const Color(0xFF92400E), const Color(0xFFB45309));
    // 頂部 4 根木條間隔縫隙
    final slatPaint = Paint()..color = const Color(0xFF451A03)..strokeWidth = 1.2;
    for (double off = -12; off <= 12; off += 8.0) {
      canvas.drawLine(Offset(p.dx + off - 14, p.dy - palletH + off * 0.5 - 7), Offset(p.dx + off + 14, p.dy - palletH + off * 0.5 + 7), slatPaint);
    }

    // 2. 堆疊 3 個瓦楞紙箱 (Stacked Cardboard Boxes)
    // 底層左箱
    final box1P = Offset(p.dx - 8, p.dy - palletH - 2);
    _drawCardboardBox(canvas, box1P, 22, 22, 18);

    // 底層右箱
    final box2P = Offset(p.dx + 12, p.dy - palletH + 2);
    _drawCardboardBox(canvas, box2P, 20, 20, 16);

    // 頂層錯落交疊紙箱
    final box3P = Offset(p.dx - 1, p.dy - palletH - 19);
    _drawCardboardBox(canvas, box3P, 22, 22, 17);
  }

  // --- 瓦楞紙箱繪製 (棕色封箱膠帶條紋與白色物流條碼標籤) ---
  void _drawCardboardBox(Canvas canvas, Offset p, double w, double d, double h) {
    _draw3DBox(canvas, p, w, d, h, const Color(0xFFB45309), const Color(0xFFD97706), const Color(0xFFF59E0B));

    // 棕色十字封箱膠帶條紋 (Packing Tape)
    final tapeTop = Paint()..color = const Color(0xFF78350F)..strokeWidth = 2.2;
    canvas.drawLine(Offset(p.dx - w / 4, p.dy - h - d / 8), Offset(p.dx + w / 4, p.dy - h + d / 8), tapeTop);

    // 白色物流條碼標籤 (White Shipping Label with Barcode)
    final labelP = Offset(p.dx - w / 4 + 2, p.dy - h / 2 - 2);
    canvas.drawRect(Rect.fromCenter(center: labelP, width: 6.0, height: 4.5), Paint()..color = Colors.white);
    // 條碼黑色細線
    canvas.drawLine(Offset(labelP.dx - 2, labelP.dy - 1), Offset(labelP.dx - 2, labelP.dy + 1), Paint()..color = Colors.black87..strokeWidth = 0.6);
    canvas.drawLine(Offset(labelP.dx, labelP.dy - 1), Offset(labelP.dx, labelP.dy + 1), Paint()..color = Colors.black87..strokeWidth = 0.6);
    canvas.drawLine(Offset(labelP.dx + 2, labelP.dy - 1), Offset(labelP.dx + 2, labelP.dy + 1), Paint()..color = Colors.black87..strokeWidth = 0.6);
  }

  // ============================================================================
  // 繪圖幾何核心輔助函式
  // ============================================================================
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

  void _drawRoomWalls(Canvas canvas, double ox, double oy, int size, Color col1, Color col2) {
    final leftCorner = _iso(0, 0, ox, oy);
    final backRight = _iso(size.toDouble(), 0, ox, oy);
    final frontLeft = _iso(0, size.toDouble(), ox, oy);

    final leftWall = Path()
      ..moveTo(frontLeft.dx, frontLeft.dy)
      ..lineTo(leftCorner.dx, leftCorner.dy)
      ..lineTo(leftCorner.dx, leftCorner.dy - 78)
      ..lineTo(frontLeft.dx, frontLeft.dy - 78)
      ..close();
    canvas.drawPath(leftWall, Paint()..color = col1);

    final rightWall = Path()
      ..moveTo(leftCorner.dx, leftCorner.dy)
      ..lineTo(backRight.dx, backRight.dy)
      ..lineTo(backRight.dx, backRight.dy - 78)
      ..lineTo(leftCorner.dx, leftCorner.dy - 78)
      ..close();
    canvas.drawPath(rightWall, Paint()..color = col2);
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

  // ============================================================================
  // 角色 7: 【主角精細化模型 (Player Character)】
  // ============================================================================
  void _paintPlayer(Canvas canvas, double ox, double oy) {
    final p = _iso(playerGx, playerGy, ox, oy);

    // 1. 腳下雙層真實投影陰影 (Dual-Layer Ambient Occlusion Shadow)
    canvas.drawOval(
      Rect.fromCenter(center: Offset(p.dx, p.dy + 4), width: 26, height: 12),
      Paint()..color = Colors.black.withValues(alpha: 0.45),
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(p.dx, p.dy + 4), width: 14, height: 7),
      Paint()..color = Colors.black.withValues(alpha: 0.35),
    );

    // 2. 邁步動畫偏移 (Bobbing, Leg swing, Arm stride)
    final legSwing = isMoving ? math.sin(walkCycle) * 5.0 : 0.0;
    final armSwing = isMoving ? math.cos(walkCycle) * 4.0 : 0.0;
    final bobbing = isMoving ? (math.cos(walkCycle * 2) * 1.5).abs() : 0.0;

    final bodyY = p.dy - 23 - bobbing;

    // 3. 雙腿與皮鞋 (深色褲子與立體黑色皮鞋)
    final legPaint = Paint()..color = const Color(0xFF1E293B)..strokeWidth = 3.6..strokeCap = StrokeCap.round;
    final shoePaint = Paint()..color = const Color(0xFF09090B);

    // 左腿與左鞋
    final lFootX = p.dx - 3 - legSwing;
    final lFootY = p.dy;
    canvas.drawLine(Offset(p.dx - 3, p.dy - 12), Offset(lFootX, lFootY), legPaint);
    canvas.drawOval(Rect.fromCenter(center: Offset(lFootX, lFootY + 1), width: 6.0, height: 3.5), shoePaint);

    // 右腿與右鞋
    final rFootX = p.dx + 3 + legSwing;
    final rFootY = p.dy;
    canvas.drawLine(Offset(p.dx + 3, p.dy - 12), Offset(rFootX, rFootY), legPaint);
    canvas.drawOval(Rect.fromCenter(center: Offset(rFootX, rFootY + 1), width: 6.0, height: 3.5), shoePaint);

    // 4. 軀幹：時尚風衣外套 (Trench Coat with Lapels & Belt)
    final coatBody = Path()
      ..moveTo(p.dx - 8, bodyY - 14)
      ..lineTo(p.dx + 8, bodyY - 14)
      ..lineTo(p.dx + 9, bodyY + 5)
      ..lineTo(p.dx - 9, bodyY + 5)
      ..close();
    canvas.drawPath(coatBody, Paint()..color = const Color(0xFFB45309)); // 駝色風衣

    // 風衣領口 (Lapel) 與腰帶 (Belt with Brass Buckle)
    final lapelPaint = Paint()..color = const Color(0xFF92400E)..strokeWidth = 1.4;
    canvas.drawLine(Offset(p.dx - 6, bodyY - 14), Offset(p.dx, bodyY - 5), lapelPaint);
    canvas.drawLine(Offset(p.dx + 6, bodyY - 14), Offset(p.dx, bodyY - 5), lapelPaint);
    // 腰帶
    canvas.drawLine(Offset(p.dx - 8, bodyY - 2), Offset(p.dx + 8, bodyY - 2), Paint()..color = const Color(0xFF78350F)..strokeWidth = 2.0);
    canvas.drawRect(Rect.fromCenter(center: Offset(p.dx, bodyY - 2), width: 4.0, height: 3.5), Paint()..color = const Color(0xFFFBBF24)); // 金屬扣環

    // 5. 頭部、時尚髮型與生動朝向
    final headCenter = Offset(p.dx, bodyY - 22);
    // 臉部 (暖膚色)
    canvas.drawCircle(headCenter, 7.2, Paint()..color = const Color(0xFFFED7AA));
    // 深色立體髮型
    final hairPath = Path()
      ..addArc(Rect.fromCircle(center: Offset(headCenter.dx, headCenter.dy - 1), radius: 7.2), math.pi * 0.9, math.pi * 1.2)
      ..close();
    canvas.drawPath(hairPath, Paint()..color = const Color(0xFF451A03));

    // 五官眼神 (隨主角 8 方向朝向轉動)
    final eyeOffsetX = math.cos(facingAngle) * 3.2;
    final eyeOffsetY = math.sin(facingAngle) * 2.2;
    canvas.drawCircle(Offset(headCenter.dx + eyeOffsetX, headCenter.dy + eyeOffsetY), 1.3, Paint()..color = Colors.black87);

    // 6. 手臂擺動與手持物品
    if (carryState == PlayerCarryState.suitcase) {
      // 右手提復古皮革旅行皮箱 (隨行走擺動)
      final caseSwing = isMoving ? math.sin(walkCycle) * 4.0 : 0.0;
      final caseP = Offset(p.dx + 12, bodyY - 2 + caseSwing);

      // 皮箱本體 (深棕色皮革)
      final caseRect = Rect.fromCenter(center: caseP, width: 16, height: 11);
      canvas.drawRRect(RRect.fromRectAndRadius(caseRect, const Radius.circular(2.0)), Paint()..color = const Color(0xFF78350F));

      // 4 個黃銅金屬包角 (Corner Protectors)
      final brassPaint = Paint()..color = const Color(0xFFFBBF24);
      canvas.drawCircle(Offset(caseRect.left + 1.5, caseRect.top + 1.5), 1.2, brassPaint);
      canvas.drawCircle(Offset(caseRect.right - 1.5, caseRect.top + 1.5), 1.2, brassPaint);
      canvas.drawCircle(Offset(caseRect.left + 1.5, caseRect.bottom - 1.5), 1.2, brassPaint);
      canvas.drawCircle(Offset(caseRect.right - 1.5, caseRect.bottom - 1.5), 1.2, brassPaint);

      // 雙黃銅搭扣 (Latches)
      canvas.drawRect(Rect.fromCenter(center: Offset(caseP.dx - 3, caseP.dy), width: 1.5, height: 3), brassPaint);
      canvas.drawRect(Rect.fromCenter(center: Offset(caseP.dx + 3, caseP.dy), width: 1.5, height: 3), brassPaint);

      // 皮革金屬提把
      canvas.drawLine(Offset(caseP.dx - 4, caseP.dy - 6), Offset(caseP.dx + 4, caseP.dy - 6), Paint()..color = const Color(0xFFFBBF24)..strokeWidth = 1.5);

      // 左手自然擺動
      canvas.drawLine(Offset(p.dx - 8, bodyY - 10), Offset(p.dx - 10 - armSwing, bodyY + 2), Paint()..color = const Color(0xFFB45309)..strokeWidth = 3.0..strokeCap = StrokeCap.round);
    } else if (carryState == PlayerCarryState.box) {
      // 雙手高舉 2.5D 瓦楞紙箱 (帶封箱膠帶與白色物流條碼標籤)
      final boxP = Offset(p.dx, bodyY - 38);
      _drawCardboardBox(canvas, boxP, 24, 24, 18);

      // 雙手前伸抱箱
      final armPaint = Paint()..color = const Color(0xFFB45309)..strokeWidth = 3.2..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(p.dx - 8, bodyY - 10), Offset(p.dx - 10, bodyY - 26), armPaint);
      canvas.drawLine(Offset(p.dx + 8, bodyY - 10), Offset(p.dx + 10, bodyY - 26), armPaint);
    } else {
      // 雙臂自然交替擺動
      final armPaint = Paint()..color = const Color(0xFFB45309)..strokeWidth = 3.0..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(p.dx - 8, bodyY - 10), Offset(p.dx - 10 - armSwing, bodyY + 2), armPaint);
      canvas.drawLine(Offset(p.dx + 8, bodyY - 10), Offset(p.dx + 10 + armSwing, bodyY + 2), armPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _IsometricWorldPainter oldDelegate) => true;
}
