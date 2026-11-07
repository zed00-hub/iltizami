import 'models.dart';

double _d(dynamic v, [double def = 0]) => v is num ? v.toDouble() : def;
int _i(dynamic v, [int def = 0]) => v is num ? v.toInt() : def;
String _s(dynamic v) => (v ?? '').toString();

// ───────────────────────── المهام والخطط ─────────────────────────

class SubTask {
  String t;
  bool done;
  SubTask(this.t, {this.done = false});

  Map<String, dynamic> toJson() => {'t': t, 'd': done};
  factory SubTask.fromJson(Map<String, dynamic> j) => SubTask(_s(j['t']), done: j['d'] == true);
}

/// مهمة/خطة. level: سنوية/شهرية/أسبوعية/يومية. anchor: أي يوم يقع داخل الفترة.
class Task {
  String id;
  String title;
  PeriodType level;
  int anchor;
  bool done;
  int doneDay;
  String? parentId;

  /// true: تقدّمها يُحسب من المهام الفرعية المرتبطة بها (حرّية اختيارك)
  bool byChildren;

  /// 0 بدون، 1 عاجل ومهم، 2 مهم غير عاجل، 3 عاجل غير مهم، 4 لا عاجل ولا مهم
  int quadrant;
  String category;
  String notes;

  /// 0 بدون، 1 يوميًا، 2 أسبوعيًا، 3 شهريًا
  int repeat;
  List<SubTask> subs;
  int focusMin;
  int createdDay;

  /// وقت تذكير (دقائق اليوم) للمهام اليومية، -1 بدون
  int remind;

  Task({
    required this.id,
    required this.title,
    this.level = PeriodType.day,
    required this.anchor,
    this.done = false,
    this.doneDay = 0,
    this.parentId,
    this.byChildren = false,
    this.quadrant = 0,
    this.category = '',
    this.notes = '',
    this.repeat = 0,
    List<SubTask>? subs,
    this.focusMin = 0,
    required this.createdDay,
    this.remind = -1,
  }) : subs = subs ?? <SubTask>[];

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'level': level.index,
        'anchor': anchor,
        'done': done,
        'doneDay': doneDay,
        'parent': parentId,
        'bc': byChildren,
        'q': quadrant,
        'cat': category,
        'notes': notes,
        'rep': repeat,
        'subs': subs.map((e) => e.toJson()).toList(),
        'focus': focusMin,
        'created': createdDay,
        'remind': remind,
      };

  factory Task.fromJson(Map<String, dynamic> j) {
    final subs = <SubTask>[];
    final raw = j['subs'];
    if (raw is List) {
      for (final e in raw) {
        if (e is Map) subs.add(SubTask.fromJson(Map<String, dynamic>.from(e)));
      }
    }
    final lv = _i(j['level'], 3);
    return Task(
      id: _s(j['id']),
      title: _s(j['title']),
      level: PeriodType.values[lv < 0 || lv > 3 ? 3 : lv],
      anchor: _i(j['anchor']),
      done: j['done'] == true,
      doneDay: _i(j['doneDay']),
      parentId: (j['parent'] is String && (j['parent'] as String).isNotEmpty) ? j['parent'] as String : null,
      byChildren: j['bc'] == true,
      quadrant: clampInt(j['q'], 0, 4, 0),
      category: _s(j['cat']),
      notes: _s(j['notes']),
      repeat: clampInt(j['rep'], 0, 3, 0),
      subs: subs,
      focusMin: _i(j['focus']),
      createdDay: _i(j['created']),
      remind: _i(j['remind'], -1),
    );
  }
}

class Idea {
  String id;
  String text;
  int ms;
  Idea(this.id, this.text, this.ms);

  Map<String, dynamic> toJson() => {'id': id, 't': text, 'ms': ms};
  factory Idea.fromJson(Map<String, dynamic> j) => Idea(_s(j['id']), _s(j['t']), _i(j['ms']));
}

