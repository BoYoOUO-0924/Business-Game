import 'package:flutter_test/flutter_test.dart';
import 'package:business_sim/providers/game_state.dart';
import 'package:business_sim/services/audio_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('實體門市微觀操作與音效 (Tactile Store & Audio)', () {
    test('音效服務初始化並生成合成 WAV 數據', () async {
      final audio = AudioService();
      // 在測試環境中以 enabled: false 初始化以避免 native 聲卡 channel 調用
      await audio.init(enabled: false);

      expect(audio.isMuted, isFalse);
      expect(audio.volume, greaterThan(0));

      // 驗證內存純合成 WAV 音效已成功生成且大小正確
      expect(audio.doorChimeWav, isNotNull);
      expect(audio.doorChimeWav!.length, greaterThan(100));
      expect(audio.scanBeepWav, isNotNull);
      expect(audio.scanBeepWav!.length, greaterThan(100));
      expect(audio.cashRegisterWav, isNotNull);
      expect(audio.cashRegisterWav!.length, greaterThan(100));

      // 安全呼叫播放方法
      await audio.playDoorChime();
      await audio.playScanBeep();
      await audio.playCashRegister();
      await audio.playRestock();
      await audio.playFanfare();

      // 切換靜音
      audio.toggleMute();
      expect(audio.isMuted, isTrue);
      audio.toggleMute();
      expect(audio.isMuted, isFalse);
    });

    test('各設備剩餘陳列容量計算正確', () {
      final state = GameState();
      // 零食架開局已購置
      final snackSpace = state.remainingShelfSpaceForFixture('snack_shelf');
      expect(snackSpace, greaterThan(0));

      // 尚未購置的冷藏櫃容量為 0
      final coolerSpace = state.remainingShelfSpaceForFixture('drink_cooler');
      expect(coolerSpace, equals(0));

      // 添購冷藏櫃後，空間即時解鎖
      state.purchaseFixture('drink_cooler');
      final newCoolerSpace = state.remainingShelfSpaceForFixture('drink_cooler');
      expect(newCoolerSpace, greaterThan(0));
    });

    test('貨架單品可即時進貨補滿', () {
      final state = GameState();
      state.company.cash = 50000;
      final initialUsed = state.shelfUsed('snack_shelf');

      // 針對零食架上的洋芋片補貨 10 件
      final ok = state.restockItem('potato_chips', 10);
      expect(ok, isTrue);
      expect(state.shelfUsed('snack_shelf'), equals(initialUsed + 10));
    });
  });
}
