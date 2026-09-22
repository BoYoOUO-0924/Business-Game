import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/negotiation.dart';
import '../../providers/game_state.dart';
import '../../services/ai_negotiation_service.dart';

class NegotiationTab extends StatefulWidget {
  const NegotiationTab({super.key});

  @override
  State<NegotiationTab> createState() => _NegotiationTabState();
}

class _NegotiationTabState extends State<NegotiationTab> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  double _targetPrice = 75.0;
  int _orderQty = 60;

  final List<String> _quickPhrases = [
    '新店開張，老哥照顧一下！',
    '我一次叫 100 袋，能算便宜點嗎？',
    '長期穩定合作，算我一袋 \$75 行不行？',
    '這價格太硬了，隔壁批發商才賣 \$70！',
  ];

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GameState>();
    final coffee = state.items.firstWhere((i) => i.id == 'coffee_bean');

    return Column(
      children: [
        // 頂部 NPC 身份與好感度狀態列
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            color: Color(0xFF1E293B),
            border: Border(bottom: BorderSide(color: Colors.white10)),
          ),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 22,
                backgroundColor: Colors.amber,
                child: Text('👨‍💼', style: TextStyle(fontSize: 24)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Text(
                          '宏泰食品批發 · 老李',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        SizedBox(width: 6),
                        Text('（NPC 供應商）', style: TextStyle(color: Colors.white54, fontSize: 11)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '好感度: ${state.supplierRelationship}/100',
                          style: const TextStyle(color: Colors.amberAccent, fontSize: 12),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '當前咖啡豆合約價: \$${coffee.currentNegotiatedPrice.toInt()} / 袋',
                          style: TextStyle(
                            color: coffee.currentNegotiatedPrice < coffee.wholesaleCost
                                ? Colors.greenAccent
                                : Colors.white70,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // AI 引擎切換列 (本機 Ollama / 離線規則 / Gemini API)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          color: const Color(0xFF141E33),
          child: Row(
            children: [
              const Text('AI 引擎: ', style: TextStyle(color: Colors.white54, fontSize: 11)),
              const SizedBox(width: 6),
              _buildEngineChip(
                label: '本機 Ollama (Gemma 4)',
                provider: AiProvider.ollama,
                current: state.aiProvider,
                onSelected: () => state.setAiProvider(AiProvider.ollama),
              ),
              const SizedBox(width: 6),
              _buildEngineChip(
                label: '離線規則',
                provider: AiProvider.localRule,
                current: state.aiProvider,
                onSelected: () => state.setAiProvider(AiProvider.localRule),
              ),
              const SizedBox(width: 6),
              _buildEngineChip(
                label: 'Gemini API',
                provider: AiProvider.gemini,
                current: state.aiProvider,
                onSelected: () {
                  state.setAiProvider(AiProvider.gemini);
                  if (state.geminiApiKey.isEmpty) {
                    _showGeminiKeyDialog(context, state);
                  }
                },
              ),
              const Spacer(),
              Text(
                '上次回覆: ${state.currentAiEngine}',
                style: const TextStyle(color: Colors.white38, fontSize: 10),
              ),
            ],
          ),
        ),

        // 對話訊息滾動區域
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: state.negotiationHistory.length,
            itemBuilder: (context, index) {
              final msg = state.negotiationHistory[index];
              return _buildMessageBubble(msg);
            },
          ),
        ),

        // 快捷提議與話術晶片
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          color: const Color(0xFF0F172A),
          child: SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _quickPhrases.length,
              separatorBuilder: (context, idx) => const SizedBox(width: 8),
              itemBuilder: (context, idx) {
                return ActionChip(
                  label: Text(_quickPhrases[idx], style: const TextStyle(fontSize: 12, color: Colors.white70)),
                  backgroundColor: const Color(0xFF1E293B),
                  side: BorderSide.none,
                  onPressed: () {
                    setState(() {
                      _textController.text = _quickPhrases[idx];
                    });
                  },
                );
              },
            ),
          ),
        ),

        // 底部談判輸入控制台
        Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            color: Color(0xFF1E293B),
            border: Border(top: BorderSide(color: Colors.white10)),
          ),
          child: Column(
            children: [
              // 談判參數滑桿：期望目標價與預計採購量
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('目標出價: ', style: TextStyle(color: Colors.white54, fontSize: 11)),
                            Text('\$${_targetPrice.toInt()} / 袋',
                                style: const TextStyle(
                                    color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                        Slider(
                          value: _targetPrice,
                          min: 50,
                          max: 95,
                          divisions: 9,
                          activeColor: Colors.cyanAccent,
                          onChanged: (val) => setState(() => _targetPrice = val),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('採購袋數: ', style: TextStyle(color: Colors.white54, fontSize: 11)),
                            Text('$_orderQty 袋',
                                style: const TextStyle(
                                    color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                        Slider(
                          value: _orderQty.toDouble(),
                          min: 20,
                          max: 120,
                          divisions: 10,
                          activeColor: Colors.amberAccent,
                          onChanged: (val) => setState(() => _orderQty = val.toInt()),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // 對話文字框與發送按鈕
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: '對老李說點好話或殺價（例：老哥長期合作算便宜點）...',
                        hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: state.isNegotiating
                        ? null
                        : () async {
                            final text = _textController.text.trim();
                            if (text.isEmpty) return;
                            _textController.clear();
                            await state.sendNegotiationMessage(
                              userText: text,
                              targetPrice: _targetPrice,
                              quantity: _orderQty,
                            );
                            _scrollToBottom();
                          },
                    child: state.isNegotiating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMessageBubble(NegotiationMessage msg) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: msg.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!msg.isUser) ...[
            const CircleAvatar(
              radius: 16,
              backgroundColor: Colors.amber,
              child: Text('👨‍💼', style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: msg.isUser ? const Color(0xFF2563EB) : const Color(0xFF334155),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment:
                    msg.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Text(
                    msg.text,
                    style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
                  ),
                  // 若老李調用了 Tool 回傳結果，渲染結構化卡片
                  if (msg.outcome != null) ...[
                    const SizedBox(height: 8),
                    _buildOutcomeBadge(msg.outcome!),
                  ],
                ],
              ),
            ),
          ),
          if (msg.isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildOutcomeBadge(NegotiationOutcome outcome) {
    Color bg;
    IconData icon;
    String statusLabel;

    switch (outcome.status) {
      case NegotiationStatus.agreed:
        bg = Colors.green.shade800;
        icon = Icons.check_circle_outline;
        statusLabel = '達成共識！成交單價: \$${outcome.agreedUnitPrice.toInt()}';
        break;
      case NegotiationStatus.counterOffer:
        bg = Colors.amber.shade900;
        icon = Icons.handshake_outlined;
        statusLabel = '老李提議折衷價: \$${outcome.agreedUnitPrice.toInt()}';
        break;
      case NegotiationStatus.rejected:
      default:
        bg = Colors.red.shade900;
        icon = Icons.highlight_off_rounded;
        statusLabel = '談判破局！維持原價 \$100';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 4),
          Text(
            statusLabel,
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildEngineChip({
    required String label,
    required AiProvider provider,
    required AiProvider current,
    required VoidCallback onSelected,
  }) {
    final isSelected = provider == current;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : Colors.white60)),
      selected: isSelected,
      selectedColor: Colors.blueAccent,
      backgroundColor: const Color(0xFF1E293B),
      showCheckmark: false,
      padding: EdgeInsets.zero,
      onSelected: (_) => onSelected(),
    );
  }

  void _showGeminiKeyDialog(BuildContext context, GameState state) {
    final controller = TextEditingController(text: state.geminiApiKey);
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text('設定 Gemini API Key', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '填入 Google AI Studio API Key 即可解鎖雲端極速對話。金鑰僅儲存於本機記憶體。',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'AIzaSy...',
                  hintStyle: TextStyle(color: Colors.white30),
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: () {
                state.geminiApiKey = controller.text.trim();
                Navigator.pop(ctx);
              },
              child: const Text('保存設定'),
            ),
          ],
        );
      },
    );
  }
}
