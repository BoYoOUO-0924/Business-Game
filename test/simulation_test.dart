import 'package:flutter_test/flutter_test.dart';
import 'package:business_sim/models/employee.dart';
import 'package:business_sim/providers/game_state.dart';

void main() {
  group('營運模擬核心 (Simulation Core)', () {
    test('初始狀態：早晚班各一人、只有零食貨架上的商品可販售', () {
      final g = GameState();
      expect(g.company.cash, 50000.0);
      expect(g.company.day, 1);
      expect(g.hiredStaff.length, 2);
      expect(g.hiredStaff.map((e) => e.assignedShift).toSet(),
          {ShiftType.morning, ShiftType.evening});

      // 開局只購置了收銀台與零食貨架
      final purchased = g.fixtures.where((f) => f.isPurchased).map((f) => f.id).toSet();
      expect(purchased, {'cashier', 'snack_shelf'});

      // 因此只有掛在零食貨架上的商品能賣
      final sellable = g.items.where((i) => i.isUnlocked).toList();
      expect(sellable, isNotEmpty);
      expect(sellable.every((i) => i.requiredFixtureId == 'snack_shelf'), isTrue);
      expect(sellable.length, lessThan(g.items.length));
    });

    test('未購置陳列設備的商品不會被賣出，也不能進貨', () {
      final g = GameState();
      // 用非鮮食品項，才能確定庫存沒變是「沒賣出」而不是「沒腐壞」
      final tea = g.items.firstWhere((i) => i.id == 'chaliwon_tea');
      expect(tea.isUnlocked, isFalse, reason: '低溫冷藏櫃尚未購置');

      // 就算硬塞庫存也不該有人買走
      tea.addStock(50);
      final before = tea.stock;
      for (var i = 0; i < 24; i++) {
        g.advanceHour();
      }
      expect(tea.stock, before, reason: '未解鎖商品不應產生銷售');

      // 也不該能補貨
      expect(g.restockItem('chaliwon_tea', 10), isFalse);
      expect(g.businessLogs.any((l) => l.contains('需要先在門市添購')), isTrue);
    });

    test('購置設備會解鎖對應商品', () {
      final g = GameState();
      final before = g.items.where((i) => i.isUnlocked).length;
      expect(g.purchaseFixture('fresh_warmer'), isTrue);
      final after = g.items.where((i) => i.isUnlocked).length;
      expect(after, greaterThan(before));
      expect(g.items.firstWhere((i) => i.id == 'bento').isUnlocked, isTrue);
    });

    test('人流不受員工人數影響：加人只會提高結帳產能，不會憑空創造需求', () {
      final g = GameState();
      final baseline = g.projectedFootfall(12);

      for (final c in List.of(g.candidatePool)) {
        g.hireEmployee(c);
        g.assignShift(c.id, ShiftType.morning);
      }

      expect(g.projectedFootfall(12), baseline,
          reason: '來客數只由商譽、時段與市場事件決定');
      expect(g.checkoutCapacity(12), greaterThan(0));
    });

    test('結帳產能不足時客人會流失，並拉低商譽', () {
      final g = GameState();
      // 只留一位早班，且讓他極度疲勞以壓低產能
      for (final e in g.hiredStaff) {
        g.assignShift(e.id, e.assignedShift == ShiftType.morning
            ? ShiftType.morning
            : ShiftType.none);
      }
      for (final e in g.hiredStaff) {
        e.fatigue = 100;
      }
      // 備足庫存，確保流失來自結帳瓶頸而非缺貨
      g.restockAllToCapacity();

      while (g.company.hour != 12) {
        g.advanceHour();
      }
      final repBefore = g.company.reputation;
      for (var i = 0; i < 3; i++) {
        g.advanceHour(); // 12,13,14 都是尖峰
      }
      expect(g.company.dailyCustomersLost, greaterThan(0));
      expect(g.company.reputation, lessThanOrEqualTo(repBefore));
    });

    test('商譽是雙向的：服務水準良好時會回升', () {
      final g = GameState();
      // 大量人手 + 充足庫存 = 幾乎不流失客人
      for (final c in List.of(g.candidatePool)) {
        g.hireEmployee(c);
        g.assignShift(c.id, ShiftType.morning);
      }
      g.restockAllToCapacity();

      g.company.reputation = 50; // 從中間值起算，留出上升空間
      final before = g.company.reputation;
      while (g.company.hour != 8) {
        g.advanceHour();
      }
      for (var i = 0; i < 8; i++) {
        g.advanceHour();
      }
      expect(g.company.reputation, greaterThan(before),
          reason: '舊版商譽只會下降，永遠無法靠好好經營回升');
    });

    test('無人值班視為關店：沒有營收，但商譽不會崩盤', () {
      final g = GameState();
      for (final e in g.hiredStaff) {
        g.assignShift(e.id, ShiftType.none);
      }
      final repBefore = g.company.reputation;
      final cashBefore = g.company.cash;

      for (var i = 0; i < 12; i++) {
        g.advanceHour();
      }

      expect(g.company.dailyRevenue, 0);
      expect(g.company.cash, cashBefore, reason: '沒開店就沒有工資也沒有營收');
      expect(g.company.reputation, repBefore,
          reason: '不做 24 小時是策略選擇，不該被當成服務失誤懲罰');
    });

    test('疲勞與士氣會真正影響結帳產能', () {
      final g = GameState();
      final staff = g.hiredStaff.firstWhere((e) => e.assignedShift == ShiftType.morning);
      staff.fatigue = 0;
      staff.morale = 95;
      final fresh = staff.effectiveEfficiency;

      staff.fatigue = 95;
      staff.morale = 35;
      final worn = staff.effectiveEfficiency;

      expect(worn, lessThan(fresh), reason: '舊版 fatigue/morale 只是裝飾數字');
    });

    test('士氣見底的員工會離職', () {
      final g = GameState();
      final before = g.hiredStaff.length;
      while (g.company.hour != 23) {
        g.advanceHour();
      }
      for (final e in g.hiredStaff) {
        e.morale = 10;
      }
      g.advanceHour(); // 進入 00:00 觸發結算與離職判定
      expect(g.hiredStaff.length, lessThan(before));
      expect(g.businessLogs.any((l) => l.contains('提出辭呈')), isTrue);
    });
  });

  group('庫存與鮮食 (Inventory & Perishables)', () {
    test('鮮食以批次計算賞味期，補一件不會洗掉舊批次的時效', () {
      final g = GameState();
      g.purchaseFixture('fresh_warmer');
      final bento = g.items.firstWhere((i) => i.id == 'bento');
      bento.batches.clear();
      bento.addStock(40); // 第一批

      // 放置到接近賞味期
      for (var i = 0; i < bento.shelfLifeHours - 2; i++) {
        bento.ageOneHourAndDiscard();
      }
      final agedBefore = bento.oldestAgeHours;

      // 補 1 件新貨 —— 舊版會把 currentAgeHours 直接歸零
      bento.addStock(1);
      expect(bento.oldestAgeHours, agedBefore,
          reason: '新批次不該讓舊批次重新計算賞味期');

      // 舊批次到期後整批報廢，新批次留著
      bento.ageOneHourAndDiscard();
      final spoiled = bento.ageOneHourAndDiscard();
      expect(spoiled, greaterThan(0));
      expect(bento.stock, 1, reason: '只有過期的那一批該被報廢');
    });

    test('銷售採先進先出', () {
      final g = GameState();
      final item = g.items.firstWhere((i) => i.isUnlocked);
      item.batches.clear();
      item.addStock(10);
      item.ageOneHourAndDiscard(); // 第一批年齡 1
      item.addStock(10); // 第二批年齡 0

      item.consume(10);
      expect(item.stock, 10);
      expect(item.oldestAgeHours, 0, reason: '應先賣掉較舊的批次');
    });

    test('鮮食過期會計入損耗成本', () {
      final g = GameState();
      g.purchaseFixture('fresh_warmer');
      final bento = g.items.firstWhere((i) => i.id == 'bento');
      bento.retailPrice = 8888.0; // 貴到沒人買，確保是放到過期
      bento.addStock(30);

      for (var i = 0; i < bento.shelfLifeHours + 2; i++) {
        g.advanceHour();
      }
      expect(g.company.totalSpoilageCost, greaterThan(0));
      expect(g.businessLogs.any((l) => l.contains('鮮食報廢')), isTrue);
    });

    test('進貨受陳列設備容量限制，同設備上的商品共用容量', () {
      final g = GameState();
      final shelf = g.fixtures.firstWhere((f) => f.id == 'snack_shelf');
      final onShelf = g.items.where((i) => i.requiredFixtureId == 'snack_shelf').toList();

      // 先塞滿
      for (final item in onShelf) {
        final space = g.remainingShelfSpaceFor(item);
        if (space > 0) g.restockItem(item.id, space);
      }
      expect(g.shelfUsed('snack_shelf'), shelf.currentCapacity);

      // 滿了就進不了貨
      expect(g.restockItem(onShelf.first.id, 1), isFalse);
      expect(g.businessLogs.any((l) => l.contains('剩餘陳列空間')), isTrue);
    });

    test('升級設備可擴充陳列容量', () {
      final g = GameState();
      final shelf = g.fixtures.firstWhere((f) => f.id == 'snack_shelf');
      final before = shelf.currentCapacity;
      g.upgradeFixture('snack_shelf');
      expect(shelf.currentCapacity, greaterThan(before));
    });

    test('開局免費配置的設備升級費用不能是 0（否則可無限免費升級）', () {
      final g = GameState();
      final shelf = g.fixtures.firstWhere((f) => f.id == 'snack_shelf');
      expect(shelf.cost, 0, reason: '零食貨架開局即配備，購入成本本來就是 0');
      expect(shelf.upgradeCost, greaterThan(0),
          reason: '升級費用不該沿用購入成本的 0，否則能無限免費升級');

      final cashBefore = g.company.cash;
      g.upgradeFixture('snack_shelf');
      expect(g.company.cash, lessThan(cashBefore), reason: '升級應確實扣款');
    });

    test('一鍵補貨會保留週轉金，不會把現金燒光', () {
      final g = GameState();
      g.company.cash = g.projectedDailyFixedCost + 500;
      final reserve = g.projectedDailyFixedCost;
      g.restockAllToCapacity();
      expect(g.company.cash, greaterThanOrEqualTo(reserve - 0.01));
    });
  });

  group('財務與失敗條件 (Finance & Failure)', () {
    test('午夜結算扣租金並寫入歷史', () {
      final g = GameState();
      final rent = g.company.dailyRent;
      while (g.company.hour != 23) {
        g.advanceHour();
      }
      expect(g.company.day, 1);
      final cashBefore = g.company.cash;
      g.advanceHour(); // 進入 00:00 觸發結算
      expect(g.company.day, 2);
      expect(g.company.revenueHistory, isNotEmpty);
      expect(g.company.netProfitHistory, isNotEmpty);
      expect(cashBefore - g.company.cash, greaterThanOrEqualTo(rent - 0.01));
    });

    test('連續週轉不靈 3 天即歇業，且時間不再推進', () {
      final g = GameState();
      g.company.cash = -500000; // 深度負債，當日營收不足以轉正
      for (var d = 0; d < 3; d++) {
        g.advanceDay();
      }
      expect(g.isBankrupt, isTrue);
      final dayAtDeath = g.company.day;
      g.advanceDay();
      expect(g.company.day, dayAtDeath, reason: '歇業後不該還能繼續營業');
    });

    test('完全放著不管會倒閉，而不是永遠凍結', () {
      final g = GameState();
      for (var d = 0; d < 30 && !g.isBankrupt; d++) {
        g.advanceDay();
      }
      expect(g.isBankrupt, isTrue,
          reason: '舊版庫存賣光後營收永遠為 0，遊戲卡死但不會結束');
    });
  });
}
