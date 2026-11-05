enum HabitKind { check, count, timer }

enum PeriodType { day, week, month, year }

int _idx(dynamic v, int max, int def) {
  if (v is num) {
    final i = v.toInt();
    if (i >= 0 && i <= max) return i;
  }
  return def;
}

/// عادة أو مهمة. السجل: يوم (عدد الأيام منذ 1970) -> قيمة.
/// check: القيمة 1 = تم. count: الكمية. timer: الدقائق.
class Habit {
  String id;
  String name;
  String emoji;
  int colorIdx;
  HabitKind kind;
  PeriodType period;
  double target;
  String unit;

  /// 0 بدون، 1 وقت ثابت، 2 مرتبط بصلاة
  int reminderKind;

  /// وقت اليوم بالدقائق (للنوع 1) أو الإزاحة عن الصلاة بالدقائق (للنوع 2)
  int reminderMinutes;

  /// 0 فجر، 1 ظهر، 2 عصر، 3 مغرب، 4 عشاء
  int reminderPrayer;
  int createdDay;
  bool archived;
  Map<int, double> log;
  int? timerStartMs;

  Habit({
    required this.id,
    required this.name,
    this.emoji = '✅',
    this.colorIdx = 0,
    this.kind = HabitKind.check,
    this.period = PeriodType.day,
    this.target = 1,
    this.unit = '',
    this.reminderKind = 0,
    this.reminderMinutes = 480,
    this.reminderPrayer = 0,
    required this.createdDay,
    this.archived = false,
    Map<int, double>? log,
    this.timerStartMs,
  }) : log = log ?? <int, double>{};

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'emoji': emoji,
        'color': colorIdx,
        'kind': kind.index,
        'period': period.index,
        'target': target,
        'unit': unit,
        'rk': reminderKind,
        'rm': reminderMinutes,
        'rp': reminderPrayer,
        'created': createdDay,
        'archived': archived,
        'log': log.map((k, v) => MapEntry(k.toString(), v)),
        'timer': timerStartMs,
      };

  factory Habit.fromJson(Map<String, dynamic> j) {
    final raw = j['log'];
    final log = <int, double>{};
    if (raw is Map) {
      raw.forEach((k, v) {
        final d = int.tryParse(k.toString());
        if (d != null && v is num) log[d] = v.toDouble();
      });
    }
    return Habit(
      id: (j['id'] ?? DateTime.now().microsecondsSinceEpoch.toString()).toString(),
      name: (j['name'] ?? '').toString(),
      emoji: (j['emoji'] ?? '✅').toString(),
      colorIdx: _idx(j['color'], 9, 0),
      kind: HabitKind.values[_idx(j['kind'], HabitKind.values.length - 1, 0)],
      period: PeriodType.values[_idx(j['period'], PeriodType.values.length - 1, 0)],
      target: (j['target'] is num) ? (j['target'] as num).toDouble() : 1.0,
      unit: (j['unit'] ?? '').toString(),
      reminderKind: _idx(j['rk'], 2, 0),
      reminderMinutes: (j['rm'] is num) ? (j['rm'] as num).toInt() : 480,
      reminderPrayer: _idx(j['rp'], 4, 0),
      createdDay: (j['created'] is num) ? (j['created'] as num).toInt() : 0,
      archived: j['archived'] == true,
      log: log,
      timerStartMs: (j['timer'] is num) ? (j['timer'] as num).toInt() : null,
    );
  }
}

class Settings {
  /// أول يوم في الأسبوع بترقيم DateTime: الإثنين 1 ... الأحد 7. السبت = 6
  int weekStart;

  /// فهرس الولاية في قائمة kWilayas
  int wilaya;
  int hijriAdjust;
  bool prayerNotif;
  bool streakGuard;

  Settings({
    this.weekStart = 7,
    this.wilaya = 15,
    this.hijriAdjust = 0,
    this.prayerNotif = false,
    this.streakGuard = true,
  });

  Map<String, dynamic> toJson() => {
        'ws': weekStart,
        'wilaya': wilaya,
        'hadj': hijriAdjust,
        'pn': prayerNotif,
        'sg': streakGuard,
      };

  factory Settings.fromJson(Map<String, dynamic> j) => Settings(
        weekStart: _idx(j['ws'], 7, 7) == 0 ? 7 : _idx(j['ws'], 7, 7),
        wilaya: _idx(j['wilaya'], 57, 15),
        hijriAdjust: (j['hadj'] is num) ? (j['hadj'] as num).toInt() : 0,
        prayerNotif: j['pn'] == true,
        streakGuard: j['sg'] != false,
      );
}