// ───────────────────────── الأدوية ─────────────────────────

class Med {
  String id;
  String name;
  String emoji;
  int colorIdx;

  /// أوقات الجرعات (دقائق اليوم) مرتبة
  List<int> doses;

  /// عدد الحبات/الوحدات في الجرعة الواحدة
  double amount;
  String unit;
  int startDay;

  /// 0 = مفتوح بلا نهاية
  int endDay;

  /// -1 = بدون تتبّع مخزون
  double stock;
  int snoozeMin;
  String notes;
  bool archived;

  /// المفتاح "يوم:رقم_الجرعة" والقيمة 1 تم أخذها، 2 تخطّيتها
  Map<String, int> log;

  Med({
    required this.id,
    required this.name,
    this.emoji = '💊',
    this.colorIdx = 2,
    List<int>? doses,
    this.amount = 1,
    this.unit = 'حبة',
    required this.startDay,
    this.endDay = 0,
    this.stock = -1,
    this.snoozeMin = 10,
    this.notes = '',
    this.archived = false,
    Map<String, int>? log,
  })  : doses = doses ?? <int>[480],
        log = log ?? <String, int>{};

  static String key(int day, int idx) => '$day:$idx';

  int state(int day, int idx) => log[key(day, idx)] ?? 0;

  bool activeOn(int day) => day >= startDay && (endDay == 0 || day <= endDay);

  /// عدد الأيام المتبقية من المخزون، أو -1 إن لم يُتتبَّع
  double daysLeft() {
    if (stock < 0) return -1;
    final perDay = amount * (doses.isEmpty ? 1 : doses.length);
    if (perDay <= 0) return -1;
    return stock / perDay;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'emoji': emoji,
        'color': colorIdx,
        'doses': doses,
        'amount': amount,
        'unit': unit,
        'start': startDay,
        'end': endDay,
        'stock': stock,
        'snooze': snoozeMin,
        'notes': notes,
        'archived': archived,
        'log': log,
      };

  factory Med.fromJson(Map<String, dynamic> j) {
    final doses = <int>[];
    final rd = j['doses'];
    if (rd is List) {
      for (final e in rd) {
        if (e is num) doses.add(e.toInt());
      }
    }
    doses.sort();
    final log = <String, int>{};
    final rl = j['log'];
    if (rl is Map) {
      rl.forEach((k, v) {
        if (v is num) log[k.toString()] = v.toInt();
      });
    }
    return Med(
      id: _s(j['id']),
      name: _s(j['name']),
      emoji: _s(j['emoji']).isEmpty ? '💊' : _s(j['emoji']),
      colorIdx: clampInt(j['color'], 0, 9, 2),
      doses: doses.isEmpty ? <int>[480] : doses,
      amount: _d(j['amount'], 1),
      unit: _s(j['unit']).isEmpty ? 'حبة' : _s(j['unit']),
      startDay: _i(j['start']),
      endDay: _i(j['end']),
      stock: _d(j['stock'], -1),
      snoozeMin: clampInt(j['snooze'], 1, 120, 10),
      notes: _s(j['notes']),
      archived: j['archived'] == true,
      log: log,
    );
  }
}

// ───────────────────────── القياسات ─────────────────────────

class Metric {
  String id;
  String name;
  String unit;
  String emoji;

  /// 0 = بدون هدف
  double goal;
  Map<int, double> entries;

  Metric({
    required this.id,
    required this.name,
    this.unit = '',
    this.emoji = '📏',
    this.goal = 0,
    Map<int, double>? entries,
  }) : entries = entries ?? <int, double>{};

  /// آخر يوم مسجّل أو null
  int? lastDay() {
    int? best;
    for (final d in entries.keys) {
      if (best == null || d > best) best = d;
    }
    return best;
  }

