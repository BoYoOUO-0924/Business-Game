import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:business_sim/providers/game_state.dart';
import 'package:business_sim/services/audio_service.dart';
import 'package:business_sim/views/components/tycoon_phone_modal.dart';
import 'package:business_sim/views/main_dashboard_screen.dart';
import 'package:business_sim/views/screens/title_screen.dart';
import 'package:business_sim/views/tabs/city_gis_tab.dart';

void main() {
  setUpAll(() async {
    await AudioService().init(enabled: false);
  });

  group('都會商業大亨核心數值與決策系統 (Tycoon Simulation Engine)', () {
    test('初始五大都會商圈設定齊備，舊城幸福里已自持總店', () {
      final state = GameState();
      expect(state.districts.length, 5);

      final oldTown = state.districts.firstWhere((d) => d.id == 'old_town');
      expect(oldTown.isLeased, isTrue);
      expect(oldTown.branchStoreName, contains('幸福里'));
      expect(oldTown.monthlyRent, 3500.0);

      final techPark = state.districts.firstWhere((d) => d.id == 'tech_park');
      expect(techPark.isLeased, isFalse);
      expect(techPark.minReputationRequired, 55.0);
    });

    test('Fred 叔叔天使啟動金領取機制：+NT\$ 10,000 且不可重複領取', () {
      final state = GameState();
      final cashBefore = state.company.cash;

      expect(state.hasClaimedUncleGift, isFalse);
      expect(state.claimUncleGift(), isTrue);
      expect(state.company.cash, cashBefore + 10000.0);
      expect(state.hasClaimedUncleGift, isTrue);

      // 重複領取無效
      expect(state.claimUncleGift(), isFalse);
      expect(state.company.cash, cashBefore + 10000.0);
    });

    test('商圈租鋪擴張決策：檢查商譽門檻與資金扣除', () {
      final state = GameState();
      state.claimUncleGift(); // 補足資本

      // 科技園區需商譽 55 分，初始商譽 50 分應無法直接租賃
      state.company.reputation = 50;
      expect(state.leaseDistrict('tech_park', '矽谷一號旗艦店'), isFalse);

      // 商譽提升至 60 分且資金充足時，成功簽約租鋪
      state.company.reputation = 60;
      state.company.cash = 50000.0;
      expect(state.leaseDistrict('tech_park', '矽谷一號旗艦店'), isTrue);

      final techPark = state.districts.firstWhere((d) => d.id == 'tech_park');
      expect(techPark.isLeased, isTrue);
      expect(techPark.branchStoreName, '矽谷一號旗艦店');
      expect(state.company.cash, 50000.0 - techPark.depositRequired);
    });

    test('策劃商圈行銷大戰：扣除預算並生成全城客流倍增事件', () {
      final state = GameState();
      state.company.cash = 20000.0;

      state.launchMarketingCampaign(
        campaignName: '全店買一送一大促銷',
        cost: 3500.0,
        trafficMultiplier: 1.60,
        hours: 48,
      );

      expect(state.company.cash, 16500.0);
      expect(state.activeEvent, isNotNull);
      expect(state.activeEvent!.title, '全店買一送一大促銷');
      expect(state.activeEvent!.trafficMultiplier, 1.60);
      expect(state.activeEvent!.durationHours, 48);
    });

    test('時間流速控制與自動推進倍率 (1x, 3x, 8x)', () {
      final state = GameState();
      expect(state.isAutoPlaying, isFalse);
      expect(state.autoPlaySpeed, 1);

      state.setAutoPlaySpeed(2);
      expect(state.autoPlaySpeed, 2);

      state.setAutoPlaySpeed(3);
      expect(state.autoPlaySpeed, 3);

      state.toggleAutoPlay();
      expect(state.isAutoPlaying, isTrue);

      state.toggleAutoPlay();
      expect(state.isAutoPlaying, isFalse);
    });
  });

  group('商業大亨指揮中心與都會地圖介面測試 (Tycoon Command UI)', () {
    testWidgets('TitleScreen 開始商業大亨生涯直通指揮中心', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => GameState(),
          child: const MaterialApp(
            home: TitleScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('開始商業大亨生涯'), findsOneWidget);

      await tester.tap(find.textContaining('開始商業大亨生涯'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(MainDashboardScreen), findsOneWidget);
    });

    testWidgets('MainDashboardScreen 呈現 6 大決策分頁並可順暢切換至商圈擴張', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final state = GameState();

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: state,
          child: const MaterialApp(
            home: MainDashboardScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // 檢查導航列目的地
      expect(find.text('總覽'), findsOneWidget);
      expect(find.text('商圈擴張'), findsOneWidget);
      expect(find.text('進銷存'), findsOneWidget);
      expect(find.text('批發談判'), findsOneWidget);
      expect(find.text('人事排班'), findsOneWidget);
      expect(find.text('門市設備'), findsOneWidget);

      // 切換至商圈擴張分頁
      await tester.tap(find.text('商圈擴張'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(CityGisTab), findsOneWidget);
      expect(find.textContaining('都會五大核心商圈'), findsOneWidget);
      expect(find.textContaining('舊城幸福里'), findsOneWidget);
      expect(find.textContaining('高新矽谷園區'), findsOneWidget);
    });

    testWidgets('點擊公務手機按鈕彈出 SmartOS 並可領取 \$10,000 天使基金', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final state = GameState();
      final cashBefore = state.company.cash;

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: state,
          child: const MaterialApp(
            home: MainDashboardScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // 點擊公務手機圖示
      await tester.tap(find.byIcon(Icons.smartphone_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(TycoonPhoneModal), findsOneWidget);
      expect(find.textContaining('Fred 叔叔 (天使投資人)'), findsOneWidget);
      expect(find.textContaining('立即點擊兌現 (+NT\$ 10,000)'), findsOneWidget);

      // 點擊兌現
      await tester.tap(find.textContaining('立即點擊兌現 (+NT\$ 10,000)'));
      await tester.pump();

      expect(state.company.cash, cashBefore + 10000.0);
      expect(find.textContaining('✓ 已存入企業網銀'), findsOneWidget);
    });
  });
}
