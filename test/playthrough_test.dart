import 'package:flutter_test/flutter_test.dart';
import 'package:business_sim/models/employee.dart';
import 'package:business_sim/providers/game_state.dart';

/// 遊玩迴圈回歸測試。
///
/// 舊測試組有 16 個測試、全部通過、analyze 零警告 —— 但沒有任何一個
/// 測試真的把遊戲玩過一輪，所以「第 1 天庫存賣光後營收永遠歸零、
/// 商譽三天內觸底且無法回升」這種讓遊戲完全不能玩的問題一個都沒被抓到。
///
/// 這裡的測試會實際經營數十天，斷言遊戲維持在「可玩」的狀態。

/// 一位會看數字的玩家：留週轉金、逐步擴張、缺人才補人、每天補貨。
void playOneDay(GameState g) {
  for (final c in g.chapters) {
    if (c.isCompleted && !c.isClaimed) g.claimChapterReward(c.chapterNumber);
  }
  for (final q in g.quests) {
    if (q.isCompleted && !q.isClaimed) g.claimQuestReward(q.id);
  }

  final buffer = g.projectedDailyFixedCost * 5;

  for (final f in g.fixtures.where((f) => !f.isPurchased)) {
    if (g.company.cash - f.cost > buffer + 20000) {
      g.purchaseFixture(f.id);
      break;
    }
  }

  if (g.company.dailyServiceRate < 0.88 &&
      g.candidatePool.isNotEmpty &&
      g.company.cash > buffer + 15000) {
    const shifts = [ShiftType.morning, ShiftType.evening, ShiftType.night];
    final counts = {
      for (final s in shifts) s: g.hiredStaff.where((e) => e.assignedShift == s).length
    };
    final target = shifts.reduce((a, b) => counts[a]! <= counts[b]! ? a : b);
    if (counts[target]! < 3) {
      final cand = g.candidatePool.first;
      if (g.hireEmployee(cand)) g.assignShift(cand.id, target);
    }
  }

  g.restockAllToCapacity();
  g.advanceDay();
}

void main() {
  group('遊玩迴圈回歸測試 (Playthrough Regression)', () {
    test('認真經營 45 天：能持續獲利、不會倒閉、商譽站得住', () {
      final g = GameState();
      for (var d = 0; d < 45; d++) {
        playOneDay(g);
      }

      expect(g.isBankrupt, isFalse, reason: '正常經營不該倒閉');
      expect(g.company.cash, greaterThan(50000.0), reason: '應比開局資金更有錢');
      expect(g.company.reputation, greaterThanOrEqualTo(60),
          reason: '好好經營時商譽應站得住，而非單向下滑');

      // 最近 7 天至少要有多數天賺錢
      final profitableDays =
          g.company.netProfitHistory.where((n) => n > 0).length;
      expect(profitableDays, greaterThanOrEqualTo(4),
          reason: '穩定期應該多數日子是賺錢的');
    });

    test('營收不會在庫存賣光後永遠凍結', () {
      final g = GameState();
      for (var d = 0; d < 10; d++) {
        playOneDay(g);
      }
      final revenueAt10 = g.company.totalRevenue;
      final soldAt10 = g.company.totalUnitsSold;

      for (var d = 0; d < 10; d++) {
        playOneDay(g);
      }
      expect(g.company.totalRevenue, greaterThan(revenueAt10));
      expect(g.company.totalUnitsSold, greaterThan(soldAt10));
    });

    test('主線四章在合理天數內可全數達成', () {
      final g = GameState();
      final completedOn = <int, int>{};

      for (var d = 0; d < 60; d++) {
        playOneDay(g);
        for (final c in g.chapters) {
          if (c.isCompleted && !completedOn.containsKey(c.chapterNumber)) {
            completedOn[c.chapterNumber] = g.company.day;
          }
        }
      }

      expect(completedOn.keys.toSet(), {1, 2, 3, 4}, reason: '四章都應可達成');
      expect(completedOn[1]!, lessThan(completedOn[4]!),
          reason: '章節應該是循序推進而非同時達成');
      expect(completedOn[4]!, greaterThan(15),
          reason: '最終章不該在半個月內就輕鬆破關');
    });

    test('商品品項會隨設備投資逐步解鎖', () {
      final g = GameState();
      final atStart = g.items.where((i) => i.isUnlocked).length;
      for (var d = 0; d < 30; d++) {
        playOneDay(g);
      }
      final atEnd = g.items.where((i) => i.isUnlocked).length;
      expect(atStart, lessThan(atEnd));
      expect(atEnd, g.items.length, reason: '長期經營應能解鎖全部品項');
    });

    test('堆人不能刷銷量：把人全擠在同一班不會讓營收倍增', () {
      double revenueWith(int extraStaffOnMorning) {
        final g = GameState();
        for (var i = 0; i < extraStaffOnMorning; i++) {
          if (g.candidatePool.isEmpty) break;
          final c = g.candidatePool.first;
          g.hireEmployee(c);
          g.assignShift(c.id, ShiftType.morning);
        }
        for (var d = 0; d < 5; d++) {
          g.restockAllToCapacity();
          g.advanceDay();
        }
        return g.company.totalRevenue;
      }

      final lean = revenueWith(0);
      final stacked = revenueWith(4);

      // 舊版 staffEfficiency 是效率「加總」後直接乘進需求，
      // 5 個人擠同一班可以讓銷量變成 5 倍。
      expect(stacked, lessThan(lean * 1.6),
          reason: '增聘人手只該減少流失，不該線性放大需求');
    });

    test('忘記補貨會被明確警告，而不是默默沒生意', () {
      final g = GameState();
      for (var d = 0; d < 5; d++) {
        g.advanceDay(); // 完全不補貨
      }
      expect(
        g.businessLogs.any((l) => l.contains('缺貨流失')),
        isTrue,
        reason: '缺貨導致客人流失時應該明確告知玩家',
      );
    });
  });
}
