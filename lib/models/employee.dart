enum ShiftType {
  none,   // 未排班 / 休假
  morning,// 早班 (08:00 ~ 16:00)
  evening,// 晚班 (16:00 ~ 24:00)
  night,  // 大夜 (00:00 ~ 08:00)
}

class Employee {
  final String id;
  final String name;
  final String avatar;
  final String role; // '兼職工讀生', '正職收銀員', '儲備店長'
  final double hourlyWage;
  final double efficiency; // 結帳效率基準 (0.8 ~ 1.4)
  final String trait; // 特質描述
  int fatigue; // 疲勞度 (0 ~ 100)
  int morale;  // 士氣 (0 ~ 100)
  ShiftType assignedShift;

  Employee({
    required this.id,
    required this.name,
    required this.avatar,
    required this.role,
    required this.hourlyWage,
    this.efficiency = 1.0,
    required this.trait,
    this.fatigue = 10,
    this.morale = 85,
    this.assignedShift = ShiftType.none,
  });

  /// 判斷該員工在此時段 (0~23) 是否正在上班
  bool isOnDuty(int hour) {
    switch (assignedShift) {
      case ShiftType.morning:
        return hour >= 8 && hour < 16;
      case ShiftType.evening:
        return hour >= 16 && hour < 24;
      case ShiftType.night:
        return hour >= 0 && hour < 8;
      case ShiftType.none:
        return false;
    }
  }

  /// 實際工作效率：疲勞會拖垮產能，士氣則小幅加減。
  /// 這是疲勞與士氣真正生效的地方 —— 撐著不排休，結帳速度就會掉。
  double get effectiveEfficiency {
    final fatiguePenalty = fatigue > 55 ? (fatigue - 55) / 100.0 : 0.0; // 最多 -0.45
    final moraleModifier = (morale - 70) / 100.0 * 0.4; // -0.28 ~ +0.12
    return (efficiency * (1.0 - fatiguePenalty) + moraleModifier).clamp(0.25, 2.0);
  }

  /// 是否已瀕臨離職（士氣過低）
  bool get isAboutToQuit => morale <= 30;

  String get conditionLabel {
    if (morale <= 30) return '瀕臨離職';
    if (fatigue >= 80) return '過勞';
    if (fatigue >= 55) return '疲憊';
    if (morale >= 85) return '幹勁十足';
    return '狀態正常';
  }

  String get shiftName {
    switch (assignedShift) {
      case ShiftType.morning:
        return '早班 (08-16)';
      case ShiftType.evening:
        return '晚班 (16-24)';
      case ShiftType.night:
        return '大夜 (00-08)';
      case ShiftType.none:
        return '未排班 (休假)';
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'avatar': avatar,
        'role': role,
        'wage': hourlyWage,
        'eff': efficiency,
        'trait': trait,
        'fatigue': fatigue,
        'morale': morale,
        'shift': assignedShift.index,
      };

  factory Employee.fromJson(Map<String, dynamic> j) => Employee(
        id: j['id'] as String,
        name: j['name'] as String,
        avatar: j['avatar'] as String,
        role: j['role'] as String,
        hourlyWage: (j['wage'] as num).toDouble(),
        efficiency: (j['eff'] as num).toDouble(),
        trait: j['trait'] as String,
        fatigue: (j['fatigue'] as num).toInt(),
        morale: (j['morale'] as num).toInt(),
        assignedShift: ShiftType.values[(j['shift'] as num).toInt()],
      );
}
