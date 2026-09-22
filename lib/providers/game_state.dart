import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chapter_quest.dart';
import '../models/company.dart';
import '../models/employee.dart';
import '../models/inventory_item.dart';
import '../models/market_event.dart';
import '../models/negotiation.dart';
import '../models/quest.dart';
import '../models/store_fixture.dart';
import '../models/supplier.dart';
import '../services/ai_negotiation_service.dart';

class GameState extends ChangeNotifier {
  final Company company = Company();
  final AiNegotiationService _negotiationService = AiNegotiationService();

  late final List<InventoryItem> items;
  final List<NegotiationMessage> negotiationHistory = [];
  final List<String> businessLogs = [];

  // 人事與排班
  final List<Employee> hiredStaff = [];
  final List<Employee> candidatePool = [];

  // 多重供應商批發地圖系統
  late final List<Supplier> suppliers;
  String selectedSupplierId = 'lao_li';

  // 實體設備與裝潢系統
  late final List<StoreFixture> fixtures;

  // 四階段主線創業進程系統
  late final List<ChapterStory> chapters;
  int currentChapterIndex = 0;
  int totalCustomersServed = 0;

  // 門市實體 2.5D 微觀事件串流
  final List<Map<String, dynamic>> recentCustomerEvents = [];

  // 動態市場事件
  MarketEvent? activeEvent;

  // 成就與里程碑
  late final List<Quest> quests;

  int supplierRelationship = 50; // 0 - 100 (對應當前選取批發商)
  bool isAutoPlaying = false;

  /// 連續入不敷出的天數；連 3 天現金為負即宣告倒閉
  int consecutiveInsolventDays = 0;
  bool isBankrupt = false;
  Timer? _tickerTimer;
  bool isNegotiating = false;

  // AI 引擎設定
  AiProvider aiProvider = AiProvider.ollama;
  String ollamaModel = 'gemma4:e4b-it-q4_K_M';
  String ollamaUrl = 'http://localhost:11434';
  String geminiApiKey = '';

  String get currentAiEngine => _negotiationService.lastUsedEngine;

  Supplier get selectedSupplier =>
      suppliers.firstWhere((s) => s.id == selectedSupplierId, orElse: () => suppliers.first);

  ChapterStory get currentChapter => chapters[currentChapterIndex];

  void setAiProvider(AiProvider provider) {
    aiProvider = provider;
    notifyListeners();
  }

  void selectSupplier(String supplierId) {
    selectedSupplierId = supplierId;
    supplierRelationship = selectedSupplier.relationship;

    // 添加切換供應商的問候引導
    final supplier = selectedSupplier;
    negotiationHistory.add(
      NegotiationMessage(
        sender: supplier.contactPerson,
        text: '你好！我是${supplier.name}的${supplier.contactPerson}。${supplier.description} 想採購什麼或洽談合作？',
        isUser: false,
      ),
    );

    notifyListeners();
  }

