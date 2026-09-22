import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/game_state.dart';
import 'views/main_dashboard_screen.dart';
import 'views/theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BusinessSimApp());
}

class BusinessSimApp extends StatelessWidget {
  const BusinessSimApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => GameState(),
      child: MaterialApp(
        title: '連鎖超商營運系統',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: const _Bootstrap(),
      ),
    );
  }
}

/// 開場先嘗試讀取本機存檔，再進入主畫面。
class _Bootstrap extends StatefulWidget {
  const _Bootstrap();

  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    await context.read<GameState>().load();
    if (mounted) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        backgroundColor: AppColors.page,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('🏪', style: TextStyle(fontSize: 44)),
              SizedBox(height: AppSpacing.lg),
              Text('連鎖超商營運系統', style: AppText.title),
              SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: 120,
                child: LinearProgressIndicator(
                  minHeight: 3,
                  backgroundColor: AppColors.surfaceHigh,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return const MainDashboardScreen();
  }
}
