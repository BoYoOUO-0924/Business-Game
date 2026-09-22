import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:business_sim/models/player_life_state.dart';
import 'package:business_sim/views/screens/urban_game_screen.dart';

class _RealAssetBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    final file = File(key);
    if (file.existsSync()) {
      final bytes = await file.readAsBytes();
      return ByteData.sublistView(Uint8List.fromList(bytes));
    }
    return rootBundle.load(key);
  }
}

void main() {
  testWidgets('Visual Capture Street', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    
    final life = PlayerLifeState();
    final bundle = _RealAssetBundle();

    await tester.runAsync(() async {
      await tester.pumpWidget(DefaultAssetBundle(
        bundle: bundle,
        child: MaterialApp(
          home: Scaffold(
            body: RepaintBoundary(
              key: const Key('capture_street'),
              child: UrbanGameScreen(playerLife: life, initialRoom: GameRoom.street, autoStartTicker: false),
            ),
          ),
        ),
      ));

      final element = tester.element(find.byKey(const Key('capture_street')));
      await precacheImage(const AssetImage('assets/images/urban_diorama_clean.jpg'), element);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final boundary = element.renderObject as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      File('screenshot_street.png').writeAsBytesSync(byteData!.buffer.asUint8List());
    });
  });

  testWidgets('Visual Capture Apartment', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    
    final life = PlayerLifeState();
    final bundle = _RealAssetBundle();

    await tester.runAsync(() async {
      await tester.pumpWidget(DefaultAssetBundle(
        bundle: bundle,
        child: MaterialApp(
          home: Scaffold(
            body: RepaintBoundary(
              key: const Key('capture_apartment'),
              child: UrbanGameScreen(playerLife: life, initialRoom: GameRoom.apartment, autoStartTicker: false),
            ),
          ),
        ),
      ));

      final element = tester.element(find.byKey(const Key('capture_apartment')));
      await precacheImage(const AssetImage('assets/images/apartment_diorama.jpg'), element);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final boundary = element.renderObject as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      File('screenshot_apartment.png').writeAsBytesSync(byteData!.buffer.asUint8List());
    });
  });

  testWidgets('Visual Capture Store', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    
    final life = PlayerLifeState();
    final bundle = _RealAssetBundle();

    await tester.runAsync(() async {
      await tester.pumpWidget(DefaultAssetBundle(
        bundle: bundle,
        child: MaterialApp(
          home: Scaffold(
            body: RepaintBoundary(
              key: const Key('capture_store'),
              child: UrbanGameScreen(playerLife: life, initialRoom: GameRoom.store, autoStartTicker: false),
            ),
          ),
        ),
      ));

      final element = tester.element(find.byKey(const Key('capture_store')));
      await precacheImage(const AssetImage('assets/images/store_diorama.jpg'), element);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final boundary = element.renderObject as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      File('screenshot_store.png').writeAsBytesSync(byteData!.buffer.asUint8List());
    });
  });
}