  GameState() {
    // 1. 初始化商品庫（結合真實國民品牌與經典商品）
    items = [
      // 基礎商品 (保持 ID 與測試相容)
      InventoryItem(
        id: 'coffee_bean',
        name: '阿拉比卡現磨咖啡豆',
        icon: '☕',
        category: '原物料',
        stock: 0,
        wholesaleCost: 100.0,
        currentNegotiatedPrice: 100.0,
        retailPrice: 180.0,
        baseHourlyDemand: 8.0,
        brandName: '宏泰在地雜貨',
        supplierId: 'lao_li',
        requiredFixtureId: 'coffee_bar',
      ),
      InventoryItem(
        id: 'iced_tea',
        name: '高山冰鎮烏龍茶',
        icon: '🧋',
        category: '即飲冷飲',
        stock: 90,
        wholesaleCost: 35.0,
        currentNegotiatedPrice: 35.0,
        retailPrice: 60.0,
        baseHourlyDemand: 14.0,
        brandName: '宏泰在地雜貨',
        supplierId: 'lao_li',
        requiredFixtureId: 'snack_shelf',
      ),
      InventoryItem(
        id: 'potato_chips',
        name: '經典起司洋芋片',
        icon: '🥔',
        category: '休閒零食',
        stock: 80,
        wholesaleCost: 25.0,
        currentNegotiatedPrice: 25.0,
        retailPrice: 45.0,
        baseHourlyDemand: 16.0,
        brandName: '宏泰在地雜貨',
        supplierId: 'lao_li',
        requiredFixtureId: 'snack_shelf',
      ),
      InventoryItem(
        id: 'bento',
        name: '日式照燒雞便當',
        icon: '🍱',
        category: '鮮食便當',
        stock: 0,
        wholesaleCost: 60.0,
        currentNegotiatedPrice: 60.0,
        retailPrice: 110.0,
        baseHourlyDemand: 11.0,
        isPerishable: true,
        shelfLifeHours: 16,
        brandName: '鮮食聯合廚房',
        supplierId: 'central_kitchen',
        requiredFixtureId: 'fresh_warmer',
      ),
      InventoryItem(
        id: 'sandwich',
        name: '鮮奶草莓三明治',
        icon: '🥪',
        category: '鮮食輕食',
        stock: 0,
        wholesaleCost: 30.0,
        currentNegotiatedPrice: 30.0,
        retailPrice: 55.0,
        baseHourlyDemand: 9.0,
        isPerishable: true,
        shelfLifeHours: 18,
        brandName: '鮮食聯合廚房',
        supplierId: 'central_kitchen',
        requiredFixtureId: 'fresh_warmer',
      ),
      InventoryItem(
        id: 'hotdog',
        name: '現烤脆皮熱狗',
        icon: '🌭',
        category: '熟食小吃',
        stock: 0,
        wholesaleCost: 20.0,
        currentNegotiatedPrice: 20.0,
        retailPrice: 40.0,
        baseHourlyDemand: 13.0,
        brandName: '鮮食聯合廚房',
        supplierId: 'central_kitchen',
        requiredFixtureId: 'fresh_warmer',
      ),

      // 國民真實品牌熱銷陣容
      InventoryItem(
        id: 'imei_puff',
        name: '義美小泡芙 (香濃牛奶)',
        icon: '🥐',
        category: '休閒零食',
        stock: 60,
        wholesaleCost: 24.0,
        currentNegotiatedPrice: 24.0,
        retailPrice: 38.0,
        baseHourlyDemand: 15.0,
        brandName: '義美食品 (I-Mei)',
        supplierId: 'imei_foods',
        requiredFixtureId: 'snack_shelf',
      ),
      InventoryItem(
        id: 'mine_shine_tea',
        name: '麥香奶茶 (300ml 經典包)',
        icon: '🧋',
        category: '即飲冷飲',
        stock: 100,
        wholesaleCost: 9.0,
        currentNegotiatedPrice: 9.0,
        retailPrice: 15.0,
        baseHourlyDemand: 22.0,
        brandName: '統一企業',
        supplierId: 'uni_president',
        requiredFixtureId: 'snack_shelf',
      ),
      InventoryItem(
        id: 'chaliwon_tea',
        name: '茶裏王日式無糖綠茶',
        icon: '🍵',
        category: '即飲冷飲',
        stock: 0,
        wholesaleCost: 15.0,
        currentNegotiatedPrice: 15.0,
        retailPrice: 25.0,
        baseHourlyDemand: 18.0,
        brandName: '統一企業',
        supplierId: 'uni_president',
        requiredFixtureId: 'drink_cooler',
      ),
      InventoryItem(
        id: 'manhan_noodle',
        name: '滿漢大餐蔥燒牛肉麵',
        icon: '🍜',
        category: '休閒零食',
        stock: 50,
        wholesaleCost: 38.0,
        currentNegotiatedPrice: 38.0,
        retailPrice: 59.0,
        baseHourlyDemand: 12.0,
        brandName: '統一企業',
        supplierId: 'uni_president',
        requiredFixtureId: 'snack_shelf',
      ),
      InventoryItem(
        id: 'uni_pudding',
        name: '統一布丁 (經典焦糖)',
        icon: '🍮',
        category: '低溫甜點',
        stock: 0,
        wholesaleCost: 12.0,
        currentNegotiatedPrice: 12.0,
        retailPrice: 20.0,
        baseHourlyDemand: 14.0,
        isPerishable: true,
        shelfLifeHours: 36,
        brandName: '統一企業',
        supplierId: 'uni_president',
        requiredFixtureId: 'drink_cooler',
      ),
      InventoryItem(
        id: 'heysong_sars',
        name: '黑松沙士 (600ml 寶特瓶)',
        icon: '🥤',
        category: '即飲冷飲',
        stock: 0,
        wholesaleCost: 19.0,
        currentNegotiatedPrice: 19.0,
        retailPrice: 32.0,
        baseHourlyDemand: 13.0,
        brandName: '黑松企業',
        supplierId: 'uni_president',
        requiredFixtureId: 'drink_cooler',
      ),
      InventoryItem(
        id: 'onigiri_pork',
        name: '經典肉鬆御飯糰',
        icon: '🍙',
        category: '鮮食米食',
        stock: 0,
        wholesaleCost: 20.0,
        currentNegotiatedPrice: 20.0,
        retailPrice: 35.0,
        baseHourlyDemand: 16.0,
        isPerishable: true,
        shelfLifeHours: 18,
        brandName: '鮮食聯合廚房',
        supplierId: 'central_kitchen',
        requiredFixtureId: 'fresh_warmer',
      ),
      InventoryItem(
        id: 'railway_bento',
        name: '國民奮起湖鐵路便當',
        icon: '🍱',
        category: '鮮食便當',
        stock: 0,
        wholesaleCost: 55.0,
        currentNegotiatedPrice: 55.0,
        retailPrice: 95.0,
        baseHourlyDemand: 10.0,
        isPerishable: true,
        shelfLifeHours: 14,
        brandName: '鮮食聯合廚房',
        supplierId: 'central_kitchen',
        requiredFixtureId: 'fresh_warmer',
      ),
      InventoryItem(
        id: 'tea_egg',
        name: '所長特選茶葉蛋',
        icon: '🥚',
        category: '熟食小吃',
        stock: 0,
        wholesaleCost: 8.0,
        currentNegotiatedPrice: 8.0,
        retailPrice: 14.0,
        baseHourlyDemand: 20.0,
        isPerishable: true,
        shelfLifeHours: 20,
        brandName: '鮮食聯合廚房',
        supplierId: 'central_kitchen',
        requiredFixtureId: 'fresh_warmer',
      ),
      InventoryItem(
        id: 'ucc_latte',
        name: '現煮莊園特大熱拿鐵',
        icon: '☕',
        category: '現煮咖啡',
        stock: 0,
        wholesaleCost: 22.0,
        currentNegotiatedPrice: 22.0,
        retailPrice: 55.0,
        baseHourlyDemand: 12.0,
        brandName: 'UCC 精品商用咖啡部',
        supplierId: 'ucc_coffee',
        requiredFixtureId: 'coffee_bar',
      ),
    ];

    // 2. 初始化多重供應商
    suppliers = [
      Supplier(
        id: 'lao_li',
        name: '宏泰老糧行',
        contactPerson: '老李',
        avatar: '👴',
        brandTag: '在地雜貨',
        location: '民生西路老街商圈',
        description: '街坊鄰里老字號，少量散裝批發，無起訂門檻，講究江湖交情。',
        minOrderQuantity: 10,
        baseDiscount: 1.0,
        isUnlocked: true,
        unlockRequirementText: '開局即解鎖',
        relationship: 50,
        suppliedItemIds: const [], // 空清單 = 萬用在地貨源，可補任何已解鎖商品（無折扣）
        personalityPrompt: '市井江湖老店長，說話豪爽親切，看重誠意與定期來貨。',
      ),
      Supplier(
        id: 'uni_president',
        name: '統一企業直營經銷處',
        contactPerson: '王課長',
        avatar: '👔',
        brandTag: '國民龍頭',
        location: '新莊物流經銷總倉',
        description: '統包麥香、茶裏王、滿漢大餐與布丁，整箱大宗批發折扣最深，重視合約採購額。',
        minOrderQuantity: 40,
        baseDiscount: 0.88,
        isUnlocked: false,
        unlockRequirementText: '門市累積營業額達到 \$120,000 或完成主線第 1 章',
        relationship: 50,
        suppliedItemIds: ['mine_shine_tea', 'chaliwon_tea', 'manhan_noodle', 'uni_pudding', 'heysong_sars'],
        personalityPrompt: '西裝筆挺的大企業課長，談吐專業嚴謹，重視銷量預測與採購規模。',
      ),
      Supplier(
        id: 'imei_foods',
        name: '義美食品直營物流',
        contactPerson: '林經理',
        avatar: '👩‍💼',
        brandTag: '良心口碑',
        location: '南崁直營物流中心',
        description: '小泡芙與傳統豆奶專供，品質一流，自帶龐大鐵粉客群與口碑加成。',
        minOrderQuantity: 30,
        baseDiscount: 0.90,
        isUnlocked: false,
        unlockRequirementText: '門市商譽指數達到 70 分以上',
        relationship: 50,
        suppliedItemIds: ['imei_puff'],
        personalityPrompt: '講究品質與食品安全，重視門市衛生環境與商譽評價。',
      ),
      Supplier(
        id: 'central_kitchen',
        name: '鮮食聯合中央廚房',
        contactPerson: '陳廠長',
        avatar: '👨‍🍳',
        brandTag: '低溫冷鏈',
        location: '五股鮮食低溫配送園區',
        description: '每日清晨 06:00 低溫直送鐵路便當、肉鬆御飯糰與茶葉蛋，保證現做鮮度。',
        minOrderQuantity: 20,
        baseDiscount: 0.92,
        isUnlocked: false,
        unlockRequirementText: '門市添購【低溫冷藏展示櫃】或【鮮食加熱保溫台】',
        relationship: 50,
        suppliedItemIds: ['bento', 'sandwich', 'hotdog', 'onigiri_pork', 'railway_bento', 'tea_egg'],
        personalityPrompt: '帶廚師帽的熱情廠長，在乎便當冷鏈溫控與每日銷售回報。',
      ),
      Supplier(
        id: 'ucc_coffee',
        name: 'UCC 精品商用咖啡部',
        contactPerson: 'Sofia 總監',
        avatar: '☕',
        brandTag: '精品咖啡',
        location: '信義商貿金融大樓',
        description: '供應日本職人級高階焙煎咖啡豆與配方，專攻高毛利白領客群。',
        minOrderQuantity: 15,
        baseDiscount: 0.85,
        isUnlocked: false,
        unlockRequirementText: '門市規模升級至 Lv.2 並購置【現煮義式咖啡吧台】',
        relationship: 50,
        suppliedItemIds: ['ucc_latte'],
        personalityPrompt: '講究產地風味與萃取萃取率的品豆師，重視門市形象與品牌品味。',
      ),
    ];

    // 3. 初始化實體門市設備
    fixtures = [
      StoreFixture(
        id: 'cashier',
        name: '現代收銀櫃台機',
        icon: '🛒',
        type: FixtureType.cashier,
        description: '門市核心結帳站，等級越高顧客排隊結帳速度越快。',
        cost: 0,
        isPurchased: true,
        level: 1,
        maxCapacity: 0,
        gridX: 2,
        gridY: 4,
      ),
      StoreFixture(
        id: 'snack_shelf',
        name: '四層雙面零食泡麵架',
        icon: '🥔',
        type: FixtureType.snackShelf,
        description: '陳列洋芋片、小泡芙、滿漢大餐與常溫麥香飲品。',
        cost: 0,
        isPurchased: true,
        level: 1,
        maxCapacity: 700,
        gridX: 4,
        gridY: 2,
      ),
      StoreFixture(
        id: 'drink_cooler',
        name: '雙門飲料低溫展示櫃',
        icon: '🧊',
        type: FixtureType.drinkCooler,
        description: '保持 4°C 恆溫，陳列茶裏王、黑松沙士與統一布丁。',
        cost: 3500,
        isPurchased: false,
        level: 1,
        maxCapacity: 550,
        gridX: 1,
        gridY: 1,
      ),
      StoreFixture(
        id: 'fresh_warmer',
        name: '鮮食微波與茶葉蛋保溫台',
        icon: '🍱',
        type: FixtureType.freshWarmer,
        description: '恆溫保溫熱賣茶葉蛋與奮起湖鐵路便當。',
        cost: 4200,
        isPurchased: false,
        level: 1,
        maxCapacity: 450,
        gridX: 5,
        gridY: 3,
      ),
      StoreFixture(
        id: 'coffee_bar',
        name: '現煮義式咖啡吧台',
        icon: '☕',
        type: FixtureType.coffeeBar,
        description: '高壓萃取職人莊園拿鐵，白領高毛利核心利器。',
        cost: 6500,
        isPurchased: false,
        level: 1,
        maxCapacity: 300,
        gridX: 1,
        gridY: 3,
      ),
    ];

    // 4. 初始化四階段創業主線
    chapters = [
      ChapterStory(
        chapterNumber: 1,
        title: '第 1 章：巷弄小雜貨起步',
        subtitle: '白手起家・親力親為',
        icon: '🏪',
        storyIntro: '頂下這間轉角小雜貨，資金雖少但滿懷雄心！老闆兼當收銀與理貨員，打好社區口碑。',
        rewardCash: 3500,
        rewardReputation: 8,
        unlockSummary: '解鎖【統一企業直營經銷處】洽談資格，解鎖【員工招募大廳】。',
        goals: [
          ChapterGoal(
            id: 'c1_g1',
            title: '親自接待顧客',
            description: '店面結帳服務累計滿 1,200 位顧客',
            targetValue: 1200,
            metricType: 'customers_served',
          ),
          ChapterGoal(
            id: 'c1_g2',
            title: '營收破萬',
            description: '累計營業額達到 \$50,000',
            targetValue: 50000,
            metricType: 'revenue',
          ),
          ChapterGoal(
            id: 'c1_g3',
            title: '資本穩健',
            description: '現金存量推進到 \$70,000 以上',
            targetValue: 70000,
            metricType: 'cash',
          ),
        ],
      ),
      ChapterStory(
        chapterNumber: 2,
        title: '第 2 章：現代化超商轉型',
        subtitle: '引進低溫冷鏈・組建班底',
        icon: '🍱',
        storyIntro: '單靠常溫雜貨毛利有限，添購雙門冷藏展示櫃，前往五股鮮食工廠簽訂每日現做便當合約！',
        rewardCash: 6000,
        rewardReputation: 12,
        unlockSummary: '解鎖【義美食品直營物流】直購權，解鎖中型門市貨架擴增許可。',
        goals: [
          ChapterGoal(
            id: 'c2_g1',
            title: '設備升級',
            description: '在店內購置【雙門飲料冷藏展示櫃】',
            targetValue: 1,
            metricType: 'fixture_purchased',
          ),
          ChapterGoal(
            id: 'c2_g2',
            title: '組建早晚班',
            description: '聘請至少 4 名員工排定輪班',
            targetValue: 4,
            metricType: 'hired_staff',
          ),
          ChapterGoal(
            id: 'c2_g3',
            title: '單日破萬營收',
            description: '單日營業額突破 \$40,000',
            targetValue: 40000,
            metricType: 'daily_revenue',
          ),
        ],
      ),
      ChapterStory(
        chapterNumber: 3,
        title: '第 3 章：24H 旗艦營運',
        subtitle: '現煮香氣・全天候不夜城',
        icon: '☕',
        storyIntro: '引進 UCC 莊園咖啡吧台，全面開啟大夜班，打造 24 小時燈火通明的社區避風港！',
        rewardCash: 10000,
        rewardReputation: 15,
        unlockSummary: '取得【一級大宗代理合約】，批發進貨全面享額外 15% 折扣！',
        goals: [
          ChapterGoal(
            id: 'c3_g1',
            title: '現煮吧台',
            description: '在店內裝設【現煮義式咖啡吧台】',
            targetValue: 1,
            metricType: 'fixture_purchased',
          ),
          ChapterGoal(
            id: 'c3_g2',
            title: '商譽指標',
            description: '門市商譽指數衝破 80 分',
            targetValue: 80,
            metricType: 'reputation',
          ),
          ChapterGoal(
            id: 'c3_g3',
            title: '累積大額銷量',
            description: '累計銷售商品超過 25,000 件',
            targetValue: 25000,
            metricType: 'units_sold',
          ),
        ],
      ),
      ChapterStory(
        chapterNumber: 4,
        title: '第 4 章：商圈連鎖霸王',
        subtitle: '大宗統購・跨區展店',
        icon: '👑',
        storyIntro: '門市成為全區指標名店！簽下商業區第二間旗艦門市租約，開啟連鎖超商商業帝國！',
        rewardCash: 25000,
        rewardReputation: 25,
        unlockSummary: '榮膺年度最佳零售企業獎，解鎖第二分店自動化經營模式！',
        goals: [
          ChapterGoal(
            id: 'c4_g1',
            title: '資本雄厚',
            description: '門市現金資產達到 \$400,000',
            targetValue: 400000,
            metricType: 'cash',
          ),
          ChapterGoal(
            id: 'c4_g2',
            title: '百萬級名店',
            description: '累積總營業額突破 \$1,500,000',
            targetValue: 1500000,
            metricType: 'revenue',
          ),
          ChapterGoal(
            id: 'c4_g3',
            title: '五星頂級口碑',
            description: '門市商譽指數達到 90 分以上',
            targetValue: 90,
            metricType: 'reputation',
          ),
        ],
      ),
    ];

    // 初始化員工：早晚班各一位，開局就有一張能運轉的班表。
    // 大夜班（00-08）刻意留白，作為玩家第一個成長決策。
    hiredStaff.addAll([
      Employee(
        id: 'staff_1',
        name: '林阿美',
        avatar: '👩‍💼',
        role: '正職收銀員',
        hourlyWage: 190.0,
        efficiency: 1.1,
        trait: '手腳俐落（結帳產能 +10%）',
        fatigue: 15,
        morale: 90,
        assignedShift: ShiftType.morning,
      ),
      Employee(
        id: 'staff_2',
        name: '吳承翰',
        avatar: '🧑‍💼',
        role: '正職收銀員',
        hourlyWage: 195.0,
        efficiency: 1.05,
        trait: '晚班熟手（夜間客群熟悉）',
        fatigue: 12,
        morale: 86,
        assignedShift: ShiftType.evening,
      ),
    ]);

    // 求職應徵候選池
    candidatePool.addAll([
      Employee(
        id: 'cand_1',
        name: '陳冠宇（小陳）',
        avatar: '👨‍💼',
        role: '儲備店長',
        hourlyWage: 230.0,
        efficiency: 1.25,
        trait: '細心帳務（減少鮮食損耗）',
        fatigue: 5,
        morale: 80,
      ),
      Employee(
        id: 'cand_2',
        name: '張家豪',
        avatar: '🧑‍🎓',
        role: '兼職工讀生',
        hourlyWage: 183.0,
        efficiency: 0.95,
        trait: '活力熱情（來客好感+5%）',
        fatigue: 10,
        morale: 85,
      ),
      Employee(
        id: 'cand_3',
        name: '王淑華',
        avatar: '👩‍🏫',
        role: '熟練大夜',
        hourlyWage: 210.0,
        efficiency: 1.15,
        trait: '抗壓性強（夜間不易疲累）',
        fatigue: 8,
        morale: 88,
      ),
    ]);

    // 經營目標里程碑清單 (原版相容)
    quests = [
      Quest(
        id: 'q_revenue_30k',
        title: '營運起步：第一桶金',
        description: '累計總營業額達到 \$500,000',
        icon: '💰',
        targetValue: 500000,
        rewardCash: 5000,
        rewardReputation: 5,
      ),
      Quest(
        id: 'q_negotiation',
        title: '商業談判家',
        description: '成功向老李砍價，使咖啡豆進貨價降至 \$85 或以下',
        icon: '🤝',
        targetValue: 85,
        rewardCash: 3500,
        rewardReputation: 8,
      ),
      Quest(
        id: 'q_hire_team',
        title: '組建團隊',
        description: '門市聘用員工總數達到 6 名或以上',
        icon: '👥',
        targetValue: 6,
        rewardCash: 4000,
        rewardReputation: 10,
      ),
      Quest(
        id: 'q_sales_volume',
        title: '熱銷名店',
        description: '全店累計商品銷售總量達到 30,000 件',
        icon: '📦',
        targetValue: 30000,
        rewardCash: 6000,
        rewardReputation: 12,
      ),
      Quest(
        id: 'q_reputation_80',
        title: '五星商譽',
        description: '門市顧客聲譽指數達到 80 分以上',
        icon: '⭐',
        targetValue: 80,
        rewardCash: 8000,
        rewardReputation: 15,
      ),
    ];

    // 初始化歡迎訊息
    negotiationHistory.add(
      NegotiationMessage(
        sender: '老李',
        text: '老闆你好啊！我是宏泰食品批發的老李。咖啡豆公定批發價是一袋 \$100，你要多少袋？有誠意的話可以跟你談談折扣！',
        isUser: false,
      ),
    );

    // 依初始已購置的設備推導哪些商品真的能上架販售
    refreshItemAvailability();

    businessLogs.add(
      '【創業第 1 天】超商營運系統啟動！初始資金 \$${company.cash.toInt()}。'
      '目前僅有收銀台與零食貨架，先把零食飲料賣起來，再添購冷藏櫃與鮮食保溫台擴充品項。',
    );

    _pristineSnapshot = jsonEncode(toJson());
  }

