class Quest {
  final String id;
  final String title;
  final String description;
  final String icon;
  final double targetValue;
  final double rewardCash;
  final int rewardReputation;
  bool isCompleted;
  bool isClaimed;

  Quest({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.targetValue,
    required this.rewardCash,
    required this.rewardReputation,
    this.isCompleted = false,
    this.isClaimed = false,
  });

  double currentProgress(double actualValue) {
    if (actualValue >= targetValue) return 1.0;
    return (actualValue / targetValue).clamp(0.0, 1.0);
  }
}
