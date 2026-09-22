import 'dart:math';

/// 一批同時進貨的商品。鮮食以批次為單位計算賞味期，
/// 銷售採 FIFO（先進先出），避免「補 1 件就洗掉整批時效」的漏洞。
class StockBatch {
  int units;
  int ageHours;

  StockBatch({required this.units, this.ageHours = 0});

  Map<String, dynamic> toJson() => {'u': units, 'a': ageHours};

  factory StockBatch.fromJson(Map<String, dynamic> j) =>
      StockBatch(units: (j['u'] as num).toInt(), ageHours: (j['a'] as num).toInt());
}

class InventoryItem {
  final String id;
  final String name;
  final String icon;
  final String category;
  final double wholesaleCost; // 原廠建議批發價
  double currentNegotiatedPrice; // 與供應商談妥的進貨價
  double retailPrice; // 門市販售價格
  final double baseHourlyDemand; // 該商品在顧客心中的相對熱門度（權重）

  // 鮮食保鮮機制（以批次計）
  final bool isPerishable;
  final int shelfLifeHours;
  int dailySpoiledUnits;

  // 品牌與陳列設備
  final String brandName;
  final String supplierId;
  final String requiredFixtureId;

  /// 是否已解鎖販售。由所需陳列設備是否購置推導而來，
  /// 統一在 GameState.refreshItemAvailability() 更新，不可手動設定。
  bool isUnlocked;

  /// 本商品目前在架上的所有批次（越前面越舊）
  final List<StockBatch> batches;

  /// 今日因缺貨而流失的來客數（供缺貨警示與商譽計算）
  int dailyLostSales;

  InventoryItem({
    required this.id,
    required this.name,
    required this.icon,
    required this.category,
    int stock = 50,
    required this.wholesaleCost,
    required this.currentNegotiatedPrice,
    required this.retailPrice,
    this.baseHourlyDemand = 8.0,
    this.isPerishable = false,
    this.shelfLifeHours = 24,
    this.dailySpoiledUnits = 0,
    this.dailyLostSales = 0,
    this.brandName = '宏泰在地雜貨',
    this.supplierId = 'lao_li',
    this.requiredFixtureId = 'snack_shelf',
    this.isUnlocked = true,
  }) : batches = stock > 0 ? [StockBatch(units: stock)] : [];

  /// 目前總庫存（由批次推導，唯一真實來源）
  int get stock => batches.fold(0, (a, b) => a + b.units);

  /// 毛利率 (Gross Margin)
  double get grossMargin =>
      retailPrice > 0 ? (retailPrice - currentNegotiatedPrice) / retailPrice : 0.0;

  /// 單件毛利
  double get unitProfit => retailPrice - currentNegotiatedPrice;

  /// 最舊批次已放置的時數（鮮食新鮮度指標）
  int get oldestAgeHours => batches.isEmpty ? 0 : batches.first.ageHours;

  /// 鮮食剩餘賞味時數；非鮮食回傳 null
  int? get hoursUntilSpoil =>
      isPerishable && batches.isNotEmpty ? max(0, shelfLifeHours - oldestAgeHours) : null;

  /// 進貨，建立新批次
  void addStock(int quantity) {
    if (quantity <= 0) return;
    batches.add(StockBatch(units: quantity));
  }

  /// 依 FIFO 賣出，回傳實際賣出數量
  int consume(int quantity) {
    var remaining = quantity;
    var sold = 0;
    while (remaining > 0 && batches.isNotEmpty) {
      final batch = batches.first;
      final take = min(batch.units, remaining);
      batch.units -= take;
      remaining -= take;
      sold += take;
      if (batch.units <= 0) batches.removeAt(0);
    }
    return sold;
  }

  /// 讓所有批次老化 1 小時，並整批報廢超過賞味期者。
  /// 回傳這次報廢的件數。
  int ageOneHourAndDiscard() {
    if (batches.isEmpty) return 0;
    for (final b in batches) {
      b.ageHours += 1;
    }
    if (!isPerishable) return 0;

    var spoiled = 0;
    batches.removeWhere((b) {
      if (b.ageHours >= shelfLifeHours) {
        spoiled += b.units;
        return true;
      }
      return false;
    });
    dailySpoiledUnits += spoiled;
    return spoiled;
  }

  /// 顧客對本商品的相對吸引力權重。
  /// 定價越貴吸引力越低（彈性 -1.3），缺貨或未解鎖則為 0。
  double attractiveness() {
    if (!isUnlocked || stock <= 0) return 0.0;
    return baseHourlyDemand * priceElasticity();
  }

  /// 定價彈性：以「批發成本 × 1.6」為心理合理價的基準
  double priceElasticity() {
    final anchor = wholesaleCost * 1.6;
    if (anchor <= 0 || retailPrice <= 0) return 1.0;
    return pow(retailPrice / anchor, -1.3).toDouble().clamp(0.05, 4.0);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'negotiated': currentNegotiatedPrice,
        'retail': retailPrice,
        'unlocked': isUnlocked,
        'spoiled': dailySpoiledUnits,
        'lost': dailyLostSales,
        'batches': batches.map((b) => b.toJson()).toList(),
      };

  void applyJson(Map<String, dynamic> j) {
    currentNegotiatedPrice = (j['negotiated'] as num).toDouble();
    retailPrice = (j['retail'] as num).toDouble();
    isUnlocked = j['unlocked'] as bool;
    dailySpoiledUnits = (j['spoiled'] as num?)?.toInt() ?? 0;
    dailyLostSales = (j['lost'] as num?)?.toInt() ?? 0;
    batches
      ..clear()
      ..addAll((j['batches'] as List)
          .map((e) => StockBatch.fromJson(Map<String, dynamic>.from(e))));
  }
}
