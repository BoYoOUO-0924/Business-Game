import 'package:flutter_test/flutter_test.dart';
import 'package:business_sim/models/employee.dart';
import 'package:business_sim/providers/game_state.dart';

void main() {
  group('商品與貨源 (Catalog & Sourcing)', () {
    test('國民品牌商品庫', () {
      final g = GameState();
      for (final name in [
        '義美小泡芙',
        '麥香奶茶',
        '茶裏王',
        '滿漢大餐',
        '統一布丁',
        '黑松沙士',
        '奮起湖鐵路便當',
        '茶葉蛋',
        '現煮莊園特大熱拿鐵',
      ]) {
        expect(g.items.any((i) => i.name.contains(name)), isTrue, reason: '缺少 $name');
      }
    });

    test('批發商依門檻解鎖', () {
      final g = GameState();
      expect(g.suppliers.firstWhere((s) => s.id == 'lao_li').isUnlocked, isTrue);

      final uni = g.suppliers.firstWhere((s) => s.id == 'uni_president');
      expect(uni.isUnlocked, isFalse);
      g.company.totalRevenue = 130000.0;
      g.advanceHour();
      expect(uni.isUnlocked, isTrue);

      final imei = g.suppliers.firstWhere((s) => s.id == 'imei_foods');
      expect(imei.isUnlocked, isFalse);
      g.company.reputation = 75;
      g.advanceHour();
      expect(imei.isUnlocked, isTrue);
    });

    test('添購冷藏設備會解鎖中央廚房貨源', () {
      final g = GameState();
      final kitchen = g.suppliers.firstWhere((s) => s.id == 'central_kitchen');
      expect(kitchen.isUnlocked, isFalse);
      expect(g.purchaseFixture('drink_cooler'), isTrue);
      expect(kitchen.isUnlocked, isTrue);
    });

    test('品牌供應商未解鎖時，可回頭向萬用在地貨源老李進貨（原價）', () {
      final g = GameState();
      final puff = g.items.firstWhere((i) => i.id == 'imei_puff');
      expect(g.suppliers.firstWhere((s) => s.id == 'imei_foods').isUnlocked, isFalse);
      expect(g.effectiveSupplierFor(puff).id, 'lao_li');

      final laoLiPrice = g.effectiveUnitCost(puff);

      // 解鎖義美後改由品牌直營供貨，且更便宜
      g.company.reputation = 75;
      g.advanceHour();
      expect(g.effectiveSupplierFor(puff).id, 'imei_foods');
      expect(g.effectiveUnitCost(puff), lessThan(laoLiPrice));
    });
  });

  group('主線章節與成就 (Chapters & Quests)', () {
    test('章節目標描述與實際門檻一致', () {
      final g = GameState();
      // 第 4 章現金目標：舊版描述寫 $80,000 但實際只檢查 8000
      final cashGoal =
          g.chapters.last.goals.firstWhere((goal) => goal.metricType == 'cash');
      expect(cashGoal.description.contains('400,000'), isTrue);
      expect(cashGoal.targetValue, 400000);
    });

    test('達成章節目標後可領獎並推進至下一章', () {
      final g = GameState();
      final ch1 = g.chapters.first;
      for (final goal in ch1.goals) {
        goal.isAchieved = true;
      }
      g.advanceHour();
      expect(ch1.isCompleted, isTrue);

      final cashBefore = g.company.cash;
      g.claimChapterReward(1);
      expect(ch1.isClaimed, isTrue);
      expect(g.company.cash, cashBefore + ch1.rewardCash);
      expect(g.currentChapterIndex, 1);
    });

    test('成就達成與領獎', () {
      final g = GameState();
      final quest = g.quests.firstWhere((q) => q.id == 'q_hire_team');
      expect(quest.isCompleted, isFalse);

      while (g.hiredStaff.length < quest.targetValue) {
        if (g.candidatePool.isEmpty) g.advanceDay();
        if (!g.hireEmployee(g.candidatePool.first)) break;
      }
      g.advanceHour();
      expect(quest.isCompleted, isTrue);

      final cashBefore = g.company.cash;
      final repBefore = g.company.reputation;
      g.claimQuestReward(quest.id);
      expect(quest.isClaimed, isTrue);
      expect(g.company.cash, cashBefore + quest.rewardCash);
      expect(g.company.reputation, repBefore + quest.rewardReputation);
    });
  });

  group('人事 (HR)', () {
    test('招聘扣除培訓費並可指派班次', () {
      final g = GameState();
      final cashBefore = g.company.cash;
      final cand = g.candidatePool.first;

      expect(g.hireEmployee(cand), isTrue);
      expect(g.company.cash, cashBefore - 1500.0);

      g.assignShift(cand.id, ShiftType.night);
      expect(cand.assignedShift, ShiftType.night);
      expect(cand.isOnDuty(3), isTrue);
      expect(cand.isOnDuty(13), isFalse);
    });

    test('人力市場會持續有新應徵者上門', () {
      final g = GameState();
      while (g.candidatePool.isNotEmpty) {
        g.hireEmployee(g.candidatePool.first);
      }
      expect(g.candidatePool, isEmpty);

      g.advanceDay();
      expect(g.candidatePool, isNotEmpty,
          reason: '舊版候選池只有固定 3 人，聘完就再也請不到人');
    });

    test('值班才計薪', () {
      final g = GameState();
      // 白天有人值班 → 計薪
      expect(g.company.hour, 8);
      final wagesBefore = g.company.dailyWages;
      g.advanceHour(); // 09:00 早班值班中
      expect(g.company.dailyWages, greaterThan(wagesBefore));

      // 開局大夜班無人排班 → 不計薪
      while (g.company.hour != 1) {
        g.advanceHour(); // 跨過午夜，dailyWages 會重置
      }
      final wagesAtNight = g.company.dailyWages;
      g.advanceHour(); // 02:00 仍無人值班
      expect(g.company.dailyWages, wagesAtNight, reason: '大夜無人值班不該計薪');
    });
  });

  group('存檔 (Persistence)', () {
    test('存檔與讀檔可完整還原營運狀態', () {
      final a = GameState();
      a.purchaseFixture('drink_cooler');
      a.hireEmployee(a.candidatePool.first);
      for (var d = 0; d < 3; d++) {
        a.restockAllToCapacity();
        a.advanceDay();
      }

      final snapshot = a.toJson();

      final b = GameState();
      b.applyJson(snapshot);

      expect(b.company.day, a.company.day);
      expect(b.company.hour, a.company.hour);
      expect(b.company.cash, a.company.cash);
      expect(b.company.reputation, a.company.reputation);
      expect(b.company.totalUnitsSold, a.company.totalUnitsSold);
      expect(b.hiredStaff.length, a.hiredStaff.length);
      expect(b.fixtures.firstWhere((f) => f.id == 'drink_cooler').isPurchased, isTrue);
      expect(b.items.where((i) => i.isUnlocked).length,
          a.items.where((i) => i.isUnlocked).length);
      for (final item in a.items) {
        expect(b.items.firstWhere((i) => i.id == item.id).stock, item.stock,
            reason: '${item.name} 庫存未正確還原');
      }
    });

    test('讀檔後可繼續正常營業', () {
      final a = GameState();
      a.restockAllToCapacity();
      a.advanceDay();

      final b = GameState()..applyJson(a.toJson());
      final revenueBefore = b.company.totalRevenue;
      b.restockAllToCapacity();
      b.advanceDay();
      expect(b.company.totalRevenue, greaterThan(revenueBefore));
    });
  });
}