  // ─────────────────────────────────────────────────────────────
  // 營運模擬核心
  //
  // 模型：人流 (footfall) → 結帳產能 (capacity) → 成交 (sales)
  //
  // 人流由「商譽 × 時段 × 市場事件」決定，與員工人數無關；
  // 員工決定的是「這些客人有多少結得了帳」的上限。
  // 因此增聘人手不會憑空創造需求，只會減少流失 —— 這是舊版
  // 把 efficiency 加總後直接乘進需求所造成的線性刷分漏洞的根因。
  // ─────────────────────────────────────────────────────────────

  /// 基準人流：商譽 50 分、離峰時段的每小時來客數。
  /// 對照真實超商日均約 800~1000 人次而定。
  static const double baseFootfallPerHour = 34.0;

  /// 單一員工每小時可服務的來客上限（再乘上其實際效率）。
  /// 對照真實超商收銀尖峰每小時 60~100 人次而定。
  /// 這個值決定了「人手」與「人流」的拉鋸：離峰一人綽綽有餘，
  /// 尖峰（11-14、17-20）單人會結不完，必須為尖峰班別加派人手。
  static const double checkoutThroughputPerStaff = 45.0;

  /// 商譽累加器：避免整數化造成的跳動，滿 ±1 才實際加減
  double _reputationAccumulator = 0.0;

  final Random _rng = Random();

