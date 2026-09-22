class ProductBrand {
  final String id;
  final String name;
  final String icon;
  final String slogan;
  final String category;

  const ProductBrand({
    required this.id,
    required this.name,
    required this.icon,
    required this.slogan,
    required this.category,
  });

  static const List<ProductBrand> brands = [
    ProductBrand(
      id: 'imei',
      name: '義美食品 (I-Mei)',
      icon: '🏰',
      slogan: '真材實料、老字號良心食品',
      category: '經典糕點與零食',
    ),
    ProductBrand(
      id: 'uni_president',
      name: '統一企業 (Uni-President)',
      icon: '🏭',
      slogan: '三好一公道、國民超商不可或缺之王',
      category: '速食麵與國民飲品',
    ),
    ProductBrand(
      id: 'heysong',
      name: '黑松企業 (HeySong)',
      icon: '🌲',
      slogan: '台灣人的氣泡回憶與清涼感',
      category: '經典氣泡汽水',
    ),
    ProductBrand(
      id: 'fresh_kitchen',
      name: '鮮食聯合中央廚房',
      icon: '🍱',
      slogan: '低溫冷鏈每日清晨現製配送',
      category: '米食便當與熟食',
    ),
    ProductBrand(
      id: 'ucc_japan',
      name: 'UCC 精品商用咖啡部',
      icon: '☕',
      slogan: '專業焙煎、職人級香氣拿鐵',
      category: '現萃現磨咖啡',
    ),
    ProductBrand(
      id: 'local_market',
      name: '宏泰在地雜貨老行',
      icon: '🏪',
      slogan: '街坊鄰里互助、少量批發應急好幫手',
      category: '傳統散裝零食',
    ),
  ];

  static ProductBrand? findById(String id) {
    try {
      return brands.firstWhere((b) => b.id == id);
    } catch (_) {
      return null;
    }
  }
}
