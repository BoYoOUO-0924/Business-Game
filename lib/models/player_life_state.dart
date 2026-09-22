import 'package:flutter/foundation.dart';

/// 主角生活與生理狀態 (Life Simulation Vital State)
class PlayerLifeState extends ChangeNotifier {
  // 生理三大核心指標 (0 ~ 100)
  double _energy = 94.0;
  double _hunger = 82.0;
  double _happiness = 75.0;

  // 個人現金 (開局為 0，領取叔叔贈金後變為 $10,000)
  double _personalCash = 0.0;

  // 主線劇情與開局狀態
  bool _hasClaimedUncleGift = false;
  bool _hasReadUncleMessage = false;
  bool _isCarryingSuitcase = true;

  // 當前任務目標
  String _currentQuest = '查看右下角手機：叔叔發來的新簡訊';

  // 時間 (第 1 天 19:14 黃昏初抵)
  int _day = 1;
  int _hour = 19;
  int _minute = 14;

  // Getters
  double get energy => _energy;
  double get hunger => _hunger;
  double get happiness => _happiness;
  double get personalCash => _personalCash;
  bool get hasClaimedUncleGift => _hasClaimedUncleGift;
  bool get hasReadUncleMessage => _hasReadUncleMessage;
  bool get isCarryingSuitcase => _isCarryingSuitcase;
  String get currentQuest => _currentQuest;
  int get day => _day;
  int get hour => _hour;
  int get minute => _minute;

  String get timeFormatted {
    final h = _hour.toString().padLeft(2, '0');
    final m = _minute.toString().padLeft(2, '0');
    return '第 $_day 天 $h:$m';
  }

  /// 標記已讀叔叔簡訊
  void markUncleMessageRead() {
    if (!_hasReadUncleMessage) {
      _hasReadUncleMessage = true;
      notifyListeners();
    }
  }

  /// 領取叔叔贈送的 $10,000 啟動金
  bool claimUncleGift() {
    if (_hasClaimedUncleGift) return false;
    _personalCash += 10000.0;
    _hasClaimedUncleGift = true;
    _currentQuest = '前往街角出租套房，在折疊床睡一覺 (體力回滿)';
    notifyListeners();
    return true;
  }

  /// 在出租公寓折疊床睡覺 (體力回滿，推進至隔日早晨 07:00)
  void sleepInApartment() {
    _energy = 100.0;
    _hunger = (_hunger - 25.0).clamp(10.0, 100.0);
    _happiness = (_happiness + 10.0).clamp(0.0, 100.0);
    _day += 1;
    _hour = 7;
    _minute = 0;
    _isCarryingSuitcase = false; // 皮箱放在公寓裡了
    _currentQuest = '查看手機地產 App 簽約租鋪，或前往老鋪兼職打工';
    notifyListeners();
  }

  /// 吃東西補充飽食度與幸福感
  void eatFood({required double restore, double cost = 0.0}) {
    if (_personalCash >= cost) {
      _personalCash -= cost;
      _hunger = (_hunger + restore).clamp(0.0, 100.0);
      _happiness = (_happiness + 5.0).clamp(0.0, 100.0);
      notifyListeners();
    }
  }

  /// 調整幸福度
  void adjustHappiness(double delta) {
    _happiness = (_happiness + delta).clamp(0.0, 100.0);
    notifyListeners();
  }

  /// 兼職打工 (消耗體力與時間，獲得即時現金)
  void takePartTimeShift({int hours = 4, double hourlyWage = 150.0}) {
    final totalPay = hours * hourlyWage;
    _personalCash += totalPay;
    _energy = (_energy - (hours * 12.0)).clamp(0.0, 100.0);
    _hunger = (_hunger - (hours * 8.0)).clamp(0.0, 100.0);
    _hour = (_hour + hours) % 24;
    notifyListeners();
  }

  /// 自然時間微幅代謝 (每次呼叫推進 1 分鐘)
  void tick() {
    _minute += 1;
    if (_minute >= 60) {
      _minute = 0;
      _hour = (_hour + 1) % 24;
      if (_hour == 0) _day++;

      // 每小時微幅消耗體力與飽食
      _energy = (_energy - 1.0).clamp(0.0, 100.0);
      _hunger = (_hunger - 1.2).clamp(0.0, 100.0);
    }
    notifyListeners();
  }
}