  /// 當前時段的人流時段係數
  double footfallTimeFactor(int hour) {
    if ((hour >= 11 && hour <= 14) || (hour >= 17 && hour <= 20)) return 1.4;
    if (hour >= 0 && hour <= 6) return 0.25;
    return 1.0;
  }

  /// 此刻值班中的員工
  List<Employee> onDutyStaff(int hour) =>
      hiredStaff.where((e) => e.isOnDuty(hour)).toList();

  /// 此刻的結帳產能（每小時可服務人次）
  double checkoutCapacity(int hour) => onDutyStaff(hour)
      .fold(0.0, (acc, e) => acc + checkoutThroughputPerStaff * e.effectiveEfficiency);

  /// 門市此刻是否營業中（有人值班才算開門）
  bool get isStoreOpen => onDutyStaff(company.hour).isNotEmpty;

  /// 本時段預估來客數（未受結帳產能限制的原始人流）
  int projectedFootfall(int hour) {
    final eventMult = (activeEvent != null && activeEvent!.affectedCategory == 'all')
        ? activeEvent!.trafficMultiplier
        : 1.0;
    return (baseFootfallPerHour *
            footfallTimeFactor(hour) *
            (company.reputation / 50.0) *
            eventMult)
        .round();
  }

  /// 推進 1 小時遊戲時間
  void advanceHour() {
    if (isBankrupt) return;
    company.hour = (company.hour + 1) % 24;

    // 1. 市場事件倒數
    if (activeEvent != null) {
      activeEvent!.hoursRemaining -= 1;
      if (activeEvent!.isExpired) {
        businessLogs.insert(0, '📢 市場快訊結束：【${activeEvent!.title}】事件已落幕，市場恢復常態。');
        activeEvent = null;
      }
    }

    // 2. 人事：值班扣薪、疲勞累積；休息中恢復
    final onDuty = onDutyStaff(company.hour);
    for (final staff in hiredStaff) {
      if (staff.isOnDuty(company.hour)) {
        company.dailyWages += staff.hourlyWage;
        company.totalWages += staff.hourlyWage;
        company.cash -= staff.hourlyWage;
        staff.fatigue = min(100, staff.fatigue + 4);
        if (staff.fatigue > 80) {
          staff.morale = max(0, staff.morale - 2);
        }
      } else {
        staff.fatigue = max(0, staff.fatigue - 9);
        if (staff.fatigue < 40 && staff.morale < 95) {
          staff.morale = min(100, staff.morale + 2);
        }
      }
    }

    // 3. 無人值班 = 門市拉下鐵門。沒有營收，但也不會有客人上門抱怨，
    //    懲罰是「賺不到錢」而非商譽崩盤 —— 不做 24 小時是策略，不是失誤。
    if (onDuty.isEmpty) {
      _ageStockAndWriteOffSpoilage();
      if (company.hour == 0) _settleDailyAccounts();
      _checkAllProgress();
      notifyListeners();
      return;
    }

    company.dailyOpenHours += 1;

    // 4. 產生人流，並以結帳產能設上限
    final footfall =
        max(0, (projectedFootfall(company.hour) * (0.85 + _rng.nextDouble() * 0.3)).round());
    final capacity = checkoutCapacity(company.hour).floor();
    final canServe = min(footfall, capacity);
    final turnedAwayByQueue = footfall - canServe;

    if (turnedAwayByQueue > 0) {
      company.dailyCustomersLost += turnedAwayByQueue;
      if (turnedAwayByQueue >= 8) {
        businessLogs.insert(
          0,
          '🚶 大排長龍：${company.hour}:00 結帳人力不足，$turnedAwayByQueue 位客人放棄結帳離開，商譽受損。',
        );
      }
    }

    // 5. 逐位顧客決定要買什麼。顧客是「為了某商品而來」，
    //    該商品缺貨就掉頭走人 —— 缺貨因此真的會痛。
    final shoppable = items.where((i) => i.isUnlocked).toList();
    final weights = shoppable.map(_desireWeight).toList();
    final weightSum = weights.fold(0.0, (a, b) => a + b);

    double hourSales = 0.0;
    var served = 0;
    var lostToStockout = 0;
    final soldThisHour = <InventoryItem, int>{};

    if (weightSum > 0) {
      for (var c = 0; c < canServe; c++) {
        final wanted = _pickWeighted(shoppable, weights, weightSum);
        if (wanted.stock <= 0) {
          wanted.dailyLostSales += 1;
          lostToStockout += 1;
          continue;
        }
        wanted.consume(1);
        hourSales += wanted.retailPrice;
        served += 1;
        soldThisHour.update(wanted, (v) => v + 1, ifAbsent: () => 1);
      }
    } else {
      lostToStockout = canServe;
    }

    company.dailyCustomersLost += lostToStockout;
    company.dailyCustomersServed += served;
    company.totalUnitsSold += served;
    totalCustomersServed += served;

    soldThisHour.forEach((item, count) {
      _recordCustomerEvent(item, count, count * item.retailPrice);
    });

    if (lostToStockout >= 3) {
      final soldOut = shoppable.where((i) => i.stock <= 0).toList()
        ..sort((a, b) => b.dailyLostSales.compareTo(a.dailyLostSales));
      if (soldOut.isNotEmpty) {
        businessLogs.insert(
          0,
          '📉 缺貨流失：${company.hour}:00 有 $lostToStockout 位客人撲空，主因【${soldOut.first.name}】已售罄，請盡快補貨！',
        );
      }
    }

    company.dailyRevenue += hourSales;
    company.totalRevenue += hourSales;
    company.cash += hourSales;

    // 6. 商品老化與鮮食報廢
    _ageStockAndWriteOffSpoilage();

    // 7. 商譽：由本時段實際服務水準雙向調整
    _applyReputationForHour(served: served, lost: turnedAwayByQueue + lostToStockout);

    // 8. 跨日結算
    if (company.hour == 0) _settleDailyAccounts();

    _checkAllProgress();
    notifyListeners();
  }

  /// 顧客對某商品的慾望權重（與是否有貨無關 —— 想買的東西缺貨才會流失）
  double _desireWeight(InventoryItem item) {
    var w = item.baseHourlyDemand * item.priceElasticity();
    if (activeEvent != null &&
        activeEvent!.affectedCategory != 'all' &&
        activeEvent!.affectedCategory == item.category) {
      w *= activeEvent!.trafficMultiplier;
    }
    return w;
  }

  InventoryItem _pickWeighted(List<InventoryItem> pool, List<double> weights, double sum) {
    var roll = _rng.nextDouble() * sum;
    for (var i = 0; i < pool.length; i++) {
      roll -= weights[i];
      if (roll <= 0) return pool[i];
    }
    return pool.last;
  }

  /// 所有批次老化 1 小時，逾期鮮食整批報廢
  void _ageStockAndWriteOffSpoilage() {
    for (final item in items) {
      final spoiled = item.ageOneHourAndDiscard();
      if (spoiled > 0) {
        final cost = spoiled * item.currentNegotiatedPrice;
        company.dailySpoilageCost += cost;
        company.totalSpoilageCost += cost;
        _reputationAccumulator -= spoiled * 0.02;
        businessLogs.insert(
          0,
          '🍱 鮮食報廢：【${item.name}】整批超過 ${item.shelfLifeHours} 小時賞味期，報廢 $spoiled 件（損失 \$${cost.toInt()}）。',
        );
      }
    }
  }

  /// 商譽雙向調整：服務水準高於 80% 就上升，低於就下降。
  /// 舊版只有「無人值班 -1」一條單向路徑，商譽必定在 3 天內觸底且永不回升。
  void _applyReputationForHour({required int served, required int lost}) {
    final total = served + lost;
    if (total > 0) {
      final serviceRate = served / total;
      _reputationAccumulator += (serviceRate - 0.8) * 1.2;
    }

    while (_reputationAccumulator >= 1.0) {
      _reputationAccumulator -= 1.0;
      company.reputation = min(100, company.reputation + 1);
    }
    while (_reputationAccumulator <= -1.0) {
      _reputationAccumulator += 1.0;
      company.reputation = max(15, company.reputation - 1);
    }
  }

  void _checkAllProgress() {
    _checkChapterProgress();
    _checkSupplierUnlockStatus();
    _checkQuestsProgress();
  }

  void _recordCustomerEvent(InventoryItem item, int count, double revenue) {
    if (recentCustomerEvents.length > 12) {
      recentCustomerEvents.removeAt(0);
    }
    recentCustomerEvents.add({
      'time': '${company.hour.toString().padLeft(2, '0')}:00',
      'itemName': item.name,
      'icon': item.icon,
      'count': count,
      'revenue': revenue,
    });
  }

  /// 手動服務一位顧客（在 2.5D 畫布中點擊快速收銀）
  void serveManualCustomer() {
    if (!isStoreOpen) {
      businessLogs.insert(0, '🔒 門市目前無人值班，無法結帳。請先於「人事排班」安排班表。');
      notifyListeners();
      return;
    }
    final availableItems = items.where((i) => i.isUnlocked && i.stock > 0).toList();
    if (availableItems.isEmpty) return;

    final item = availableItems[_rng.nextInt(availableItems.length)];
    item.consume(1);
    final rev = item.retailPrice;

    company.dailyRevenue += rev;
    company.totalRevenue += rev;
    company.cash += rev;
    company.totalUnitsSold += 1;
    company.dailyCustomersServed += 1;
    totalCustomersServed += 1;

    _recordCustomerEvent(item, 1, rev);
    _checkChapterProgress();
    notifyListeners();
  }

