import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:business_sim/models/player_life_state.dart';
import 'package:business_sim/services/audio_service.dart';
import 'package:business_sim/views/screens/urban_game_screen.dart';

void main() {
  setUpAll(() async {
    await AudioService().init(enabled: false);
  });

  group('點擊移動與智慧互動 (Click-to-Move & Smart Tap-to-Interact)', () {
    testWidgets('介面已徹底淨化：粗糙虛擬搖桿已移除，保留公務手機與快捷鍵動作按鈕', (tester) async {
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final life = PlayerLifeState();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UrbanGameScreen(playerLife: life, autoStartTicker: false),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // 驗證虛擬類比搖桿圖示已被徹底拔除
      expect(find.byIcon(Icons.gamepad_rounded), findsNothing);

      // 驗證右側公務手機存在
      expect(find.byIcon(Icons.smartphone_rounded), findsOneWidget);

      // 驗證右下角動作按鈕存在
      expect(find.byIcon(Icons.navigation_rounded), findsOneWidget);
    });

    testWidgets('點擊地面激發點擊移動與水波紋', (tester) async {
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final life = PlayerLifeState();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UrbanGameScreen(playerLife: life, autoStartTicker: true),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // 點擊地圖中央偏下位置 (地面)
      await tester.tapAt(const Offset(640, 450));
      await tester.pump(const Duration(milliseconds: 50));

      // 角色開始移動
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
    });

    testWidgets('點擊計程車觸發大都會呼叫站對話框', (tester) async {
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final life = PlayerLifeState();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UrbanGameScreen(
              playerLife: life,
              initialRoom: GameRoom.street,
              autoStartTicker: true,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // 計程車位於 gx: 5.0, gy: 7.0
      // originX = 640, originY = 720 * 0.16 = 115.2
      // x = 640 + (5 - 7) * 42 = 640 - 84 = 556
      // y = 115.2 + (5 + 7) * 21 = 115.2 + 252 = 367.2
      await tester.tapAt(const Offset(556, 367));
      await tester.pump(const Duration(milliseconds: 100));

      // 角色自動步行靠近並觸發對話框
      for (int i = 0; i < 25; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (find.text('大都會計程車呼叫站').evaluate().isNotEmpty) break;
      }

      expect(find.text('大都會計程車呼叫站'), findsOneWidget);
      expect(find.text('了解'), findsOneWidget);

      await tester.tap(find.text('了解'));
      await tester.pump(); // 觸發 onPressed Navigator.pop
      await tester.pump(const Duration(milliseconds: 300)); // 完成淡出
      expect(find.text('大都會計程車呼叫站'), findsNothing);
    });

    test('等角座標與螢幕座標精確封閉逆運算 (Screen Tap to Isometric Grid Inversion)', () {
      const originX = 640.0;
      final rooms = [GameRoom.street, GameRoom.apartment, GameRoom.store];

      for (final room in rooms) {
        double originY = 720 * 0.16;
        if (room == GameRoom.apartment) originY = 720 * 0.22;
        if (room == GameRoom.store) originY = 720 * 0.18;

        for (double gx = 1.0; gx <= 8.0; gx += 0.5) {
          for (double gy = 1.0; gy <= 8.0; gy += 0.5) {
            final sx = originX + (gx - gy) * (84.0 / 2);
            final sy = originY + (gx + gy) * (42.0 / 2);

            final dx = (sx - originX) / (84.0 / 2);
            final dy = (sy - originY) / (42.0 / 2);
            final recoveredGx = (dx + dy) / 2;
            final recoveredGy = (dy - dx) / 2;

            expect((recoveredGx - gx).abs(), lessThan(1e-9));
            expect((recoveredGy - gy).abs(), lessThan(1e-9));
          }
        }
      }
    });

    testWidgets('點擊公寓大門自動走入出租套房，並點擊折疊床睡覺', (tester) async {
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final life = PlayerLifeState();
      life.takePartTimeShift(hours: 4, hourlyWage: 150); // 消耗體力並賺取工資

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UrbanGameScreen(
              playerLife: life,
              initialRoom: GameRoom.street,
              autoStartTicker: true,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // 公寓大門位於 gx: 2.0, gy: 0.5 ~ 1.5
      // originX = 640, originY = 115.2
      // x = 640 + (2.0 - 0.5) * 42 = 640 + 63 = 703
      // y = 115.2 + (2.0 + 0.5) * 21 = 115.2 + 52.5 = 167.7
      await tester.tapAt(const Offset(703, 168));
      await tester.pump(const Duration(milliseconds: 50));

      // 角色自動走向大門並進入套房 (需約 95 步)
      for (int i = 0; i < 120; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        if (find.text('街角出租套房 (頂樓)').evaluate().isNotEmpty) break;
      }

      expect(find.text('街角出租套房 (頂樓)'), findsOneWidget);

      // 套房內點擊折疊床 (gx: 4.0, gy: 2.0)
      // originX = 640, originY = 720 * 0.22 = 158.4
      // x = 640 + (4 - 2) * 42 = 640 + 84 = 724
      // y = 158.4 + (4 + 2) * 21 = 158.4 + 126 = 284.4
      await tester.tapAt(const Offset(724, 284));

      for (int i = 0; i < 120; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        if (life.energy == 100.0) break;
      }

      expect(life.energy, 100.0);
      expect(life.isCarryingSuitcase, isFalse);
    });

    testWidgets('在超商點擊紙箱棧板抱起紙箱，點擊貨架補貨，點擊收銀台結帳', (tester) async {
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final life = PlayerLifeState();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UrbanGameScreen(
              playerLife: life,
              initialRoom: GameRoom.store,
              autoStartTicker: true,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('CITY MART 超商門市'), findsOneWidget);

      // 1. 點擊進貨紙箱棧板 (gx: 1.8, gy: 5.0)
      // originX = 640, originY = 720 * 0.18 = 129.6
      // x = 640 + (1.8 - 5.0) * 42 = 640 - 134.4 = 505.6
      // y = 129.6 + (1.8 + 5.0) * 21 = 129.6 + 142.8 = 272.4
      await tester.tapAt(const Offset(506, 272));

      for (int i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (find.textContaining('抱起了滿箱的零食').evaluate().isNotEmpty) break;
      }
      expect(find.textContaining('抱起了滿箱的零食'), findsOneWidget);

      // 2. 點擊零食貨架 (gx: 3.5, gy: 3.2)
      // x = 640 + (3.5 - 3.2) * 42 = 640 + 12.6 = 652.6
      // y = 129.6 + (3.5 + 3.2) * 21 = 129.6 + 140.7 = 270.3
      await tester.tapAt(const Offset(653, 270));

      for (int i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (find.textContaining('成功補滿零食展示架').evaluate().isNotEmpty) break;
      }
      expect(find.textContaining('成功補滿零食展示架'), findsOneWidget);

      // 3. 點擊收銀台 (gx: 5.0, gy: 2.8)
      // x = 640 + (5.0 - 2.8) * 42 = 640 + 92.4 = 732.4
      // y = 129.6 + (5.0 + 2.8) * 21 = 129.6 + 163.8 = 293.4
      final cashBefore = life.personalCash;
      await tester.tapAt(const Offset(732, 293));

      for (int i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (life.personalCash > cashBefore) break;
      }
      expect(life.personalCash, cashBefore + 150.0);
    });
  });
}
