import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../models/negotiation.dart';

enum AiProvider {
  localRule, // 內建智慧商業規則引擎 (0延遲、不耗資源)
  ollama,    // 本機 Ollama 模型 (完全免費、隱私高)
  gemini,    // 雲端 Gemini API (極速、高品質)
}

class AiNegotiationService {
  static const double costFloor = 65.0; // 成本底線
  static const double listPrice = 100.0; // 原廠批發價

  String lastUsedEngine = '離線智慧規則';

  /// 主進入點：依據選取的 AI 引擎執行談判運算
  Future<NegotiationOutcome> negotiate({
    required String userMessage,
    required double targetPrice,
    required int orderQuantity,
    required int currentRelationship,
    AiProvider provider = AiProvider.ollama,
    String ollamaUrl = 'http://localhost:11434',
    String ollamaModel = 'gemma4:e4b-it-q4_K_M',
    String? geminiApiKey,
    String supplierName = '老李',
    String itemName = '咖啡豆',
    double? itemCostFloor,
    double? itemListPrice,
    String? customPersonalityPrompt,
  }) async {
    final floor = itemCostFloor ?? costFloor;
    final list = itemListPrice ?? listPrice;
    if (provider == AiProvider.ollama) {
      try {
        final outcome = await _negotiateWithOllama(
          userMessage: userMessage,
          targetPrice: targetPrice,
          orderQuantity: orderQuantity,
          relationship: currentRelationship,
          baseUrl: ollamaUrl,
          modelName: ollamaModel,
          supplierName: supplierName,
          itemName: itemName,
          costFloor: floor,
          listPrice: list,
          customPrompt: customPersonalityPrompt,
        ).timeout(const Duration(seconds: 18));
        lastUsedEngine = '本機 Ollama ($ollamaModel)';
        return outcome;
      } catch (e) {
        // 若 Ollama 逾時或未開，自動無縫降級至規則引擎
        lastUsedEngine = '離線規則 (Ollama 備用)';
        final fallback = _simulateSupplierEvaluation(
          userMessage: userMessage,
          targetPrice: targetPrice,
          orderQuantity: orderQuantity,
          relationship: currentRelationship,
          supplierName: supplierName,
          itemName: itemName,
          costFloor: floor,
          listPrice: list,
        );
        return NegotiationOutcome(
          status: fallback.status,
          agreedUnitPrice: fallback.agreedUnitPrice,
          relationshipChange: fallback.relationshipChange,
          dialogue: '【本機 AI 回應較慢，由備用引擎即時回覆】\n${fallback.dialogue}',
          reasoning: 'Ollama 呼叫失敗或超時 ($e)，自動啟用備用商業邏輯。',
        );
      }
    } else if (provider == AiProvider.gemini && geminiApiKey != null && geminiApiKey.isNotEmpty) {
      try {
        final outcome = await _negotiateWithGemini(
          userMessage: userMessage,
          targetPrice: targetPrice,
          orderQuantity: orderQuantity,
          relationship: currentRelationship,
          apiKey: geminiApiKey,
          supplierName: supplierName,
          itemName: itemName,
          costFloor: floor,
          listPrice: list,
        ).timeout(const Duration(seconds: 10));
        lastUsedEngine = 'Google Gemini API';
        return outcome;
      } catch (e) {
        lastUsedEngine = '離線規則 (Gemini 備用)';
        return _simulateSupplierEvaluation(
          userMessage: userMessage,
          targetPrice: targetPrice,
          orderQuantity: orderQuantity,
          relationship: currentRelationship,
          supplierName: supplierName,
          itemName: itemName,
          costFloor: floor,
          listPrice: list,
        );
      }
    } else {
      // 預設純本機商業規則引擎
      lastUsedEngine = '離線智慧規則';
      await Future.delayed(Duration(milliseconds: 300 + Random().nextInt(300)));
      return _simulateSupplierEvaluation(
        userMessage: userMessage,
        targetPrice: targetPrice,
        orderQuantity: orderQuantity,
        relationship: currentRelationship,
        supplierName: supplierName,
        itemName: itemName,
        costFloor: floor,
        listPrice: list,
      );
    }
  }

