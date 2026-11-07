import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';
import 'models_ext.dart';
import 'notifications.dart';
import 'stats.dart';
import 'util.dart';

class AppStore extends ChangeNotifier {
  List<Habit> habits = [];
  List<Task> tasks = [];
  List<Med> meds = [];
  List<Metric> metrics = [];
  List<QuitHabit> quits = [];
  List<Idea> ideas = [];
  Map<int, JEntry> journal = {};
  Map<int, int> focus = {};
  Map<int, String> reviews = {};

  /// يوم -> 5 أرقام (الفجر..العشاء): 0 لم تُحدَّد، 1 جماعة، 2 منفردة، 3 فاتت
  Map<int, String> prayerLog = {};
  Khatma? khatma;
  int khatmaDone = 0;
  Settings settings = Settings();
  bool loaded = false;
  bool locked = false;
  SharedPreferences? _prefs;

  static const String _key = 'iltizam_v1';

  List<Habit> get active => habits.where((h) => !h.archived).toList();
  List<Habit> get archived => habits.where((h) => h.archived).toList();

  Habit? byId(String id) {
    for (final h in habits) {
      if (h.id == id) return h;
    }
    return null;
  }

  Task? taskById(String id) {
    for (final t in tasks) {
      if (t.id == id) return t;
    }
    return null;
  }

  Med? medById(String id) {
    for (final m in meds) {
      if (m.id == id) return m;
    }
    return null;
  }

