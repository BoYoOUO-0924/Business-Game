class Supplier {
  final String id;
  final String name;
  final String contactPerson;
  final String avatar;
  final String brandTag;
  final String location;
  final String description;
  final int minOrderQuantity; // 最低起訂量 MOQ
  final double baseDiscount; // 基礎折扣 (例如 0.85 = 85折)
  bool isUnlocked;
  final String unlockRequirementText;
  int relationship; // 好感度 0 - 100
  final List<String> suppliedItemIds;
  final String personalityPrompt; // 給 AI 談判的模型設定

  Supplier({
    required this.id,
    required this.name,
    required this.contactPerson,
    required this.avatar,
    required this.brandTag,
    required this.location,
    required this.description,
    required this.minOrderQuantity,
    this.baseDiscount = 1.0,
    this.isUnlocked = false,
    required this.unlockRequirementText,
    this.relationship = 50,
    required this.suppliedItemIds,
    required this.personalityPrompt,
  });

  /// 依據好感度獲得額外批發折扣 (0% ~ 12%)
  double get effectiveWholesaleMultiplier {
    final bonusDiscount = (relationship - 50).clamp(0, 50) / 50.0 * 0.12;
    return (baseDiscount - bonusDiscount).clamp(0.70, 1.0);
  }
}