  /// 每日午夜結算
  void _settleDailyAccounts() {
    company.cash -= company.dailyRent;
    company.totalExpenses += company.dailyRent;

    final net = company.dailyNetProfit;
    company.revenueHistory.add(company.dailyRevenue);
    company.netProfitHistory.add(net);
    if (company.revenueHistory.length > 7) company.revenueHistory.removeAt(0);
    if (company.netProfitHistory.length > 7) company.netProfitHistory.removeAt(0);

    final rate = (company.dailyServiceRate * 100).toStringAsFixed(0);
    businessLogs.insert(
      0,
      '📊【第 ${company.day} 天結算】營收 \$${company.dailyRevenue.toInt()}，淨利 \$${net.toInt()}'
      '（工資 \$${company.dailyWages.toInt()}、進貨 \$${company.dailyExpenses.toInt()}、'
      '報廢 \$${company.dailySpoilageCost.toInt()}、租金 \$${company.dailyRent.toInt()}）'
      '｜接客 ${company.dailyCustomersServed} 人，服務達成率 $rate%，營業 ${company.dailyOpenHours} 小時。',
    );

    if (company.cash < 0) {
      consecutiveInsolventDays += 1;
      final grace = 3 - consecutiveInsolventDays;
      if (grace > 0) {
        businessLogs.insert(
          0,
          '🚨 財務警報：門市現金已為負 \$${company.cash.toInt()}！'
          '請立刻減班、調整售價或出清庫存 —— 再連續 $grace 天週轉不靈就會被迫歇業。',
        );
      } else {
        isBankrupt = true;
        isAutoPlaying = false;
        _tickerTimer?.cancel();
        _tickerTimer = null;
        businessLogs.insert(
          0,
          '🏚️ 門市歇業：連續 3 天週轉不靈，房東收回店面，創業之路在第 ${company.day} 天畫下句點。',
        );
      }
    } else {
      consecutiveInsolventDays = 0;
    }

    _processStaffTurnover();

    company.day += 1;
    company.dailyRevenue = 0.0;
    company.dailyExpenses = 0.0;
    company.dailyWages = 0.0;
    company.dailySpoilageCost = 0.0;
    company.dailyCustomersServed = 0;
    company.dailyCustomersLost = 0;
    company.dailyOpenHours = 0;

    for (final item in items) {
      item.dailySpoiledUnits = 0;
      item.dailyLostSales = 0;
    }

    _tryTriggerRandomMarketEvent();
    _refillCandidatePool();
  }

  // ─────────────────────────────────────────────────────────────
  // 人力市場
  //
  // 原本候選池只有固定 3 人，聘完就再也請不到人，
  // 但 24 小時營運至少需要 3 班、尖峰時段更需要兩人同時在線。
  // 這裡讓應徵者持續上門，商譽越高越容易找到好手。
  // ─────────────────────────────────────────────────────────────

  static const List<String> _surnames = [
    '陳', '林', '黃', '張', '李', '王', '吳', '劉', '蔡', '楊', '許', '鄭', '謝', '洪', '郭'
  ];
  static const List<String> _givenNames = [
    '雅婷', '家豪', '怡君', '志豪', '淑芬', '俊傑', '美玲', '建宏', '雅雯', '宗翰',
    '佳蓉', '柏翰', '思穎', '冠廷', '詩涵', '承恩', '于婷', '彥廷'
  ];

  int _candidateSerial = 100;

  /// 產生一位隨機求職者，素質受門市商譽影響
  Employee _generateCandidate() {
    _candidateSerial += 1;
    final prestige = (company.reputation - 50) / 100.0; // -0.35 ~ +0.5

    final roll = _rng.nextDouble() + prestige * 0.4;
    final String role;
    final double baseWage;
    final double baseEff;
    final String trait;

    if (roll > 0.82) {
      role = '儲備店長';
      baseWage = 235;
      baseEff = 1.30;
      trait = '調度高手（結帳產能大幅提升）';
    } else if (roll > 0.55) {
      role = '正職收銀員';
      baseWage = 205;
      baseEff = 1.12;
      trait = '穩健可靠（產能穩定）';
    } else if (roll > 0.28) {
      role = '熟練大夜';
      baseWage = 215;
      baseEff = 1.15;
      trait = '抗壓性強（夜間不易疲累）';
    } else {
      role = '兼職工讀生';
      baseWage = 185;
      baseEff = 0.92;
      trait = '薪資實惠（適合離峰時段）';
    }

    final avatars = ['🧑‍💼', '👩‍💼', '👨‍💼', '🧑‍🎓', '👩‍🏫', '🧑‍🍳'];
    return Employee(
      id: 'cand_$_candidateSerial',
      name: '${_surnames[_rng.nextInt(_surnames.length)]}${_givenNames[_rng.nextInt(_givenNames.length)]}',
      avatar: avatars[_rng.nextInt(avatars.length)],
      role: role,
      hourlyWage: (baseWage + _rng.nextInt(21) - 10).toDouble(),
      efficiency: double.parse((baseEff + (_rng.nextDouble() - 0.5) * 0.16).toStringAsFixed(2)),
      trait: trait,
      fatigue: 5 + _rng.nextInt(12),
      morale: 78 + _rng.nextInt(18),
    );
  }

  /// 每日補充人力市場，維持 3~5 位候選人
  void _refillCandidatePool() {
    if (candidatePool.length >= 5) return;
    final arrivals = candidatePool.length < 3 ? 2 : 1;
    for (var i = 0; i < arrivals; i++) {
      if (candidatePool.length >= 5) break;
      candidatePool.add(_generateCandidate());
    }
  }

  /// 士氣見底的員工會自請離職 —— 讓疲勞與士氣真正有後果
  void _processStaffTurnover() {
    final quitting = hiredStaff.where((e) => e.morale <= 20).toList();
    for (final e in quitting) {
      hiredStaff.remove(e);
      businessLogs.insert(
        0,
        '💔 人員流失：「${e.name}」因長期過勞、士氣低落提出辭呈並已離職。請注意排班與輪休！',
      );
    }
  }

  /// 市場事件圖鑑（存檔還原時也會用到）
  List<MarketEvent> get _allMarketEvents => [
      MarketEvent(
        id: 'heatwave',
        title: '極端高溫熱浪特報',
        description: '氣溫飆破 38 度，即飲冰飲、茶飲與冰品銷量暴增 100%！',
        icon: '☀️',
        trafficMultiplier: 2.0,
        costMultiplier: 1.0,
        affectedCategory: '即飲冷飲',
        durationHours: 36,
      ),
      MarketEvent(
        id: 'food_festival',
        title: '商圈週年慶人潮擠爆',
        description: '鄰近商圈舉辦大型慶典，全門市各品項客流狂飆 150%！',
        icon: '🎪',
        trafficMultiplier: 2.5,
        costMultiplier: 1.0,
        affectedCategory: 'all',
        durationHours: 48,
      ),
      MarketEvent(
        id: 'heavy_rain',
        title: '滯留鋒面連日暴雨',
        description: '豪雨特報民眾減少外出，白天來客量下滑 40%。',
        icon: '🌧️',
        trafficMultiplier: 0.6,
        costMultiplier: 1.0,
        affectedCategory: 'all',
        durationHours: 24,
      ),
      MarketEvent(
        id: 'shipping_delay',
        title: '港口物流塞港危機',
        description: '供應鏈受阻，批發進貨成本全面上漲 20%！',
        icon: '🚢',
        trafficMultiplier: 1.0,
        costMultiplier: 1.2,
        affectedCategory: 'all',
        durationHours: 36,
      ),
    ];

  /// 隨機觸發重大事件
  void _tryTriggerRandomMarketEvent() {
    if (activeEvent != null) return;
    if (_rng.nextDouble() > 0.35) return;

    final eventList = _allMarketEvents;
    activeEvent = eventList[_rng.nextInt(eventList.length)];
    businessLogs.insert(0, '🔥 突發重大事件：【${activeEvent!.title}】${activeEvent!.description}');
  }

  /// 購買門市實體設備
  bool purchaseFixture(String fixtureId) {
    final fixIndex = fixtures.indexWhere((f) => f.id == fixtureId);
    if (fixIndex == -1) return false;

    final fixture = fixtures[fixIndex];
    if (fixture.isPurchased) return false;

    if (company.cash < fixture.cost) {
      businessLogs.insert(0, '❌ 添購失敗：現金不足以支付「${fixture.name}」費用 \$${fixture.cost.toInt()}！');
      notifyListeners();
      return false;
    }

    company.cash -= fixture.cost;
    fixture.isPurchased = true;
    company.reputation = min(100, company.reputation + 4);

    final newlyUnlocked = refreshItemAvailability();

    businessLogs.insert(
      0,
      '🔨 設備添購成功：門市安裝【${fixture.name}】，商譽 +4，'
      '解鎖 ${newlyUnlocked.length} 項新商品：${newlyUnlocked.map((i) => i.name).join('、')}',
    );

    _checkSupplierUnlockStatus();
    _checkChapterProgress();
    notifyListeners();
    return true;
  }

