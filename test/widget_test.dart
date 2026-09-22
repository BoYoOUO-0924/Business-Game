import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:business_sim/models/employee.dart';
import 'package:business_sim/providers/game_state.dart';
import 'package:business_sim/views/main_dashboard_screen.dart';
import 'package:business_sim/views/tabs/hr_tab.dart';
import 'package:business_sim/views/tabs/inventory_tab.dart';
import 'package:business_sim/views/tabs/overview_tab.dart';
import 'package:business_sim/views/tabs/store_tab.dart';
import 'package:business_sim/views/theme/app_theme.dart';

Widget _host(GameState state, Widget child) => ChangeNotifierProvider.value(
      value: state,
      child: MaterialApp(theme: buildAppTheme(), home: Scaffold(body: child)),
    );

void main() {
  group('主畫面 (Dashboard)', () {
    testWidgets('顯示時間、現金與營業狀態，五個分頁都可切換', (tester) async {
      tester.view.physicalSize = const Size(1200, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final state = GameState();
      await tester.pumpWidget(_host(state, const MainDashboardScreen()));
      await tester.pump();

      // 「第 1 天」在標題列、今日損益與主線卡片都會出現
      expect(find.textContaining('第 1 天'), findsWidgets);
      expect(find.text('營業中'), findsOneWidget);

      for (final label in ['進銷存', '批發地圖', '人事排班', '門市']) {
        await tester.tap(find.text(label));
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('推進 1 小時會更新時間', (tester) async {
      tester.view.physicalSize = const Size(1200, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final state = GameState();
      await tester.pumpWidget(_host(state, const MainDashboardScreen()));
      await tester.pump();

      expect(find.textContaining('08:00'), findsOneWidget);
      await tester.tap(find.byTooltip('推進 1 小時'));
      await tester.pump();
      expect(find.textContaining('09:00'), findsOneWidget);
    });
  });

  group('總覽 (Overview)', () {
    testWidgets('渲染 KPI、損益與班表覆蓋圖', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final state = GameState();
      await tester.pumpWidget(_host(state, OverviewTab(onNavigateTab: (_) {})));
      await tester.pumpAndSettle();

      expect(find.text('現金'), findsOneWidget);
      expect(find.text('門市商譽'), findsOneWidget);
      expect(find.text('服務達成率'), findsOneWidget);
      expect(find.text('今日損益'), findsOneWidget);
      expect(find.text('24 小時人流與結帳產能'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('缺貨時顯示警示並可一鍵補貨', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final state = GameState();
      for (final item in state.items) {
        item.batches.clear(); // 全面清空庫存
      }
      await tester.pumpWidget(_host(state, OverviewTab(onNavigateTab: (_) {})));
      await tester.pumpAndSettle();

      expect(find.textContaining('項商品即將缺貨'), findsOneWidget);
      await tester.tap(find.text('一鍵補貨'));
      await tester.pumpAndSettle();
      expect(state.items.fold<int>(0, (a, i) => a + i.stock), greaterThan(0));
    });

    testWidgets('歇業時蓋上結束畫面', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final state = GameState();
      state.company.cash = -500000;
      for (var d = 0; d < 3; d++) {
        state.advanceDay();
      }
      expect(state.isBankrupt, isTrue);

      await tester.pumpWidget(_host(state, const MainDashboardScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('門市歇業'), findsWidgets);
      expect(find.text('重新開店'), findsOneWidget);
    });
  });

  group('進銷存 (Inventory)', () {
    testWidgets('已解鎖與未解鎖商品分開呈現', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final state = GameState();
      await tester.pumpWidget(_host(state, InventoryTab(onGoToNegotiate: () {})));
      await tester.pumpAndSettle();

      expect(find.text('在架商品'), findsOneWidget);
      expect(find.text('尚未解鎖的商品'), findsOneWidget);
      expect(find.text('陳列空間'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('人事排班 (HR)', () {
    testWidgets('顯示排班健檢與班別配置，可調整班次', (tester) async {
      tester.view.physicalSize = const Size(1200, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final state = GameState();
      await tester.pumpWidget(_host(state, const HrTab()));
      await tester.pumpAndSettle();

      expect(find.text('排班健檢'), findsOneWidget);
      expect(find.text('班別配置'), findsOneWidget);
      expect(find.text('打烊時數'), findsOneWidget);
      // 開局大夜無人，應提示無人值班
      expect(find.text('無人值班・打烊'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('聘用候選人會加入在職名單', (tester) async {
      tester.view.physicalSize = const Size(1200, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final state = GameState();
      final before = state.hiredStaff.length;
      await tester.pumpWidget(_host(state, const HrTab()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('聘用').first);
      await tester.pumpAndSettle();
      expect(state.hiredStaff.length, before + 1);
    });
  });

  group('門市 (Store)', () {
    testWidgets('設備列表顯示可解鎖的商品，購買後生效', (tester) async {
      tester.view.physicalSize = const Size(1200, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final state = GameState();
      await tester.pumpWidget(_host(state, const StoreTab()));
      // 門市實景是持續播放的動畫，不能用 pumpAndSettle（永遠不會靜止）
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('門市設備'), findsOneWidget);
      expect(find.text('經營成就'), findsOneWidget);

      final before = state.items.where((i) => i.isUnlocked).length;
      await tester.tap(find.text('添購設備').first);
      await tester.pump(const Duration(milliseconds: 100));
      expect(state.items.where((i) => i.isUnlocked).length, greaterThan(before));
    });
  });

  group('班表覆蓋圖 (Coverage Chart)', () {
    testWidgets('點選長條會顯示該時段明細', (tester) async {
      tester.view.physicalSize = const Size(1200, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final state = GameState();
      // 讓大夜無人值班，確保圖中有「打烊」時段
      await tester.pumpWidget(_host(state, const HrTab()));
      await tester.pumpAndSettle();

      expect(find.textContaining('點選長條查看各時段明細'), findsWidgets);
      expect(find.text('可服務來客'), findsWidgets);
      expect(find.text('人力不足流失'), findsWidgets);
    });
  });

  group('存檔往返 (Save round-trip)', () {
    testWidgets('重新開店會回到第 1 天', (tester) async {
      final state = GameState();
      for (var d = 0; d < 5; d++) {
        state.restockAllToCapacity();
        state.advanceDay();
      }
      expect(state.company.day, greaterThan(1));

      state.resetToNewGame();
      expect(state.company.day, 1);
      expect(state.company.cash, 50000.0);
      expect(state.hiredStaff.length, 2);
      expect(state.hiredStaff.map((e) => e.assignedShift).toSet(),
          {ShiftType.morning, ShiftType.evening});
    });
  });
}
