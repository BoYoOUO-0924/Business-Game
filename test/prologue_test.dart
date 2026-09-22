import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:business_sim/models/player_life_state.dart';
import 'package:business_sim/services/audio_service.dart';
import 'package:business_sim/views/components/smart_phone_modal.dart';
import 'package:business_sim/views/screens/title_screen.dart';
import 'package:business_sim/views/screens/urban_game_screen.dart';

void main() {
  setUpAll(() async {
    // 確保在無頭測試環境關閉音效硬體
    await AudioService().init(enabled: false);
  });

  group('第一幕開局狀態機 (PlayerLifeState Model)', () {
    test('初始狀態符合初抵大都會的生理與背包指標', () {
      final life = PlayerLifeState();
      expect(life.energy, 94.0);
      expect(life.hunger, 82.0);
      expect(life.happiness, 75.0);
      expect(life.personalCash, 0.0);
      expect(life.hasClaimedUncleGift, isFalse);
      expect(life.hasReadUncleMessage, isFalse);
      expect(life.isCarryingSuitcase, isTrue);
      expect(life.day, 1);
      expect(life.hour, 19);
      expect(life.minute, 14);
      expect(life.timeFormatted, '第 1 天 19:14');
      expect(life.currentQuest, contains('查看右下角手機'));
    });

    test('領取叔叔贈金流程：+NT\$10,000 且不可重複領取，任務目標推進', () {
      final life = PlayerLifeState();
      expect(life.claimUncleGift(), isTrue);
      expect(life.personalCash, 10000.0);
      expect(life.hasClaimedUncleGift, isTrue);
      expect(life.currentQuest, contains('前往街角出租套房'));

      // 重複領取無效
      expect(life.claimUncleGift(), isFalse);
      expect(life.personalCash, 10000.0);
    });

    test('在出租公寓折疊床睡覺：體力回滿、放下皮箱、推進至隔日早晨 07:00', () {
      final life = PlayerLifeState();
      life.claimUncleGift();
      life.sleepInApartment();

      expect(life.energy, 100.0);
      expect(life.day, 2);
      expect(life.hour, 7);
      expect(life.minute, 0);
      expect(life.isCarryingSuitcase, isFalse);
      expect(life.currentQuest, contains('簽約租鋪'));
    });

    test('進食與兼職打工機制正常', () {
      final life = PlayerLifeState();
      life.claimUncleGift();

      // 吃個超商便當 $80，飽食 +20
      final cashBefore = life.personalCash;
      final hungerBefore = life.hunger;
      life.eatFood(restore: 20, cost: 80);
      expect(life.personalCash, cashBefore - 80);
      expect(life.hunger, (hungerBefore + 20).clamp(0.0, 100.0));

      // 兼職打工 4 小時，每小時 150
      final cashBeforeJob = life.personalCash;
      final energyBeforeJob = life.energy;
      life.takePartTimeShift(hours: 4, hourlyWage: 150);
      expect(life.personalCash, cashBeforeJob + 600);
      expect(life.energy, energyBeforeJob - 48);
    });
  });

  group('開局畫面與手機互動 (TitleScreen & UrbanGameScreen Widget)', () {
    testWidgets('標題畫面正常渲染主副標題與開始生涯按鈕', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const MaterialApp(
          home: TitleScreen(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('都會商雄'), findsOneWidget);
      expect(find.text('URBAN AMBITION : RETAIL TYCOON'), findsOneWidget);
      expect(find.textContaining('開始新生涯'), findsOneWidget);
      expect(find.textContaining('進入連鎖超商後台'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('都會俯視街景渲染 HUD 與手機未讀提示', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final life = PlayerLifeState();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UrbanGameScreen(playerLife: life),
          ),
        ),
      );
      // 門市街景包含背景雨滴微動態，用指定時長 pump
      await tester.pump(const Duration(milliseconds: 100));

      // 檢查頂部 HUD 數值
      expect(find.textContaining('94/100'), findsOneWidget); // 體力
      expect(find.textContaining('82/100'), findsOneWidget); // 飽食
      expect(find.textContaining('\$0'), findsWidgets);   // 開局現金

      // 檢查主線提示條
      expect(find.textContaining('叔叔發來的新簡訊'), findsOneWidget);

      // 檢查右下角未讀簡訊提示氣泡
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('智慧手機 SmartPhoneModal 顯示叔叔訊息並可領取 \$10,000 啟動金', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final life = PlayerLifeState();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SmartPhoneModal(
              playerLife: life,
              onClose: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      // 驗證手機內部簡訊內容
      expect(find.text('叔叔 (Uncle Fred)'), findsOneWidget);
      expect(find.textContaining('歡迎來到這座大都會'), findsOneWidget);
      expect(find.textContaining('領取啟動金 (+NT\$ 10,000)'), findsOneWidget);

      // 點擊領取按鈕
      await tester.tap(find.textContaining('領取啟動金 (+NT\$ 10,000)'));
      await tester.pump();

      // 驗證現金變更為 $10,000
      expect(life.personalCash, 10000.0);
      expect(life.hasClaimedUncleGift, isTrue);
      expect(find.textContaining('已存入網銀 (+NT\$ 10,000)'), findsOneWidget);
    });
  });
}