  /// 升級實體設備
  bool upgradeFixture(String fixtureId) {
    final fixture = fixtures.firstWhere((f) => f.id == fixtureId);
    if (!fixture.isPurchased) return false;

    final cost = fixture.upgradeCost;
    if (company.cash < cost) return false;

    company.cash -= cost;
    fixture.level += 1;
    businessLogs.insert(
      0,
      '⬆️ 設備升級：【${fixture.name}】提升至 Lv.${fixture.level}，陳列容量提高至 ${fixture.currentCapacity} 件！',
    );
    notifyListeners();
    return true;
  }

  // ─────────────────────────────────────────────────────────────
  // 設備門檻與貨架容量
  //
  // 舊版 requiredFixtureId 與 isUnlocked 只被寫入、從未被讀取，
  // 導致 17 項商品無視設備全部開賣，整套章節進程失去意義。
  // ─────────────────────────────────────────────────────────────

  /// 依目前已購置的設備，重新推導每項商品是否可販售。
  /// 回傳這次「新解鎖」的商品清單。
  List<InventoryItem> refreshItemAvailability() {
    final newly = <InventoryItem>[];
    for (final item in items) {
      final fixture = fixtures.firstWhere(
        (f) => f.id == item.requiredFixtureId,
        orElse: () => fixtures.first,
      );
      final shouldUnlock = fixture.isPurchased;
      if (shouldUnlock && !item.isUnlocked) newly.add(item);
      item.isUnlocked = shouldUnlock;
    }
    return newly;
  }

  /// 某項商品所屬的陳列設備
  StoreFixture fixtureFor(InventoryItem item) => fixtures.firstWhere(
        (f) => f.id == item.requiredFixtureId,
        orElse: () => fixtures.first,
      );

  /// 該設備目前已陳列的總件數（同一設備上的商品共用容量）
  int shelfUsed(String fixtureId) => items
      .where((i) => i.requiredFixtureId == fixtureId)
      .fold(0, (a, i) => a + i.stock);

  /// 該項商品目前還能再進多少件（受所屬設備的剩餘容量限制）
  int remainingShelfSpaceFor(InventoryItem item) {
    final fixture = fixtureFor(item);
    if (!fixture.isPurchased) return 0;
    return max(0, fixture.currentCapacity - shelfUsed(fixture.id));
  }

  /// 補貨時實際適用的供應商：品牌供應商解鎖後才享折扣，
  /// 否則回頭找萬用在地貨源老李（原價，但隨時買得到）。
  Supplier effectiveSupplierFor(InventoryItem item) {
    final branded = suppliers.firstWhere(
      (s) => s.id == item.supplierId,
      orElse: () => suppliers.first,
    );
    if (branded.isUnlocked) return branded;
    return suppliers.firstWhere((s) => s.id == 'lao_li', orElse: () => suppliers.first);
  }

  /// 檢核主線章節達成狀況
  void _checkChapterProgress() {
    final chapter = currentChapter;
    if (chapter.isCompleted) return;

    for (final goal in chapter.goals) {
      if (goal.isAchieved) continue;

      switch (goal.metricType) {
        case 'customers_served':
          if (totalCustomersServed >= goal.targetValue) goal.isAchieved = true;
          break;
        case 'revenue':
          if (company.totalRevenue >= goal.targetValue) goal.isAchieved = true;
          break;
        case 'cash':
          if (company.cash >= goal.targetValue) goal.isAchieved = true;
          break;
        case 'daily_revenue':
          if (company.dailyRevenue >= goal.targetValue) goal.isAchieved = true;
          break;
        case 'reputation':
          if (company.reputation >= goal.targetValue) goal.isAchieved = true;
          break;
        case 'hired_staff':
          if (hiredStaff.length >= goal.targetValue) goal.isAchieved = true;
          break;
        case 'units_sold':
          if (company.totalUnitsSold >= goal.targetValue) goal.isAchieved = true;
          break;
        case 'fixture_purchased':
          if (goal.id == 'c2_g1') {
            final cooler = fixtures.firstWhere((f) => f.id == 'drink_cooler');
            if (cooler.isPurchased) goal.isAchieved = true;
          } else if (goal.id == 'c3_g1') {
            final coffee = fixtures.firstWhere((f) => f.id == 'coffee_bar');
            if (coffee.isPurchased) goal.isAchieved = true;
          }
          break;
      }
    }

    if (chapter.checkAllGoalsAchieved() && !chapter.isCompleted) {
      chapter.isCompleted = true;
      businessLogs.insert(
        0,
        '🏆 主線達成：恭喜完成【${chapter.title}】全部目標！快前往領取豐厚晉級獎勵！',
      );
    }
  }

  /// 領取主線章節晉級獎勵
  void claimChapterReward(int chapterNumber) {
    final chapterIndex = chapters.indexWhere((c) => c.chapterNumber == chapterNumber);
    if (chapterIndex == -1) return;

    final chapter = chapters[chapterIndex];
    if (!chapter.isCompleted || chapter.isClaimed) return;

    chapter.isClaimed = true;
    company.cash += chapter.rewardCash;
    company.reputation = min(100, company.reputation + chapter.rewardReputation);

    businessLogs.insert(
      0,
      '🎉 晉級授獎：【${chapter.title}】頒發獎金 \$${chapter.rewardCash.toInt()}，聲譽 +${chapter.rewardReputation}！${chapter.unlockSummary}',
    );

    // 切換至下一章
    if (currentChapterIndex < chapters.length - 1) {
      currentChapterIndex += 1;
    }

    _checkSupplierUnlockStatus();
    notifyListeners();
  }

  /// 自動檢查批發商解鎖條件
  void _checkSupplierUnlockStatus() {
    for (final s in suppliers) {
      if (s.isUnlocked) continue;

      bool shouldUnlock = false;
      switch (s.id) {
        case 'uni_president':
          if (company.totalRevenue >= 120000 || currentChapterIndex >= 1) {
            shouldUnlock = true;
          }
          break;
        case 'imei_foods':
          if (company.reputation >= 70 || currentChapterIndex >= 2) {
            shouldUnlock = true;
          }
          break;
        case 'central_kitchen':
          final cooler = fixtures.firstWhere((f) => f.id == 'drink_cooler');
          final warmer = fixtures.firstWhere((f) => f.id == 'fresh_warmer');
          if (cooler.isPurchased || warmer.isPurchased) {
            shouldUnlock = true;
          }
          break;
        case 'ucc_coffee':
          final coffeeBar = fixtures.firstWhere((f) => f.id == 'coffee_bar');
          if (coffeeBar.isPurchased && company.storeLevel >= 2) {
            shouldUnlock = true;
          }
          break;
      }

      if (shouldUnlock) {
        s.isUnlocked = true;
        businessLogs.insert(
          0,
          '🗺️ 商圈新貨源解鎖：成功開啟【${s.name}】採購合作渠道！可前往地圖拜訪洽談！',
        );
      }
    }
  }

  /// 檢核成就任務進度
  void _checkQuestsProgress() {
    final coffee = items.firstWhere((e) => e.id == 'coffee_bean');

    for (final q in quests) {
      if (q.isCompleted) continue;

      switch (q.id) {
        case 'q_revenue_30k':
          if (company.totalRevenue >= q.targetValue) q.isCompleted = true;
          break;
        case 'q_negotiation':
          if (coffee.currentNegotiatedPrice <= q.targetValue) q.isCompleted = true;
          break;
        case 'q_hire_team':
          if (hiredStaff.length >= q.targetValue) q.isCompleted = true;
          break;
        case 'q_sales_volume':
          if (company.totalUnitsSold >= q.targetValue) q.isCompleted = true;
          break;
        case 'q_reputation_80':
          if (company.reputation >= q.targetValue) q.isCompleted = true;
          break;
      }
    }
  }

  /// 領取成就獎勵
  void claimQuestReward(String questId) {
    final q = quests.firstWhere((e) => e.id == questId);
    if (!q.isCompleted || q.isClaimed) return;

    q.isClaimed = true;
    company.cash += q.rewardCash;
    company.reputation = min(100, company.reputation + q.rewardReputation);

    businessLogs.insert(
      0,
      '🎉 達成目標【${q.title}】：獲得獎金 \$${q.rewardCash.toInt()}，聲譽 +${q.rewardReputation}！',
    );
    notifyListeners();
  }