  /// 呼叫本機 Ollama 的 Chat API
  Future<NegotiationOutcome> _negotiateWithOllama({
    required String userMessage,
    required double targetPrice,
    required int orderQuantity,
    required int relationship,
    required String baseUrl,
    required String modelName,
    String supplierName = '老李',
    String itemName = '咖啡豆',
    double costFloor = 65.0,
    double listPrice = 100.0,
    String? customPrompt,
  }) async {
    final uri = Uri.parse('$baseUrl/api/chat');

    final systemPrompt = customPrompt ?? '''
你現在扮演食品批發商負責人「$supplierName」。
【商業背景】
- 商品：$itemName。官方批發牌價：\$$listPrice/件。你的進貨成本底線：\$$costFloor/件（低於底線絕對賠錢不賣）。
- 玩家採購量：$orderQuantity 件
- 玩家提議出價：\$$targetPrice / 件
- 玩家與你好感度：$relationship / 100

【決策規則】
1. 若出價 < $costFloor：破局拒絕 (status: "rejected")，成交價維持 $listPrice，好感度扣分。
2. 若出價 >= ${costFloor * 1.25} 或大量採購(>=50件)：可同意成交 (status: "accepted")，成交價為玩家出價，好感度加分。
3. 若出價在 $costFloor ~ ${costFloor * 1.25} 之間：提出折衷報價 (status: "counter_offer")。

你必須只輸出 JSON 物件，格式如下（不要包含額外的說明文字或 Markdown 標籤）：
{
  "status": "accepted" 或 "counter_offer" 或 "rejected",
  "final_unit_price": 數字,
  "relationship_change": 整數(-5到5),
  "dialogue": "40字以內的$supplierName口吻回話",
  "reasoning": "簡短理由"
}
''';

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json; charset=utf-8'},
      body: jsonEncode({
        'model': modelName,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userMessage},
        ],
        'stream': false,
        'options': {
          'temperature': 0.7,
        },
      }),
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      final content = decoded['message']?['content'] as String? ?? '';
      return _parseJsonOutcome(content, targetPrice);
    } else {
      throw Exception('Ollama error status: ${response.statusCode}');
    }
  }

  /// 呼叫雲端 Gemini API (REST)
  Future<NegotiationOutcome> _negotiateWithGemini({
    required String userMessage,
    required double targetPrice,
    required int orderQuantity,
    required int relationship,
    required String apiKey,
    String supplierName = '老李',
    String itemName = '咖啡豆',
    double costFloor = 65.0,
    double listPrice = 100.0,
  }) async {
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey',
    );

    final prompt = '''
扮演批發商「$supplierName」。商品 $itemName 牌價 \$$listPrice，成本底線 \$$costFloor。
採購量：$orderQuantity 件，出價：\$$targetPrice，好感度：$relationship。
玩家說話：「$userMessage」
請以 JSON 回應：
{"status": "accepted"|"counter_offer"|"rejected", "final_unit_price": 數字, "relationship_change": 整數, "dialogue": "話術", "reasoning": "理由"}
''';

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [{'text': prompt}]
          }
        ],
        'generationConfig': {
          'responseMimeType': 'application/json',
          'temperature': 0.7,
        },
      }),
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      final rawText = decoded['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '{}';
      return _parseJsonOutcome(rawText, targetPrice);
    } else {
      throw Exception('Gemini API returned status ${response.statusCode}');
    }
  }

  /// 解析 LLM 輸出的 JSON
  NegotiationOutcome _parseJsonOutcome(String rawJson, double fallbackTargetPrice) {
    try {
      // 清除可能存在的 markdown 程式碼區塊包裹
      String cleaned = rawJson.trim();
      if (cleaned.startsWith('```')) {
        cleaned = cleaned.replaceAll(RegExp(r'^```(json)?\n?'), '').replaceAll(RegExp(r'\n?```$'), '');
      }
      final jsonStart = cleaned.indexOf('{');
      final jsonEnd = cleaned.lastIndexOf('}');
      if (jsonStart != -1 && jsonEnd != -1) {
        cleaned = cleaned.substring(jsonStart, jsonEnd + 1);
      }

      final map = jsonDecode(cleaned) as Map<String, dynamic>;
      return NegotiationOutcome.fromMap(map);
    } catch (_) {
      // 若 JSON 解析失敗，提取對話文字並保守給予折衷價
      return NegotiationOutcome(
        status: NegotiationStatus.counterOffer,
        agreedUnitPrice: 85.0,
        relationshipChange: 1,
        dialogue: rawJson.length > 80 ? '${rawJson.substring(0, 80)}...' : rawJson,
        reasoning: '從非標準格式中提取回覆。',
      );
    }
  }

  /// 備用/離線智慧商業規則運算 (相容各家供應商)
  NegotiationOutcome _simulateSupplierEvaluation({
    required String userMessage,
    required double targetPrice,
    required int orderQuantity,
    required int relationship,
    String supplierName = '老李',
    String itemName = '咖啡豆',
    double costFloor = 65.0,
    double listPrice = 100.0,
  }) {
    final lowerMsg = userMessage.toLowerCase();
    final bool mentionsVolume = lowerMsg.contains('大量') ||
        lowerMsg.contains('很多') ||
        lowerMsg.contains('長期') ||
        orderQuantity >= 50;
    final bool isPolite = lowerMsg.contains('請') ||
        lowerMsg.contains('拜託') ||
        lowerMsg.contains('照顧') ||
        lowerMsg.contains('合作') ||
        lowerMsg.contains('經理') ||
        lowerMsg.contains('廠長') ||
        lowerMsg.contains('老闆');
    final bool isAggressive = lowerMsg.contains('搶錢') ||
        lowerMsg.contains('黑心') ||
        lowerMsg.contains('太貴') ||
        lowerMsg.contains('別家');

    if (targetPrice < costFloor) {
      return NegotiationOutcome(
        status: NegotiationStatus.rejected,
        agreedUnitPrice: listPrice,
        relationshipChange: -5,
        dialogue: '$supplierName：「做生意不是這樣搞的！一件 \$$targetPrice 我們直接虧本，別家批發商也不可能給你這個價！」',
        reasoning: '出價低於成本底線 \$$costFloor，視為無誠意漫天殺價。',
      );
    }

    double acceptablePrice = listPrice * 0.85;
    if (relationship > 70) acceptablePrice -= (listPrice * 0.05);
    if (orderQuantity >= 40) acceptablePrice -= (listPrice * 0.05);
    if (mentionsVolume) acceptablePrice -= (listPrice * 0.03);
    if (isPolite) acceptablePrice -= (listPrice * 0.02);
    if (isAggressive) acceptablePrice += (listPrice * 0.04);

    acceptablePrice = max(costFloor, acceptablePrice);

    if (targetPrice >= acceptablePrice) {
      int relDelta = 4;
      if (orderQuantity >= 50) relDelta += 3;
      if (isPolite) relDelta += 2;

      String reply = '$supplierName：「看在你採購 $orderQuantity 件且誠意十足的份上，這批$itemName就照你說的單價 \$$targetPrice 簽約！合作愉快！」';

      return NegotiationOutcome(
        status: NegotiationStatus.agreed,
        agreedUnitPrice: targetPrice,
        relationshipChange: relDelta,
        dialogue: reply,
        reasoning: '出價符合底線，採購量充足，達成共識。',
      );
    } else {
      final counterPrice = ((targetPrice + acceptablePrice) / 2).roundToDouble();
      int relDelta = isAggressive ? -2 : 1;

      return NegotiationOutcome(
        status: NegotiationStatus.counterOffer,
        agreedUnitPrice: counterPrice,
        relationshipChange: relDelta,
        dialogue:
            '$supplierName：「一口氣砍到 \$$targetPrice 真的太硬了！這樣吧，各退一步算你單價 \$$counterPrice，如果可以現在就開單立約！」',
        reasoning: '出價偏低，提出折衷讓利方案 \$$counterPrice。',
      );
    }
  }
}
