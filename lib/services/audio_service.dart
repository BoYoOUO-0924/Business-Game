import 'dart:math' as math;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// 遊戲音效控制器 (支援純內存合成 WAV，免外部資源加載延遲，全平台可用)
class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  AudioPlayer? _player;
  bool _isMuted = false;
  bool _enabled = true;
  double _volume = 0.7;

  bool get isMuted => _isMuted;
  bool get isEnabled => _enabled;
  double get volume => _volume;

  // 預生成快取的音效 Byte 陣列
  Uint8List? _doorChimeWav;
  Uint8List? _scanBeepWav;
  Uint8List? _cashRegisterWav;
  Uint8List? _restockWav;
  Uint8List? _fanfareWav;
  Uint8List? _footstepWav;

  Uint8List? get doorChimeWav => _doorChimeWav;
  Uint8List? get scanBeepWav => _scanBeepWav;
  Uint8List? get cashRegisterWav => _cashRegisterWav;
  Uint8List? get footstepWav => _footstepWav;

  Future<void> init({bool enabled = true}) async {
    _enabled = enabled;
    _generateAllSoundEffects();
    if (!_enabled) return;

    try {
      _player = AudioPlayer();
      await _player?.setVolume(_volume);
    } catch (e) {
      _enabled = false;
      debugPrint('AudioService init safe fallback: $e');
    }
  }

  void toggleMute() {
    _isMuted = !_isMuted;
    _player?.setVolume(_isMuted ? 0.0 : _volume);
  }

  void setVolume(double val) {
    _volume = val.clamp(0.0, 1.0);
    if (!_isMuted) {
      _player?.setVolume(_volume);
    }
  }

  void _generateAllSoundEffects() {
    _doorChimeWav = _synthesizeTwoToneChime(659.25, 523.25, 0.22, 0.35); // 叮咚 (E5 -> C5)
    _scanBeepWav = _synthesizeTone(1800.0, 0.07, waveform: 'sine'); // 掃碼嗶
    _scanBeepWav = _synthesizeTone(1800.0, 0.07, waveform: 'sine');
    _cashRegisterWav = _synthesizeCashRegister(); // 收銀機噹 (Ka-ching)
    _restockWav = _synthesizeRestockThud(); // 補貨入架落地音
    _fanfareWav = _synthesizeFanfare(); // 通關熱烈短音
    _footstepWav = _synthesizeFootstep(); // 角色輕微踏步音
  }

  DateTime? _lastFootstepTime;

  Future<void> playFootstep() async {
    if (_isMuted || _footstepWav == null) return;
    final now = DateTime.now();
    if (_lastFootstepTime != null && now.difference(_lastFootstepTime!).inMilliseconds < 260) {
      return;
    }
    _lastFootstepTime = now;
    await _playSoundBytes(_footstepWav!);
  }

  Future<void> playDoorChime() async {
    if (_isMuted || _doorChimeWav == null) return;
    await _playSoundBytes(_doorChimeWav!);
  }

  Future<void> playScanBeep() async {
    if (_isMuted || _scanBeepWav == null) return;
    await _playSoundBytes(_scanBeepWav!);
  }

  Future<void> playCashRegister() async {
    if (_isMuted || _cashRegisterWav == null) return;
    await _playSoundBytes(_cashRegisterWav!);
  }

  Future<void> playRestock() async {
    if (_isMuted || _restockWav == null) return;
    await _playSoundBytes(_restockWav!);
  }

  Future<void> playFanfare() async {
    if (_isMuted || _fanfareWav == null) return;
    await _playSoundBytes(_fanfareWav!);
  }

  Future<void> _playSoundBytes(Uint8List bytes) async {
    if (!_enabled || _isMuted) return;
    try {
      _player ??= AudioPlayer();
      // 使用 BytesSource 進行快速免聯網播放
      await _player?.stop();
      await _player?.play(BytesSource(bytes));
    } catch (e) {
      // 靜默處理單元測試環境或無視訊設備的異常
      debugPrint('Audio playback error (safe fallback): $e');
    }
  }

  // --- WAV 生成算法 ---

  Uint8List _buildWavHeader(int dataLength, int sampleRate, int channels, int bitsPerSample) {
    final byteRate = sampleRate * channels * (bitsPerSample ~/ 8);
    final blockAlign = channels * (bitsPerSample ~/ 8);
    final header = ByteData(44);

    // RIFF identifier
    header.setUint8(0, 0x52); // 'R'
    header.setUint8(1, 0x49); // 'I'
    header.setUint8(2, 0x46); // 'F'
    header.setUint8(3, 0x46); // 'F'
    header.setUint32(4, 36 + dataLength, Endian.little);

    // WAVE
    header.setUint8(8, 0x57);  // 'W'
    header.setUint8(9, 0x41);  // 'A'
    header.setUint8(10, 0x56); // 'V'
    header.setUint8(11, 0x45); // 'E'

    // fmt chunk
    header.setUint8(12, 0x66); // 'f'
    header.setUint8(13, 0x6D); // 'm'
    header.setUint8(14, 0x74); // 't'
    header.setUint8(15, 0x20); // ' '
    header.setUint32(16, 16, Endian.little); // Subchunk1Size
    header.setUint16(20, 1, Endian.little);  // PCM format
    header.setUint16(22, channels, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, byteRate, Endian.little);
    header.setUint16(32, blockAlign, Endian.little);
    header.setUint16(34, bitsPerSample, Endian.little);

    // data chunk
    header.setUint8(36, 0x64); // 'd'
    header.setUint8(37, 0x61); // 'a'
    header.setUint8(38, 0x74); // 't'
    header.setUint8(39, 0x61); // 'a'
    header.setUint32(40, dataLength, Endian.little);

    return header.buffer.asUint8List();
  }

  Uint8List _synthesizeTone(double freq, double durationSec, {String waveform = 'sine'}) {
    const sampleRate = 22050;
    final totalSamples = (sampleRate * durationSec).toInt();
    final pcmBytes = ByteData(totalSamples * 2);

    for (int i = 0; i < totalSamples; i++) {
      final t = i / sampleRate;
      final env = math.exp(-3.0 * (t / durationSec)); // 自然衰減
      double sample = 0.0;
      if (waveform == 'sine') {
        sample = math.sin(2 * math.pi * freq * t);
      } else {
        sample = (math.sin(2 * math.pi * freq * t) > 0) ? 0.7 : -0.7;
      }
      final sampleInt = (sample * env * 24000).toInt().clamp(-32767, 32767);
      pcmBytes.setInt16(i * 2, sampleInt, Endian.little);
    }

    final header = _buildWavHeader(pcmBytes.lengthInBytes, sampleRate, 1, 16);
    final wav = Uint8List(header.length + pcmBytes.lengthInBytes);
    wav.setAll(0, header);
    wav.setAll(header.length, pcmBytes.buffer.asUint8List());
    return wav;
  }

  Uint8List _synthesizeTwoToneChime(double freq1, double freq2, double dur1, double dur2) {
    const sampleRate = 22050;
    final totalSamples1 = (sampleRate * dur1).toInt();
    final totalSamples2 = (sampleRate * dur2).toInt();
    final totalSamples = totalSamples1 + totalSamples2;
    final pcmBytes = ByteData(totalSamples * 2);

    int byteIndex = 0;
    // 第一音 (叮)
    for (int i = 0; i < totalSamples1; i++) {
      final t = i / sampleRate;
      final env = math.exp(-2.5 * (t / dur1));
      final sample = (math.sin(2 * math.pi * freq1 * t) + 0.3 * math.sin(4 * math.pi * freq1 * t)) * env;
      final sampleInt = (sample * 24000).toInt().clamp(-32767, 32767);
      pcmBytes.setInt16(byteIndex, sampleInt, Endian.little);
      byteIndex += 2;
    }
    // 第二音 (咚)
    for (int i = 0; i < totalSamples2; i++) {
      final t = i / sampleRate;
      final env = math.exp(-2.2 * (t / dur2));
      final sample = (math.sin(2 * math.pi * freq2 * t) + 0.25 * math.sin(4 * math.pi * freq2 * t)) * env;
      final sampleInt = (sample * 26000).toInt().clamp(-32767, 32767);
      pcmBytes.setInt16(byteIndex, sampleInt, Endian.little);
      byteIndex += 2;
    }

    final header = _buildWavHeader(pcmBytes.lengthInBytes, sampleRate, 1, 16);
    final wav = Uint8List(header.length + pcmBytes.lengthInBytes);
    wav.setAll(0, header);
    wav.setAll(header.length, pcmBytes.buffer.asUint8List());
    return wav;
  }

  Uint8List _synthesizeCashRegister() {
    const sampleRate = 22050;
    const dur = 0.35;
    final totalSamples = (sampleRate * dur).toInt();
    final pcmBytes = ByteData(totalSamples * 2);

    for (int i = 0; i < totalSamples; i++) {
      final t = i / sampleRate;
      // 金屬鈴聲雙頻疊加
      final bell1 = math.sin(2 * math.pi * 1046.5 * t);
      final bell2 = math.sin(2 * math.pi * 2093.0 * t) * 0.5;
      final click = (t < 0.03) ? (math.Random(i).nextDouble() * 2 - 1) * 0.4 : 0.0;
      final env = math.exp(-6.0 * t);
      final sample = (bell1 + bell2 + click) * env;
      final sampleInt = (sample * 25000).toInt().clamp(-32767, 32767);
      pcmBytes.setInt16(i * 2, sampleInt, Endian.little);
    }

    final header = _buildWavHeader(pcmBytes.lengthInBytes, sampleRate, 1, 16);
    final wav = Uint8List(header.length + pcmBytes.lengthInBytes);
    wav.setAll(0, header);
    wav.setAll(header.length, pcmBytes.buffer.asUint8List());
    return wav;
  }

  Uint8List _synthesizeRestockThud() {
    const sampleRate = 22050;
    const dur = 0.15;
    final totalSamples = (sampleRate * dur).toInt();
    final pcmBytes = ByteData(totalSamples * 2);

    for (int i = 0; i < totalSamples; i++) {
      final t = i / sampleRate;
      final noise = (math.Random(i).nextDouble() * 2 - 1) * math.exp(-25.0 * t);
      final thud = math.sin(2 * math.pi * 180.0 * t) * math.exp(-15.0 * t);
      final sample = (noise * 0.6 + thud * 0.4);
      final sampleInt = (sample * 24000).toInt().clamp(-32767, 32767);
      pcmBytes.setInt16(i * 2, sampleInt, Endian.little);
    }

    final header = _buildWavHeader(pcmBytes.lengthInBytes, sampleRate, 1, 16);
    final wav = Uint8List(header.length + pcmBytes.lengthInBytes);
    wav.setAll(0, header);
    wav.setAll(header.length, pcmBytes.buffer.asUint8List());
    return wav;
  }

  Uint8List _synthesizeFanfare() {
    const sampleRate = 22050;
    final notes = [523.25, 659.25, 783.99, 1046.5]; // C5, E5, G5, C6
    const noteDur = 0.12;
    final totalSamples = (sampleRate * noteDur * notes.length).toInt();
    final pcmBytes = ByteData(totalSamples * 2);

    int sampleOffset = 0;
    for (final freq in notes) {
      final samplesPerNote = (sampleRate * noteDur).toInt();
      for (int i = 0; i < samplesPerNote; i++) {
        final t = i / sampleRate;
        final env = math.exp(-2.0 * (t / noteDur));
        final sample = (math.sin(2 * math.pi * freq * t) + 0.3 * math.sin(3 * math.pi * freq * t)) * env;
        final sampleInt = (sample * 24000).toInt().clamp(-32767, 32767);
        pcmBytes.setInt16(sampleOffset * 2, sampleInt, Endian.little);
        sampleOffset++;
      }
    }

    final header = _buildWavHeader(pcmBytes.lengthInBytes, sampleRate, 1, 16);
    final wav = Uint8List(header.length + pcmBytes.lengthInBytes);
    wav.setAll(0, header);
    wav.setAll(header.length, pcmBytes.buffer.asUint8List());
    return wav;
  }

  Uint8List _synthesizeFootstep() {
    const sampleRate = 22050;
    const dur = 0.05;
    final totalSamples = (sampleRate * dur).toInt();
    final pcmBytes = ByteData(totalSamples * 2);

    for (int i = 0; i < totalSamples; i++) {
      final t = i / sampleRate;
      final thud = math.sin(2 * math.pi * 95.0 * t) * math.exp(-60.0 * t);
      final noise = (math.Random(i).nextDouble() * 2 - 1) * math.exp(-80.0 * t) * 0.25;
      final sample = (thud * 0.7 + noise * 0.3);
      final sampleInt = (sample * 16000).toInt().clamp(-32767, 32767);
      pcmBytes.setInt16(i * 2, sampleInt, Endian.little);
    }

    final header = _buildWavHeader(pcmBytes.lengthInBytes, sampleRate, 1, 16);
    final wav = Uint8List(header.length + pcmBytes.lengthInBytes);
    wav.setAll(0, header);
    wav.setAll(header.length, pcmBytes.buffer.asUint8List());
    return wav;
  }
}
