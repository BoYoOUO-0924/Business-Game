class ChapterGoal {
  final String id;
  final String title;
  final String description;
  final double targetValue;
  final String metricType; // 'revenue', 'customers_served', 'hired_staff', 'reputation', 'fixture_purchased'
  bool isAchieved;

  ChapterGoal({
    required this.id,
    required this.title,
    required this.description,
    required this.targetValue,
    required this.metricType,
    this.isAchieved = false,
  });

  double getProgress(double currentValue) {
    if (currentValue >= targetValue) return 1.0;
    return (currentValue / targetValue).clamp(0.0, 1.0);
  }
}

class ChapterStory {
  final int chapterNumber;
  final String title;
  final String subtitle;
  final String icon;
  final String storyIntro;
  final List<ChapterGoal> goals;
  final double rewardCash;
  final int rewardReputation;
  final String unlockSummary;
  bool isCompleted;
  bool isClaimed;

  ChapterStory({
    required this.chapterNumber,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.storyIntro,
    required this.goals,
    required this.rewardCash,
    required this.rewardReputation,
    required this.unlockSummary,
    this.isCompleted = false,
    this.isClaimed = false,
  });

  bool checkAllGoalsAchieved() {
    return goals.every((g) => g.isAchieved);
  }
}