  Future<void> load() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final s = _prefs!.getString(_key);
      if (s != null && s.isNotEmpty) {
        _applyJson(jsonDecode(s));
      }
    } catch (_) {}
    locked = settings.pinHash != null;
    loaded = true;
    notifyListeners();
    NotificationService.scheduleSoon(this);
  }

  List<T> _list<T>(dynamic raw, T Function(Map<String, dynamic>) make) {
    final out = <T>[];
    if (raw is List) {
      for (final e in raw) {
        if (e is Map) {
          try {
            out.add(make(Map<String, dynamic>.from(e)));
          } catch (_) {}
        }
      }
    }
    return out;
  }

  Map<int, V> _intMap<V>(dynamic raw, V? Function(dynamic) conv) {
    final out = <int, V>{};
    if (raw is Map) {
      raw.forEach((k, v) {
        final d = int.tryParse(k.toString());
        final c = conv(v);
        if (d != null && c != null) out[d] = c;
      });
    }
    return out;
  }

  void _applyJson(dynamic data) {
    if (data is! Map) return;
    habits = _list(data['habits'], Habit.fromJson);
    tasks = _list(data['tasks'], Task.fromJson);
    meds = _list(data['meds'], Med.fromJson);
    metrics = _list(data['metrics'], Metric.fromJson);
    quits = _list(data['quits'], QuitHabit.fromJson);
    ideas = _list(data['ideas'], Idea.fromJson);
    journal = _intMap<JEntry>(data['journal'], (v) => v is Map ? JEntry.fromJson(Map<String, dynamic>.from(v)) : null);
    focus = _intMap<int>(data['focus'], (v) => v is num ? v.toInt() : null);
    reviews = _intMap<String>(data['reviews'], (v) => v is String ? v : null);
    prayerLog = _intMap<String>(data['prayers'], (v) => (v is String && v.length == 5) ? v : null);
    final kh = data['khatma'];
    khatma = kh is Map ? Khatma.fromJson(Map<String, dynamic>.from(kh)) : null;
    khatmaDone = data['khatmaDone'] is num ? (data['khatmaDone'] as num).toInt() : 0;
    final st = data['settings'];
    settings = st is Map ? Settings.fromJson(Map<String, dynamic>.from(st)) : Settings();
  }

  Map<String, dynamic> toJson() => {
        'v': 2,
        'habits': habits.map((h) => h.toJson()).toList(),
        'tasks': tasks.map((t) => t.toJson()).toList(),
        'meds': meds.map((m) => m.toJson()).toList(),
        'metrics': metrics.map((m) => m.toJson()).toList(),
        'quits': quits.map((q) => q.toJson()).toList(),
        'ideas': ideas.map((i) => i.toJson()).toList(),
        'journal': journal.map((k, v) => MapEntry(k.toString(), v.toJson())),
        'focus': focus.map((k, v) => MapEntry(k.toString(), v)),
        'reviews': reviews.map((k, v) => MapEntry(k.toString(), v)),
        'prayers': prayerLog.map((k, v) => MapEntry(k.toString(), v)),
        'khatma': khatma?.toJson(),
        'khatmaDone': khatmaDone,
        'settings': settings.toJson(),
      };

  void _changed({bool reschedule = true}) {
    try {
      _prefs?.setString(_key, jsonEncode(toJson()));
    } catch (_) {}
    notifyListeners();
    if (reschedule) NotificationService.scheduleSoon(this);
  }

  /// للشاشات التي عدّلت كائنًا مباشرةً وتريد الحفظ
  void save() => _changed();

  int _idCounter = 0;
  String newId() => '${DateTime.now().microsecondsSinceEpoch}${_idCounter++}';

  // ───────── الإجازة ─────────
  bool isFrozen(int day) {
    for (final v in settings.vacations) {
      if (v.length >= 2 && day >= v[0] && day <= v[1]) return true;
    }
    return false;
  }

  HabitStats statsFor(Habit h) =>
      computeStats(h, settings.weekStart, todayNum(), frozen: isFrozen);

  // ───────── العادات ─────────
  void addHabit(Habit h) {
    habits.add(h);
    _changed();
  }

  void saveHabit() => _changed();

  void deleteHabit(Habit h) {
    habits.removeWhere((x) => x.id == h.id);
    _changed();
  }

  void setArchived(Habit h, bool v) {
    h.archived = v;
    h.timerStartMs = null;
    _changed();
  }

  void setValue(Habit h, int day, double v) {
    if (day > todayNum()) return;
    if (v <= 0) {
      h.log.remove(day);
    } else {
      h.log[day] = h.kind == HabitKind.check ? 1.0 : double.parse(v.toStringAsFixed(2));
      h.missed.remove(day);
    }
    _changed();
  }

  /// 0 لم تُحدَّد، 1 تمت، 2 فاتت
  int checkState(Habit h, int day) {
    if ((h.log[day] ?? 0) > 0) return 1;
    if (h.missed.contains(day)) return 2;
    return 0;
  }

  /// دورة الحالات الثلاث: لم تُحدَّد ← تمت ← فاتت ← لم تُحدَّد
  void cycleCheck(Habit h, int day) {
    if (day > todayNum()) return;
    final s = checkState(h, day);
    if (s == 0) {
      h.log[day] = 1.0;
      h.missed.remove(day);
    } else if (s == 1) {
      h.log.remove(day);
      h.missed.add(day);
    } else {
      h.missed.remove(day);
    }
    _changed();
  }

  void setMissed(Habit h, int day, bool v) {
    if (day > todayNum()) return;
    if (v) {
      h.log.remove(day);
      h.missed.add(day);
    } else {
      h.missed.remove(day);
    }
    _changed();
  }

  void toggleCheck(Habit h, int day) {
    final cur = h.log[day] ?? 0;
    setValue(h, day, cur > 0 ? 0 : 1);
  }

  void addAmount(Habit h, int day, double delta) {
    final cur = h.log[day] ?? 0;
    double nv = cur + delta;
    if (nv < 0) nv = 0;
    setValue(h, day, nv);
  }

  void startTimer(Habit h) {
    h.timerStartMs = DateTime.now().millisecondsSinceEpoch;
    _changed(reschedule: false);
  }

  double stopTimer(Habit h) {
    final start = h.timerStartMs;
    h.timerStartMs = null;
    double minutes = 0;
    if (start != null) {
      minutes = (DateTime.now().millisecondsSinceEpoch - start) / 60000.0;
      minutes = (minutes * 10).round() / 10.0;
    }
    if (minutes >= 0.1) {
      addAmount(h, todayNum(), minutes);
    } else {
      _changed(reschedule: false);
    }
    return minutes;
  }

  // ───────── المهام ─────────
  List<Task> childrenOfTask(String id) => tasks.where((t) => t.parentId == id).toList();

  void addTask(Task t) {
    tasks.add(t);
    _changed();
  }

  void deleteTask(Task t) {
    for (final c in tasks) {
      if (c.parentId == t.id) c.parentId = null;
    }
    tasks.removeWhere((x) => x.id == t.id);
    _changed();
  }

  int nextAnchor(Task t) {
    switch (t.repeat) {
      case 1:
        return t.anchor + 1;
      case 2:
        return t.anchor + 7;
      case 3:
        final d = dateOf(t.anchor);
        int y = d.year;
        int m = d.month + 1;
        if (m > 12) {
          m = 1;
          y++;
        }
        final last = DateTime.utc(y, m + 1, 0).day;
        return dayOf(DateTime.utc(y, m, d.day > last ? last : d.day));
      default:
        return t.anchor;
    }
  }

  void toggleTask(Task t) {
    t.done = !t.done;
    t.doneDay = t.done ? todayNum() : 0;
    if (t.done && t.repeat != 0) {
      final na = nextAnchor(t);
      final exists = tasks.any((x) =>
          x.title == t.title && x.level == t.level && x.repeat == t.repeat && x.anchor == na && !x.done);
      if (!exists) {
        tasks.add(Task(
          id: newId(),
          title: t.title,
          level: t.level,
          anchor: na,
          parentId: t.parentId,
          byChildren: false,
          quadrant: t.quadrant,
          category: t.category,
          notes: t.notes,
          repeat: t.repeat,
          subs: t.subs.map((s) => SubTask(s.t)).toList(),
          createdDay: todayNum(),
          remind: t.remind,
        ));
      }
    }
    _changed();
  }

  void toggleSub(Task t, int i) {
    if (i < 0 || i >= t.subs.length) return;
    t.subs[i].done = !t.subs[i].done;
    final all = t.subs.every((s) => s.done);
    if (all && !t.done) {
      t.done = true;
      t.doneDay = todayNum();
    } else if (!all && t.done) {
      t.done = false;
      t.doneDay = 0;
    }
    _changed();
  }

  // ───────── الأدوية ─────────
  void addMed(Med m) {
    meds.add(m);
    _changed();
  }

  void deleteMed(Med m) {
    meds.removeWhere((x) => x.id == m.id);
    _changed();
  }

  /// state: 0 مسح، 1 أُخذت، 2 تخطّيتها. يُحدِّث المخزون تلقائيًا
  void setDose(Med m, int day, int idx, int state) {
    if (day > todayNum()) return;
    final k = Med.key(day, idx);
    final prev = m.log[k] ?? 0;
    if (prev == state) return;
    if (m.stock >= 0) {
      if (prev == 1) m.stock += m.amount;
      if (state == 1) {
        m.stock -= m.amount;
        if (m.stock < 0) m.stock = 0;
      }
    }
    if (state == 0) {
      m.log.remove(k);
    } else {
      m.log[k] = state;
    }
    _changed();
  }

  // ───────── القياسات ─────────
  void addMetric(Metric m) {
    metrics.add(m);
    _changed();
  }

  void deleteMetric(Metric m) {
    metrics.removeWhere((x) => x.id == m.id);
    _changed();
  }

  void setEntry(Metric m, int day, double? v) {
    if (v == null) {
      m.entries.remove(day);
    } else {
      m.entries[day] = double.parse(v.toStringAsFixed(2));
    }
    _changed(reschedule: false);
  }

  // ───────── المزاج ─────────
  void setJournal(int day, int mood, String note) {
    journal[day] = JEntry(mood, note.trim());
    _changed(reschedule: false);
  }

  void clearJournal(int day) {
    journal.remove(day);
    _changed(reschedule: false);
  }

  // ───────── عادات للترك ─────────
  void addQuit(QuitHabit q) {
    quits.add(q);
    _changed(reschedule: false);
  }

  void deleteQuit(QuitHabit q) {
    quits.removeWhere((x) => x.id == q.id);
    _changed(reschedule: false);
  }

  void relapse(QuitHabit q) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final dur = q.currentMs(now);
    if (dur > q.bestMs) q.bestMs = dur;
    q.relapses.add(now);
    q.sinceMs = now;
    _changed(reschedule: false);
  }

  // ───────── الختمة ─────────
  void startKhatma(int targetDays) {
    khatma = Khatma(startDay: todayNum(), targetDays: targetDays);
    _changed(reschedule: false);
  }

  void addPages(int day, int delta) {
    final k = khatma;
    if (k == null || day > todayNum()) return;
    int nv = (k.pages[day] ?? 0) + delta;
    if (nv < 0) nv = 0;
    if (nv == 0) {
      k.pages.remove(day);
    } else {
      k.pages[day] = nv;
    }
    _changed(reschedule: false);
  }

  void finishKhatma() {
    khatma = null;
    khatmaDone++;
    _changed(reschedule: false);
  }

  void cancelKhatma() {
    khatma = null;
    _changed(reschedule: false);
  }

  // ───────── الأفكار والتركيز والمراجعة ─────────
  void addIdea(String text) {
    final t = text.trim();
    if (t.isEmpty) return;
    ideas.insert(0, Idea(newId(), t, DateTime.now().millisecondsSinceEpoch));
    _changed(reschedule: false);
  }

  void deleteIdea(Idea i) {
    ideas.removeWhere((x) => x.id == i.id);
    _changed(reschedule: false);
  }

  void addFocus(int day, int minutes, String? taskId) {
    if (minutes <= 0) return;
    focus[day] = (focus[day] ?? 0) + minutes;
    if (taskId != null) {
      final t = taskById(taskId);
      if (t != null) t.focusMin += minutes;
    }
    _changed(reschedule: false);
  }

  void setReview(int weekKey, String note) {
    final n = note.trim();
    if (n.isEmpty) {
      reviews.remove(weekKey);
    } else {
      reviews[weekKey] = n;
    }
    _changed(reschedule: false);
  }

  // ───────── الصلوات الخمس ─────────
  String prayerState(int day) => prayerLog[day] ?? '00000';

  void cyclePrayer(int day, int idx) {
    if (day > todayNum() || idx < 0 || idx > 4) return;
    final cur = prayerState(day).split('');
    final v = int.tryParse(cur[idx]) ?? 0;
    cur[idx] = '${(v + 1) % 4}';
    final s = cur.join();
    if (s == '00000') {
      prayerLog.remove(day);
    } else {
      prayerLog[day] = s;
    }
    _changed(reschedule: false);
  }

  // ───────── القفل ─────────
  String hashPin(String pin) => sha256.convert(utf8.encode('iltizam:$pin')).toString();

  bool checkPin(String pin) => settings.pinHash != null && settings.pinHash == hashPin(pin);

  void setPin(String? pin) {
    settings.pinHash = (pin == null || pin.isEmpty) ? null : hashPin(pin);
    _changed(reschedule: false);
  }

  void unlock() {
    locked = false;
    notifyListeners();
  }

  void lockNow() {
    if (settings.pinHash != null && !locked) {
      locked = true;
      notifyListeners();
    }
  }

  // ───────── الإعدادات والنسخ الاحتياطي ─────────
  void updateSettings(void Function(Settings s) fn) {
    fn(settings);
    _changed();
  }

  String exportJson() => jsonEncode(toJson());

  /// يعيد null عند النجاح، أو رسالة الخطأ
  String? importJson(String text) {
    try {
      final data = jsonDecode(text.trim());
      if (data is! Map || data['habits'] is! List) {
        return 'النص ليس نسخة احتياطية صالحة من التطبيق';
      }
      _applyJson(data);
      _changed();
      return null;
    } catch (_) {
      return 'تعذّر قراءة النص. تأكد أنك نسخت النسخة كاملة';
    }
  }

  Map<String, HabitStats> allStats() {
    final out = <String, HabitStats>{};
    for (final h in habits) {
      out[h.id] = statsFor(h);
    }
    return out;
  }
}

class StoreScope extends InheritedNotifier<AppStore> {
  const StoreScope({super.key, required AppStore store, required super.child})
      : super(notifier: store);

  static AppStore of(BuildContext context) {
    final w = context.dependOnInheritedWidgetOfExactType<StoreScope>();
    return w!.notifier!;
  }
}