  /// 招募員工
  bool hireEmployee(Employee candidate) {
    const trainingFee = 1500.0;
    if (company.cash < trainingFee) {
      businessLogs.insert(0, '❌ 招聘失敗：現金不足以支付新人培訓費用 \$${trainingFee.toInt()}！');
      notifyListeners();
      return false;
    }

    company.cash -= trainingFee;
    candidatePool.removeWhere((e) => e.id == candidate.id);
    hiredStaff.add(candidate);

    businessLogs.insert(
      0,
      '🤝 人事任命：成功聘請「${candidate.name}」（${candidate.role}），時薪 \$${candidate.hourlyWage.toInt()}。',
    );
    _checkQuestsProgress();
    _checkChapterProgress();
    notifyListeners();
    return true;
  }

  /// 解僱員工
  void fireEmployee(String staffId) {
    final staff = hiredStaff.firstWhere((e) => e.id == staffId);
    hiredStaff.removeWhere((e) => e.id == staffId);
    businessLogs.insert(0, '📋 離職紀錄：「${staff.name}」已自門市離職。');
    notifyListeners();
  }

  /// 變更排班班次
  void assignShift(String staffId, ShiftType shift) {
    final staff = hiredStaff.firstWhere((e) => e.id == staffId);
    staff.assignedShift = shift;
    businessLogs.insert(0, '🕒 排班調動：${staff.name} 已指派至「${staff.shiftName}」。');
    notifyListeners();
  }

  /// 快進 1 整天 (24 小時)
  void advanceDay() {
    for (int i = 0; i < 24; i++) {
      advanceHour();
    }
  }

  /// 自動推進時間開關
  void toggleAutoPlay() {
    isAutoPlaying = !isAutoPlaying;
    if (isAutoPlaying) {
      _tickerTimer = Timer.periodic(const Duration(milliseconds: 1200), (_) {
        advanceHour();
      });
    } else {
      _tickerTimer?.cancel();
      _tickerTimer = null;
    }
    notifyListeners();
  }

  /// 某商品現在的實際進貨單價（含市場事件與供應商折扣）
  double effectiveUnitCost(InventoryItem item) {
    var price = item.currentNegotiatedPrice;
    if (activeEvent != null && activeEvent!.costMultiplier > 1.0) {
      price *= activeEvent!.costMultiplier;
    }
    return price * effectiveSupplierFor(item).effectiveWholesaleMultiplier;
  }

  /// 叫貨採購
  bool restockItem(String itemId, int quantity) {
    final itemIndex = items.indexWhere((e) => e.id == itemId);
    if (itemIndex == -1 || quantity <= 0) return false;

    final item = items[itemIndex];

    if (!item.isUnlocked) {
      final fixture = fixtureFor(item);
      businessLogs.insert(
        0,
        '🔒 採購失敗：「${item.name}」需要先在門市添購【${fixture.name}】才能陳列販售。',
      );
      notifyListeners();
      return false;
    }

    final space = remainingShelfSpaceFor(item);
    if (quantity > space) {
      final fixture = fixtureFor(item);
      businessLogs.insert(
        0,
        '❌ 採購失敗：【${fixture.name}】剩餘陳列空間僅 $space 件（容量 ${fixture.currentCapacity}，'
        '已陳列 ${shelfUsed(fixture.id)}）。可升級設備以擴充容量。',
      );
      notifyListeners();
      return false;
    }

    final supplier = effectiveSupplierFor(item);
    final totalCost = effectiveUnitCost(item) * quantity;

    if (company.cash < totalCost) {
      businessLogs.insert(0, '❌ 採購失敗：帳戶現金不足以支付 \$${totalCost.toInt()}！');
      notifyListeners();
      return false;
    }

    company.cash -= totalCost;
    company.dailyExpenses += totalCost;
    company.totalExpenses += totalCost;
    item.addStock(quantity); // 新批次，鮮食賞味期由此刻重新起算（僅限這一批）

    businessLogs.insert(
      0,
      '📦 採購成功：向【${supplier.name}】進貨 ${item.name} $quantity 件（花費 \$${totalCost.toInt()}）。',
    );
    notifyListeners();
    return true;
  }

  /// 明日的固定開銷（人事 + 租金），一鍵補貨會保留這筆錢
  double get projectedDailyFixedCost {
    var wages = 0.0;
    for (var h = 0; h < 24; h++) {
      for (final e in hiredStaff) {
        if (e.isOnDuty(h)) wages += e.hourlyWage;
      }
    }
    return wages + company.dailyRent;
  }

  /// 以目前班表推估，一整天會有多少來客真的結得了帳
  int get projectedDailyServedCustomers {
    var total = 0;
    for (var h = 0; h < 24; h++) {
      if (onDutyStaff(h).isEmpty) continue;
      total += min(projectedFootfall(h), checkoutCapacity(h).floor());
    }
    return total;
  }

  /// 推估某商品一整天會賣掉幾件（依顧客慾望權重分配當日來客）
  int expectedDailyDemand(InventoryItem item) {
    if (!item.isUnlocked) return 0;
    final totalWeight =
        items.where((i) => i.isUnlocked).fold(0.0, (a, i) => a + _desireWeight(i));
    if (totalWeight <= 0) return 0;
    return (projectedDailyServedCustomers * (_desireWeight(item) / totalWeight)).round();
  }

  /// 目前庫存還能撐幾小時（依今日推估銷速），無限則回傳 null
  double? hoursOfCoverFor(InventoryItem item) {
    final daily = expectedDailyDemand(item);
    if (daily <= 0) return null;
    final openHours = max(1, List.generate(24, (h) => h).where((h) => onDutyStaff(h).isNotEmpty).length);
    final hourlyBurn = daily / openHours;
    if (hourlyBurn <= 0) return null;
    return item.stock / hourlyBurn;
  }

  /// 一鍵補貨：依「預估銷量」而非平均分配來配貨 ——
  /// 熱銷品多進、冷門品少進，鮮食則以一日銷量為上限避免整批報廢。
  /// 會保留一日份的固定開銷當安全水位，避免把現金一次燒光後再也補不了貨。
  /// 回傳實際花費金額。
  double restockAllToCapacity({double daysOfStock = 1.5}) {
    final reserve = projectedDailyFixedCost;
    var spent = 0.0;
    var lines = 0;

    for (final fixture in fixtures.where((f) => f.isPurchased && f.currentCapacity > 0)) {
      final onShelf = items
          .where((i) => i.isUnlocked && i.requiredFixtureId == fixture.id)
          .toList();
      if (onShelf.isEmpty) continue;

      // 目標庫存：非鮮食備 daysOfStock 天，鮮食最多備一天（多了必報廢）
      final targets = <InventoryItem, int>{};
      for (final item in onShelf) {
        final daily = expectedDailyDemand(item);
        final days = item.isPerishable ? min(1.0, daysOfStock) : daysOfStock;
        targets[item] = (daily * days).ceil();
      }

      // 目標總量若超過貨架容量，等比例縮減
      final wanted = targets.values.fold(0, (a, b) => a + b);
      if (wanted > fixture.currentCapacity && wanted > 0) {
        final scale = fixture.currentCapacity / wanted;
        targets.updateAll((_, v) => (v * scale).floor());
      }

      // 缺口大的先補，現金不足時優先保住熱銷品
      final order = onShelf.toList()
        ..sort((a, b) => (targets[b]! - b.stock).compareTo(targets[a]! - a.stock));

      for (final item in order) {
        final gap = targets[item]! - item.stock;
        if (gap <= 0) continue;
        final unitCost = effectiveUnitCost(item);
        if (unitCost <= 0) continue;
        final affordable = ((company.cash - reserve) / unitCost).floor();
        final qty = min(gap, min(affordable, remainingShelfSpaceFor(item)));
        if (qty <= 0) continue;
        if (restockItem(item.id, qty)) {
          spent += unitCost * qty;
          lines += 1;
        }
      }
    }

    businessLogs.insert(
      0,
      lines > 0
          ? '🛒 一鍵補貨完成：依預估銷量配貨 $lines 項，總計花費 \$${spent.toInt()}。'
          : '🛒 一鍵補貨：庫存已足或現金不足（需保留週轉金 \$${reserve.toInt()}），未進行採購。',
    );
    notifyListeners();
    return spent;
  }

  /// 目前庫存吃緊（撐不到 4 小時）的商品，供 UI 發出補貨警示
  List<InventoryItem> get lowStockItems => items.where((i) {
        if (!i.isUnlocked) return false;
        final cover = hoursOfCoverFor(i);
        return cover != null && cover < 4;
      }).toList();
  /// 更新定價
  void updateRetailPrice(String itemId, double newPrice) {
    final item = items.firstWhere((e) => e.id == itemId);
    item.retailPrice = newPrice;
    notifyListeners();
  }

  /// 升級門市貨架
  bool upgradeStoreShelf() {
    const cost = 15000.0;
    if (company.cash < cost) return false;

    company.cash -= cost;
    company.storeLevel += 1;
    for (final f in fixtures.where((f) => f.isPurchased && f.currentCapacity > 0)) {
      f.level += 1;
    }
    businessLogs.insert(
      0,
      '🏗️ 門市升級成功：達到等級 ${company.storeLevel}，全門市陳列設備同步升級一級，容量大幅提升！',
    );
    _checkSupplierUnlockStatus();
    notifyListeners();
    return true;
  }

