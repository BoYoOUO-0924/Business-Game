import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/game_state.dart';

class StoryProgressBanner extends StatelessWidget {
  const StoryProgressBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GameState>();
    final chapter = state.currentChapter;
    final currency = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

    return Container(
      margin: const EdgeInsets.only(bottom: 14.0),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E1B4B), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: chapter.isCompleted ? Colors.amberAccent : const Color(0xFF818CF8).withValues(alpha: 0.4),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withValues(alpha: 0.12),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 標題與晉級狀態
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(chapter.icon, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        chapter.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                      Text(
                        chapter.subtitle,
                        style: const TextStyle(color: Color(0xFFA5B4FC), fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
              if (chapter.isCompleted && !chapter.isClaimed)
                ElevatedButton(
                  onPressed: () => state.claimChapterReward(chapter.chapterNumber),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amberAccent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: const Size(80, 32),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.emoji_events_rounded, size: 14, color: Colors.black),
                      SizedBox(width: 4),
                      Text('領獎晉升', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF818CF8).withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    '章節 ${chapter.chapterNumber}/4',
                    style: const TextStyle(color: Color(0xFFA5B4FC), fontSize: 10.5, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            chapter.storyIntro,
            style: const TextStyle(color: Colors.white70, fontSize: 11.5, height: 1.3),
          ),
          const SizedBox(height: 10),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 8),

          // 章節子目標進度清單
          Column(
            children: chapter.goals.map((goal) {
              double currentValue = 0.0;
              String displayTarget = goal.targetValue.toInt().toString();

              switch (goal.metricType) {
                case 'customers_served':
                  currentValue = state.totalCustomersServed.toDouble();
                  displayTarget = '${goal.targetValue.toInt()} 位';
                  break;
                case 'revenue':
                  currentValue = state.company.totalRevenue;
                  displayTarget = currency.format(goal.targetValue);
                  break;
                case 'cash':
                  currentValue = state.company.cash;
                  displayTarget = currency.format(goal.targetValue);
                  break;
                case 'daily_revenue':
                  currentValue = state.company.dailyRevenue;
                  displayTarget = currency.format(goal.targetValue);
                  break;
                case 'reputation':
                  currentValue = state.company.reputation.toDouble();
                  displayTarget = '${goal.targetValue.toInt()} 分';
                  break;
                case 'hired_staff':
                  currentValue = state.hiredStaff.length.toDouble();
                  displayTarget = '${goal.targetValue.toInt()} 名';
                  break;
                case 'units_sold':
                  currentValue = state.company.totalUnitsSold.toDouble();
                  displayTarget = '${goal.targetValue.toInt()} 件';
                  break;
                case 'fixture_purchased':
                  currentValue = goal.isAchieved ? 1.0 : 0.0;
                  displayTarget = '已安裝';
                  break;
              }

              final progress = goal.getProgress(currentValue);

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3.0),
                child: Row(
                  children: [
                    Icon(
                      goal.isAchieved ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                      color: goal.isAchieved ? const Color(0xFF10B981) : Colors.white38,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      flex: 4,
                      child: Text(
                        goal.title,
                        style: TextStyle(
                          color: goal.isAchieved ? Colors.white : Colors.white70,
                          fontSize: 11,
                          fontWeight: goal.isAchieved ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 4,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.white10,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            goal.isAchieved ? const Color(0xFF10B981) : const Color(0xFF818CF8),
                          ),
                          minHeight: 4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      goal.isAchieved ? '達成' : displayTarget,
                      style: TextStyle(
                        color: goal.isAchieved ? const Color(0xFF10B981) : Colors.white60,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