  List<int> sortedDays() {
    final l = entries.keys.toList()..sort();
    return l;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'unit': unit,
        'emoji': emoji,
        'goal': goal,
        'entries': entries.map((k, v) => MapEntry(k.toString(), v)),
      };

  factory Metric.fromJson(Map<String, dynamic> j) {
    final e = <int, double>{};
    final raw = j['entries'];
    if (raw is Map) {
      raw.forEach((k, v) {
        final d = int.tryParse(k.toString());
        if (d != null && v is num) e[d] = v.toDouble();
      });
    }
    return Metric(
      id: _s(j['id']),
      name: _s(j['name']),
      unit: _s(j['unit']),
      emoji: _s(j['emoji']).isEmpty ? '📏' : _s(j['emoji']),
      goal: _d(j['goal']),
      entries: e,
    );
  }
}

// ───────────────────────── المزاج ─────────────────────────

class JEntry {
  int mood; // 1..5
  String note;
  JEntry(this.mood, this.note);

  Map<String, dynamic> toJson() => {'m': mood, 'n': note};
  factory JEntry.fromJson(Map<String, dynamic> j) => JEntry(clampInt(j['m'], 1, 5, 3), _s(j['n']));
}

// ───────────────────────── عادات للترك ─────────────────────────

class QuitHabit {
  String id;
  String name;
  String emoji;
  String why;

  /// بداية المحاولة الحالية (مللي ثانية)
  int sinceMs;

  /// أطول مدة نظيفة مكتملة (مللي ثانية)
  int bestMs;

  /// أوقات الانتكاسات
  List<int> relapses;

  QuitHabit({
    required this.id,
    required this.name,
    this.emoji = '🚭',
    this.why = '',
    required this.sinceMs,
    this.bestMs = 0,
    List<int>? relapses,
  }) : relapses = relapses ?? <int>[];

  int currentMs(int nowMs) => nowMs > sinceMs ? nowMs - sinceMs : 0;

  int longestMs(int nowMs) {
    final c = currentMs(nowMs);
    return c > bestMs ? c : bestMs;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'emoji': emoji,
        'why': why,
        'since': sinceMs,
        'best': bestMs,
        'rel': relapses,
      };

  factory QuitHabit.fromJson(Map<String, dynamic> j) {
    final rel = <int>[];
    final raw = j['rel'];
    if (raw is List) {
      for (final e in raw) {
        if (e is num) rel.add(e.toInt());
      }
    }
    return QuitHabit(
      id: _s(j['id']),
      name: _s(j['name']),
      emoji: _s(j['emoji']).isEmpty ? '🚭' : _s(j['emoji']),
      why: _s(j['why']),
      sinceMs: _i(j['since'], DateTime.now().millisecondsSinceEpoch),
      bestMs: _i(j['best']),
      relapses: rel,
    );
  }
}

// ───────────────────────── ختمة القرآن ─────────────────────────

const int kQuranPages = 604;

class Khatma {
  int startDay;
  int targetDays;

  /// يوم -> عدد الصفحات المقروءة فيه
  Map<int, int> pages;

  Khatma({required this.startDay, this.targetDays = 30, Map<int, int>? pages})
      : pages = pages ?? <int, int>{};

  int get total {
    int s = 0;
    for (final v in pages.values) {
      s += v;
    }
    return s;
  }

  Map<String, dynamic> toJson() => {
        'start': startDay,
        'target': targetDays,
        'pages': pages.map((k, v) => MapEntry(k.toString(), v)),
      };

  factory Khatma.fromJson(Map<String, dynamic> j) {
    final p = <int, int>{};
    final raw = j['pages'];
    if (raw is Map) {
      raw.forEach((k, v) {
        final d = int.tryParse(k.toString());
        if (d != null && v is num) p[d] = v.toInt();
      });
    }
    return Khatma(startDay: _i(j['start']), targetDays: clampInt(j['target'], 1, 730, 30), pages: p);
  }
}
