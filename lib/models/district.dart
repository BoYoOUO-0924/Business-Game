/// 都會商圈模型 (City Commercial District)
class District {
  final String id;
  final String name;
  final String icon;
  final String tag;
  final String description;
  final String targetCustomers;
  final int baseTrafficPerHour;
  final double monthlyRent;
  final double depositRequired; // 押金
  final double minReputationRequired;
  final String rivalName;
  final String favoriteCategory; // 熱銷商品類別

  bool isLeased;
  String? branchStoreName;
  double marketShare; // 0.0 ~ 1.0

  District({
    required this.id,
    required this.name,
    required this.icon,
    required this.tag,
    required this.description,
    required this.targetCustomers,
    required this.baseTrafficPerHour,
    required this.monthlyRent,
    required this.depositRequired,
    required this.minReputationRequired,
    required this.rivalName,
    required this.favoriteCategory,
    this.isLeased = false,
    this.branchStoreName,
    this.marketShare = 0.0,
  });

  /// 預設五大特色都會商圈
  static List<District> getInitialDistricts() {
    return [
      District(
        id: 'old_town',
        name: '舊城幸福里',
        icon: '🏘️',
        tag: '文教與老社區',
        description: '傳統住宅區與老街，住戶黏著度高。租金最親民，白手起家的最佳創業發源地。',
        targetCustomers: '老街住戶、退休銀髮、國高中學生',
        baseTrafficPerHour: 650,
        monthlyRent: 3500.0,
        depositRequired: 7000.0,
        minReputationRequired: 0.0,
        rivalName: '老街雜貨鋪 (個體戶)',
        favoriteCategory: '即飲冷飲',
        isLeased: true,
        branchStoreName: '幸福里總店 (1號店)',
        marketShare: 0.45,
      ),
      District(
        id: 'tech_park',
        name: '高新矽谷園區',
        icon: '💻',
        tag: '高收入 IT 聚落',
        description: '大型軟體與半導體總部林立，工程師平日三餐與深夜加班補給需求極度旺盛。',
        targetCustomers: '軟體工程師、研發白領、創投業者',
        baseTrafficPerHour: 2200,
        monthlyRent: 8500.0,
        depositRequired: 17000.0,
        minReputationRequired: 55.0,
        rivalName: '頂客超商 ApexMart',
        favoriteCategory: '現煮研磨咖啡',
        isLeased: false,
        marketShare: 0.0,
      ),
      District(
        id: 'university',
        name: '大學青春城',
        icon: '🎓',
        tag: '極限夜貓商圈',
        description: '兩所國立大學交會處，傍晚至凌晨人聲鼎沸。便宜大碗的鮮食與宵夜零食是絕對剛需。',
        targetCustomers: '大學生、研究生、社團青年',
        baseTrafficPerHour: 3400,
        monthlyRent: 11000.0,
        depositRequired: 22000.0,
        minReputationRequired: 65.0,
        rivalName: '學聯福利社',
        favoriteCategory: '常溫休閒食品',
        isLeased: false,
        marketShare: 0.0,
      ),
      District(
        id: 'cbd_center',
        name: 'CBD 摩天金融中心',
        icon: '🏢',
        tag: '奢華高單價商圈',
        description: '摩天大樓與跨國企業總部所在地。高客單價、高毛利鮮食與精品烘焙的主戰場。',
        targetCustomers: '金融分析師、企業高管、商務律師',
        baseTrafficPerHour: 4800,
        monthlyRent: 22000.0,
        depositRequired: 44000.0,
        minReputationRequired: 78.0,
        rivalName: '全聯盟連鎖 OmniMart',
        favoriteCategory: '日式鮮食便當',
        isLeased: false,
        marketShare: 0.0,
      ),
      District(
        id: 'metro_hub',
        name: '大都會高鐵轉運樞紐',
        icon: '🚄',
        tag: '24小時川流不息',
        description: '高鐵、捷運與長途客運交匯核心，全天候 24 小時人流無休，快節奏外帶商品的吸金黑洞。',
        targetCustomers: '商務旅客、返鄉通勤族、國際觀光客',
        baseTrafficPerHour: 7500,
        monthlyRent: 38000.0,
        depositRequired: 76000.0,
        minReputationRequired: 88.0,
        rivalName: '捷客快站 MetroStop',
        favoriteCategory: '即飲冷飲',
        isLeased: false,
        marketShare: 0.0,
      ),
    ];
  }
}
