enum HabitKind { check, count, timer }

enum PeriodType { day, week, month, year }

Set<int> _intSet(dynamic v) {
  final out = <int>{};
  if (v is List) {
    for (final e in v) {
      if (e is num) out.add(e.toInt());
    }
  }
  return out;
}

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

  /// دافع العادة (لماذا؟)، يظهر في الإشعارات وشاشة التفاصيل
  String why;

  /// أيام سجّلتَ فيها صراحةً أنها فاتت (للعادات من نوع تأكيد)
  Set<int> missed;

  /// تحدّي 30 أو 66 يومًا (0 = بدون)
  int challenge;

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
    this.why = '',
    Set<int>? missed,
    this.challenge = 0,
  })  : log = log ?? <int, double>{},
        missed = missed ?? <int>{};

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
        'why': why,
        'missed': missed.toList(),
        'challenge': challenge,
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
      why: (j['why'] ?? '').toString(),
      missed: _intSet(j['missed']),
      challenge: _idx(j['challenge'], 400, 0),
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

  /// تجزئة رمز القفل (null = بدون قفل)
  String? pinHash;

  /// فترات الإجازة/المرض: [بداية، نهاية] بأرقام الأيام (شاملة)
  List<List<int>> vacations;

  /// تنبيه المراجعة الأسبوعية مساء الجمعة
  bool weekReview;
  int focusWork;
  int focusBreak;

  Settings({
    this.weekStart = 7,
    this.wilaya = 15,
    this.hijriAdjust = 0,
    this.prayerNotif = false,
    this.streakGuard = true,
    this.pinHash,
    List<List<int>>? vacations,
    this.weekReview = true,
    this.focusWork = 25,
    this.focusBreak = 5,
  }) : vacations = vacations ?? <List<int>>[];

  Map<String, dynamic> toJson() => {
        'ws': weekStart,
        'wilaya': wilaya,
        'hadj': hijriAdjust,
        'pn': prayerNotif,
        'sg': streakGuard,
        'pin': pinHash,
        'vac': vacations,
        'wr': weekReview,
        'fw': focusWork,
        'fb': focusBreak,
      };

  factory Settings.fromJson(Map<String, dynamic> j) => Settings(
        weekStart: _idx(j['ws'], 7, 7) == 0 ? 7 : _idx(j['ws'], 7, 7),
        wilaya: _idx(j['wilaya'], 57, 15),
        hijriAdjust: (j['hadj'] is num) ? (j['hadj'] as num).toInt() : 0,
        prayerNotif: j['pn'] == true,
        streakGuard: j['sg'] != false,
        pinHash: (j['pin'] is String && (j['pin'] as String).isNotEmpty) ? j['pin'] as String : null,
        vacations: _vacList(j['vac']),
        weekReview: j['wr'] != false,
        focusWork: clampInt(j['fw'], 1, 180, 25),
        focusBreak: clampInt(j['fb'], 1, 60, 5),
      );
}

int clampInt(dynamic v, int lo, int hi, int def) {
  if (v is num) {
    final i = v.toInt();
    if (i < lo) return lo;
    if (i > hi) return hi;
    return i;
  }
  return def;
}

List<List<int>> _vacList(dynamic v) {
  final out = <List<int>>[];
  if (v is List) {
    for (final e in v) {
      if (e is List && e.length >= 2 && e[0] is num && e[1] is num) {
        out.add([(e[0] as num).toInt(), (e[1] as num).toInt()]);
      }
    }
  }
  return out;
}
