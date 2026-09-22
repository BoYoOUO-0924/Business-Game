class Company {
  double cash;
  int day;
  int hour;
  double totalRevenue;
  double totalExpenses;
  double dailyRevenue;
  double dailyExpenses; // 採購成本
  double dailyWages;    // 員工工資
  double dailySpoilageCost; // 鮮食報廢損耗
  double totalWages;
  double totalSpoilageCost;
  double dailyRent;     // 門市租金
  int storeLevel;
  int reputation;       // 0 - 100

  int totalUnitsSold;

  // 營運品質指標（每日重置）
  int dailyCustomersServed;   // 成功結帳的來客
  int dailyCustomersLost;     // 被迫放棄的來客（大排長龍或缺貨）
  int dailyOpenHours;         // 今日實際有人值班的時數

  final List<double> revenueHistory;    // 歷史每日營收 (最多保留 7 天)
  final List<double> netProfitHistory;  // 歷史每日淨利 (最多保留 7 天)

  Company({
    this.cash = 50000.0,
    this.day = 1,
    this.hour = 8,
    this.totalRevenue = 0.0,
    this.totalExpenses = 0.0,
    this.dailyRevenue = 0.0,
    this.dailyExpenses = 0.0,
    this.dailyWages = 0.0,
    this.dailySpoilageCost = 0.0,
    this.totalWages = 0.0,
    this.totalSpoilageCost = 0.0,
    this.dailyRent = 2500.0, // 店面月租約 7.5 萬，攤提到每日
    this.storeLevel = 1,
    this.reputation = 65,
    this.totalUnitsSold = 0,
    this.dailyCustomersServed = 0,
    this.dailyCustomersLost = 0,
    this.dailyOpenHours = 0,
    List<double>? revenueHistory,
    List<double>? netProfitHistory,
  })  : revenueHistory = revenueHistory ?? [],
        netProfitHistory = netProfitHistory ?? [];

  /// 今日淨利 = 今日營業額 - (採購進貨 + 工資 + 鮮食報廢 + 租金)
  double get dailyNetProfit =>
      dailyRevenue - (dailyExpenses + dailyWages + dailySpoilageCost + dailyRent);

  /// 今日接客成功率（服務水準），無來客時視為滿分
  double get dailyServiceRate {
    final total = dailyCustomersServed + dailyCustomersLost;
    if (total == 0) return 1.0;
    return dailyCustomersServed / total;
  }

  /// 客單價
  double get averageTicket =>
      dailyCustomersServed > 0 ? dailyRevenue / dailyCustomersServed : 0.0;

  String get timeFormatted {
    final h = hour.toString().padLeft(2, '0');
    return '第 $day 天 · $h:00';
  }

  Map<String, dynamic> toJson() => {
        'cash': cash,
        'day': day,
        'hour': hour,
        'totalRevenue': totalRevenue,
        'totalExpenses': totalExpenses,
        'dailyRevenue': dailyRevenue,
        'dailyExpenses': dailyExpenses,
        'dailyWages': dailyWages,
        'dailySpoilageCost': dailySpoilageCost,
        'totalWages': totalWages,
        'totalSpoilageCost': totalSpoilageCost,
        'dailyRent': dailyRent,
        'storeLevel': storeLevel,
        'reputation': reputation,
        'totalUnitsSold': totalUnitsSold,
        'dailyCustomersServed': dailyCustomersServed,
        'dailyCustomersLost': dailyCustomersLost,
        'dailyOpenHours': dailyOpenHours,
        'revenueHistory': revenueHistory,
        'netProfitHistory': netProfitHistory,
      };

  void applyJson(Map<String, dynamic> j) {
    cash = (j['cash'] as num).toDouble();
    day = (j['day'] as num).toInt();
    hour = (j['hour'] as num).toInt();
    totalRevenue = (j['totalRevenue'] as num).toDouble();
    totalExpenses = (j['totalExpenses'] as num).toDouble();
    dailyRevenue = (j['dailyRevenue'] as num).toDouble();
    dailyExpenses = (j['dailyExpenses'] as num).toDouble();
    dailyWages = (j['dailyWages'] as num).toDouble();
    dailySpoilageCost = (j['dailySpoilageCost'] as num).toDouble();
    totalWages = (j['totalWages'] as num).toDouble();
    totalSpoilageCost = (j['totalSpoilageCost'] as num).toDouble();
    dailyRent = (j['dailyRent'] as num).toDouble();
    storeLevel = (j['storeLevel'] as num).toInt();
    reputation = (j['reputation'] as num).toInt();
    totalUnitsSold = (j['totalUnitsSold'] as num).toInt();
    dailyCustomersServed = (j['dailyCustomersServed'] as num?)?.toInt() ?? 0;
    dailyCustomersLost = (j['dailyCustomersLost'] as num?)?.toInt() ?? 0;
    dailyOpenHours = (j['dailyOpenHours'] as num?)?.toInt() ?? 0;
    revenueHistory
      ..clear()
      ..addAll((j['revenueHistory'] as List).map((e) => (e as num).toDouble()));
    netProfitHistory
      ..clear()
      ..addAll(((j['netProfitHistory'] ?? []) as List).map((e) => (e as num).toDouble()));
  }
}
