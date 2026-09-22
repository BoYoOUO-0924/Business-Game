enum FixtureType {
  cashier,      // 收銀櫃台
  snackShelf,   // 零食泡麵貨架
  drinkCooler,  // 雙門飲料冷藏展示櫃
  freshWarmer,  // 鮮食便當茶葉蛋保溫台
  coffeeBar,    // 現煮義式咖啡吧台
}

class StoreFixture {
  final String id;
  final String name;
  final String icon;
  final FixtureType type;
  final String description;
  final double cost;
  bool isPurchased;
  int level;
  final int maxCapacity; // 該設備可陳列的總件數
  final int gridX;
  final int gridY;

  StoreFixture({
    required this.id,
    required this.name,
    required this.icon,
    required this.type,
    required this.description,
    required this.cost,
    this.isPurchased = false,
    this.level = 1,
    required this.maxCapacity,
    required this.gridX,
    required this.gridY,
  });

  /// 升級所需費用。
  /// 開局即配備的設備（收銀台、零食貨架）購入成本為 0——因為從不需要
  /// 「購買」——但升級費用不能沿用這個 0，否則公式算出來永遠免費。
  /// 改用容量規模換算一個等價的基準成本，付費設備則維持原本以購入
  /// 成本為準的算法不變。
  double get upgradeCost {
    final base = cost > 0 ? cost : maxCapacity * 8.0;
    return base * (level * 0.85);
  }

  /// 升級增加陳列容量
  int get currentCapacity => (maxCapacity * (1.0 + (level - 1) * 0.5)).round();
}
