class MarketEvent {
  final String id;
  final String title;
  final String description;
  final String icon;
  final double trafficMultiplier; // 人流增減 (如 1.8 增加 80%, 0.6 減少 40%)
  final double costMultiplier;    // 進貨成本波動 (如 1.25 上漲 25%)
  final String affectedCategory;  // 'all' 或特定類別如 '即飲冷飲'
  final int durationHours;
  int hoursRemaining;

  MarketEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    this.trafficMultiplier = 1.0,
    this.costMultiplier = 1.0,
    this.affectedCategory = 'all',
    required this.durationHours,
    int? hoursRemaining,
  }) : hoursRemaining = hoursRemaining ?? durationHours;

  bool get isExpired => hoursRemaining <= 0;
}
