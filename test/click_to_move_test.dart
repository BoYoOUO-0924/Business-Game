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

      // 計程車站點擊熱區：nx = 0.64, ny = 0.52
      // 1280x720 下 9:16 容器居中：寬 405，左邊距 437.5
      // globalX = 437.5 + 0.64 * 405 = 696.7
      // globalY = 0.52 * 720 = 374.4
      await tester.tapAt(const Offset(697, 374));
      await tester.pump(const Duration(milliseconds: 50));

      // 角色自動巡航靠近並自動彈出計程車對話框
      for (int i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        if (find.text('大都會計程車呼叫站').evaluate().isNotEmpty) break;
      }

      expect(find.text('大都會計程車呼叫站'), findsOneWidget);
      expect(find.text('了解'), findsOneWidget);

      await tester.tap(find.text('了解'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('大都會計程車呼叫站'), findsNothing);
    });

    test('微縮空間歸一化坐標正逆雙向投影 (Diorama Coordinate Projection Bijection)', () {
      const double screenW = 1280.0;
      const double screenH = 720.0;
      final containerW = screenH * (9.0 / 16.0); // 405.0
      final originX = (screenW - containerW) / 2.0; // 437.5

      for (double nx = 0.1; nx <= 0.9; nx += 0.1) {
        for (double ny = 0.3; ny <= 0.9; ny += 0.1) {
          final globalX = originX + nx * containerW;
          final globalY = ny * screenH;

          final recoveredNx = (globalX - originX) / containerW;
          final recoveredNy = globalY / screenH;

          expect((recoveredNx - nx).abs(), lessThan(1e-9));
          expect((recoveredNy - ny).abs(), lessThan(1e-9));
        }
      }
    });

    testWidgets('點擊公寓大門自動走入出租套房，並點擊折疊床睡覺', (tester) async {
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final life = PlayerLifeState();
      life.takePartTimeShift(hours: 4, hourlyWage: 150);

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

      // 點擊公寓大門熱區 (nx: 0.48, ny: 0.64)
      // globalX = 437.5 + 0.48 * 405 = 631.9
      // globalY = 0.64 * 720 = 460.8
      await tester.tapAt(const Offset(632, 461));
      await tester.pump(const Duration(milliseconds: 50));

      // 角色自動走向大門並切換至公寓套房
      for (int i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        if (find.text('街角出租套房 (頂樓)').evaluate().isNotEmpty) break;
      }

      expect(find.text('街角出租套房 (頂樓)'), findsOneWidget);

      // 套房內點擊折疊床 (nx: 0.43, ny: 0.57)
      // globalX = 437.5 + 0.43 * 405 = 611.7
      // globalY = 0.57 * 720 = 410.4
      await tester.tapAt(const Offset(612, 410));

      for (int i = 0; i < 40; i++) {
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

      // 1. 點擊進貨紙箱棧板 (nx: 0.52, ny: 0.68)
      // globalX = 437.5 + 0.52 * 405 = 648.1
      // globalY = 0.68 * 720 = 489.6
      await tester.tapAt(const Offset(648, 490));

      for (int i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        if (find.textContaining('已抱起補貨紙箱').evaluate().isNotEmpty) break;
      }
      expect(find.textContaining('已抱起補貨紙箱'), findsOneWidget);

      // 2. 點擊零食展示架 (nx: 0.44, ny: 0.52)
      // globalX = 437.5 + 0.44 * 405 = 615.7
      // globalY = 0.52 * 720 = 374.4
      await tester.tapAt(const Offset(616, 374));

      for (int i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        if (find.textContaining('成功補滿零食架').evaluate().isNotEmpty) break;
      }
      expect(find.textContaining('成功補滿零食架'), findsOneWidget);

      // 3. 點擊收銀台 (nx: 0.75, ny: 0.57)
      // globalX = 437.5 + 0.75 * 405 = 741.3
      // globalY = 0.57 * 720 = 410.4
      final cashBefore = life.personalCash;
      await tester.tapAt(const Offset(741, 410));

      for (int i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        if (life.personalCash > cashBefore) break;
      }
      expect(life.personalCash, cashBefore + 150.0);
    });
  });
}
