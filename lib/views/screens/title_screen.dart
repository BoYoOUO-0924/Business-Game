import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/player_life_state.dart';
import '../../services/audio_service.dart';
import '../main_dashboard_screen.dart';
import 'urban_game_screen.dart';

/// 遊戲開始主畫面 (Title & New Career Screen)
class TitleScreen extends StatefulWidget {
  const TitleScreen({super.key});

  @override
  State<TitleScreen> createState() => _TitleScreenState();
}

class _TitleScreenState extends State<TitleScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0E17),
      body: Stack(
        children: [
          // 1. 低多邊形大都會黃昏天際線背景
          Positioned.fill(
            child: CustomPaint(
              painter: _TitleSkylinePainter(),
            ),
          ),

          // 2. 主選單內容
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 頂部小標
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: const Text(
                          '🎮 手遊微縮模型版 (9:16)',
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ),
                      IconButton(
                        tooltip: AudioService().isMuted ? '開啟音效' : '靜音',
                        icon: Icon(
                          AudioService().isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                          color: Colors.white70,
                          size: 22,
                        ),
                        onPressed: () => setState(() => AudioService().toggleMute()),
                      ),
                    ],
                  ),

                  // 中間遊戲標題與呼吸光暈
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 遊戲霓虹標誌
                      AnimatedBuilder(
                        animation: _pulseCtrl,
                        builder: (context, _) {
                          final glow = 0.3 + (_pulseCtrl.value * 0.3);
                          return Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [Color(0xFFF97316), Color(0xFFD97706)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFF97316).withValues(alpha: glow),
                                  blurRadius: 28,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Text('🏙️', style: TextStyle(fontSize: 40)),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 20),

                      const Text(
                        '都會商雄',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.0,
                          shadows: [
                            Shadow(color: Color(0xFFF97316), blurRadius: 18),
                            Shadow(color: Colors.black, blurRadius: 6, offset: Offset(0, 3)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'URBAN AMBITION : RETAIL TYCOON',
                        style: TextStyle(
                          color: Color(0xFFFFB800),
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.8,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1B29),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: const Text(
                          '從一只皮箱出發 · 建立你的都會連鎖商業帝國',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ),
                    ],
                  ),

                  // 底部操作按鈕群
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 開始新生涯按鈕
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF97316),
                            foregroundColor: Colors.white,
                            elevation: 8,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            shadowColor: const Color(0xFFF97316).withValues(alpha: 0.6),
                          ),
                          onPressed: () {
                            AudioService().playCashRegister();
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ChangeNotifierProvider(
                                  create: (_) => PlayerLifeState(),
                                  child: Consumer<PlayerLifeState>(
                                    builder: (_, life, child) => UrbanGameScreen(playerLife: life),
                                  ),
                                ),
                              ),
                            );
                          },
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.play_arrow_rounded, size: 24),
                              SizedBox(width: 8),
                              Text(
                                '開始新生涯 (第一幕：初抵大都會)',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // 進入門市後台系統 (舊版五大分頁與回歸測試模式)
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white70,
                            side: const BorderSide(color: Colors.white24),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: () {
                            AudioService().playScanBeep();
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const MainDashboardScreen(),
                              ),
                            );
                          },
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.storefront_rounded, size: 18),
                              SizedBox(width: 8),
                              Text(
                                '進入連鎖超商後台 (進銷存/排班/批發)',
                                style: TextStyle(fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      const Text(
                        'v1.2.0 · 現代都會 Low-Poly 3D 微縮模型版',
                        style: TextStyle(color: Colors.white30, fontSize: 10.5),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TitleSkylinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // 漸層黃昏天空
    final skyPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF3B1E38), Color(0xFF1F1A2C), Color(0xFF0F0E17)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), skyPaint);

    // 暮光橙色光暈
    final glowPaint = Paint()
      ..color = const Color(0xFFF97316).withValues(alpha: 0.22)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 50);
    canvas.drawCircle(Offset(size.width / 2, size.height * 0.42), 120, glowPaint);

    // 遠處幾何低多邊形大樓剪影
    final bldgPaint = Paint()..color = const Color(0xFF14121E);
    final winPaint = Paint()..color = const Color(0xFFFDE047).withValues(alpha: 0.6);

    final bldgs = [
      {'x': 0.0, 'w': 60.0, 'h': 240.0},
      {'x': 50.0, 'w': 75.0, 'h': 340.0},
      {'x': 115.0, 'w': 65.0, 'h': 280.0},
      {'x': 170.0, 'w': 80.0, 'h': 400.0},
      {'x': 240.0, 'w': 70.0, 'h': 310.0},
      {'x': 300.0, 'w': 90.0, 'h': 360.0},
    ];

    for (final b in bldgs) {
      final rect = Rect.fromLTWH(b['x']!, size.height * 0.75 - b['h']!, b['w']!, b['h']!);
      canvas.drawRect(rect, bldgPaint);

      for (double y = rect.top + 20; y < rect.bottom - 20; y += 26) {
        for (double x = rect.left + 10; x < rect.right - 10; x += 16) {
          if ((x * y).toInt() % 4 == 0) {
            canvas.drawRect(Rect.fromLTWH(x, y, 7, 10), winPaint);
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