  /// 向供應商發送採購談判訊息
  Future<void> sendNegotiationMessage({
    required String userText,
    required double targetPrice,
    required int quantity,
    String? supplierId,
    String? itemId,
  }) async {
    final activeSupplierId = supplierId ?? selectedSupplierId;
    final supplier = suppliers.firstWhere((s) => s.id == activeSupplierId, orElse: () => suppliers.first);
    final targetItem = itemId != null
        ? items.firstWhere((i) => i.id == itemId, orElse: () => items.first)
        : items.firstWhere((i) => i.id == 'coffee_bean');

    isNegotiating = true;
    negotiationHistory.add(
      NegotiationMessage(
        sender: '玩家',
        text: '$userText (向 ${supplier.contactPerson} 提議【${targetItem.name}】單價: \$$targetPrice, 採購量: $quantity 件)',
        isUser: true,
      ),
    );
    notifyListeners();

    try {
      final outcome = await _negotiationService.negotiate(
        userMessage: userText,
        targetPrice: targetPrice,
        orderQuantity: quantity,
        currentRelationship: supplier.relationship,
        provider: aiProvider,
        ollamaUrl: ollamaUrl,
        ollamaModel: ollamaModel,
        geminiApiKey: geminiApiKey,
        supplierName: supplier.contactPerson,
        itemName: targetItem.name,
        itemCostFloor: targetItem.wholesaleCost * 0.65,
        itemListPrice: targetItem.wholesaleCost,
        customPersonalityPrompt: supplier.personalityPrompt,
      );

      supplier.relationship = max(0, min(100, supplier.relationship + outcome.relationshipChange));
      supplierRelationship = supplier.relationship;

      if (outcome.status == NegotiationStatus.agreed ||
          outcome.status == NegotiationStatus.counterOffer) {
        targetItem.currentNegotiatedPrice = outcome.agreedUnitPrice;
      }

      negotiationHistory.add(
        NegotiationMessage(
          sender: supplier.contactPerson,
          text: outcome.dialogue,
          isUser: false,
          outcome: outcome,
        ),
      );

      _checkQuestsProgress();
      _checkChapterProgress();
    } finally {
      isNegotiating = false;
      notifyListeners();
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 存檔 / 讀檔
  //
  // 舊版完全沒有持久化，關掉視窗整間店就消失了。
  // ─────────────────────────────────────────────────────────────

  static const String saveKey = 'business_sim_save_v1';

  /// 開局狀態的快照，供「重新開店」原地還原（GameState 內含大量
  /// late final 欄位，直接重建 provider 較麻煩，改為套用初始快照）
  String? _pristineSnapshot;

  /// 清空所有進度，回到第 1 天
  void resetToNewGame() {
    final snapshot = _pristineSnapshot;
    if (snapshot == null) return;

    _tickerTimer?.cancel();
    _tickerTimer = null;
    isAutoPlaying = false;
    isBankrupt = false;
    consecutiveInsolventDays = 0;
    isNegotiating = false;
    recentCustomerEvents.clear();
    negotiationHistory.clear();
    activeEvent = null;
    _candidateSerial = 100;

    applyJson(Map<String, dynamic>.from(jsonDecode(snapshot) as Map));

    negotiationHistory.add(
      NegotiationMessage(
        sender: '老李',
        text: '老闆你好啊！我是宏泰食品批發的老李。有什麼需要的，儘管開口！',
        isUser: false,
      ),
    );
    notifyListeners();
  }

  /// 是否已從存檔載入過（供 UI 顯示「繼續營業／重新開店」）
  bool hasLoadedSave = false;

  Map<String, dynamic> toJson() => {
        'version': 1,
        'savedAt': DateTime.now().toIso8601String(),
        'company': company.toJson(),
        'items': items.map((i) => i.toJson()).toList(),
        'staff': hiredStaff.map((e) => e.toJson()).toList(),
        'candidates': candidatePool.map((e) => e.toJson()).toList(),
        'fixtures': {
          for (final f in fixtures) f.id: {'purchased': f.isPurchased, 'level': f.level}
        },
        'suppliers': {
          for (final s in suppliers) s.id: {'unlocked': s.isUnlocked, 'relationship': s.relationship}
        },
        'quests': {
          for (final q in quests) q.id: {'completed': q.isCompleted, 'claimed': q.isClaimed}
        },
        'chapters': {
          for (final c in chapters)
            '${c.chapterNumber}': {
              'completed': c.isCompleted,
              'claimed': c.isClaimed,
              'goals': {for (final g in c.goals) g.id: g.isAchieved},
            }
        },
        'currentChapterIndex': currentChapterIndex,
        'totalCustomersServed': totalCustomersServed,
        'selectedSupplierId': selectedSupplierId,
        'repAccumulator': _reputationAccumulator,
        'insolventDays': consecutiveInsolventDays,
        'isBankrupt': isBankrupt,
        'logs': businessLogs.take(60).toList(),
        'activeEvent': activeEvent == null
            ? null
            : {'id': activeEvent!.id, 'hoursRemaining': activeEvent!.hoursRemaining},
      };

  void applyJson(Map<String, dynamic> j) {
    company.applyJson(Map<String, dynamic>.from(j['company']));

    final itemMap = {for (final e in (j['items'] as List)) e['id'] as String: e};
    for (final item in items) {
      final saved = itemMap[item.id];
      if (saved != null) item.applyJson(Map<String, dynamic>.from(saved));
    }

    hiredStaff
      ..clear()
      ..addAll((j['staff'] as List).map((e) => Employee.fromJson(Map<String, dynamic>.from(e))));
    candidatePool
      ..clear()
      ..addAll(
          (j['candidates'] as List).map((e) => Employee.fromJson(Map<String, dynamic>.from(e))));

    final fixMap = Map<String, dynamic>.from(j['fixtures']);
    for (final f in fixtures) {
      final saved = fixMap[f.id];
      if (saved != null) {
        f.isPurchased = saved['purchased'] as bool;
        f.level = (saved['level'] as num).toInt();
      }
    }

    final supMap = Map<String, dynamic>.from(j['suppliers']);
    for (final s in suppliers) {
      final saved = supMap[s.id];
      if (saved != null) {
        s.isUnlocked = saved['unlocked'] as bool;
        s.relationship = (saved['relationship'] as num).toInt();
      }
    }

    final questMap = Map<String, dynamic>.from(j['quests']);
    for (final q in quests) {
      final saved = questMap[q.id];
      if (saved != null) {
        q.isCompleted = saved['completed'] as bool;
        q.isClaimed = saved['claimed'] as bool;
      }
    }

    final chapterMap = Map<String, dynamic>.from(j['chapters']);
    for (final c in chapters) {
      final saved = chapterMap['${c.chapterNumber}'];
      if (saved != null) {
        c.isCompleted = saved['completed'] as bool;
        c.isClaimed = saved['claimed'] as bool;
        final goals = Map<String, dynamic>.from(saved['goals']);
        for (final g in c.goals) {
          g.isAchieved = goals[g.id] as bool? ?? false;
        }
      }
    }

    currentChapterIndex = (j['currentChapterIndex'] as num).toInt();
    totalCustomersServed = (j['totalCustomersServed'] as num).toInt();
    selectedSupplierId = j['selectedSupplierId'] as String;
    supplierRelationship = selectedSupplier.relationship;
    _reputationAccumulator = (j['repAccumulator'] as num?)?.toDouble() ?? 0.0;
    consecutiveInsolventDays = (j['insolventDays'] as num?)?.toInt() ?? 0;
    isBankrupt = j['isBankrupt'] as bool? ?? false;

    businessLogs
      ..clear()
      ..addAll((j['logs'] as List).map((e) => e as String));

    activeEvent = null;
    final savedEvent = j['activeEvent'];
    if (savedEvent != null) {
      final found = _allMarketEvents.where((e) => e.id == savedEvent['id']);
      if (found.isNotEmpty) {
        activeEvent = found.first..hoursRemaining = (savedEvent['hoursRemaining'] as num).toInt();
      }
    }

    refreshItemAvailability();
    notifyListeners();
  }

  /// 寫入本機存檔
  Future<void> save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(saveKey, jsonEncode(toJson()));
    } catch (e) {
      debugPrint('存檔失敗：$e');
    }
  }

  /// 讀取本機存檔，回傳是否成功載入
  Future<bool> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(saveKey);
      if (raw == null) return false;
      applyJson(Map<String, dynamic>.from(jsonDecode(raw) as Map));
      hasLoadedSave = true;
      businessLogs.insert(0, '💾 已讀取存檔：接續第 ${company.day} 天 ${company.hour}:00 的營運。');
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('讀檔失敗：$e');
      return false;
    }
  }

  /// 是否存在本機存檔
  static Future<bool> hasSave() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(saveKey) != null;
    } catch (_) {
      return false;
    }
  }

  /// 刪除存檔（重新開店）
  Future<void> deleteSave() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(saveKey);
    } catch (e) {
      debugPrint('刪除存檔失敗：$e');
    }
  }

  @override
  void dispose() {
    _tickerTimer?.cancel();
    super.dispose();
  }
}
