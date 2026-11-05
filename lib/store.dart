import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';
import 'notifications.dart';
import 'stats.dart';
import 'util.dart';

class AppStore extends ChangeNotifier {
  List<Habit> habits = [];
  Settings settings = Settings();
  bool loaded = false;
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

  Future<void> load() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final s = _prefs!.getString(_key);
      if (s != null && s.isNotEmpty) {
        _applyJson(jsonDecode(s));
      }
    } catch (_) {}
    loaded = true;
    notifyListeners();
    NotificationService.scheduleSoon(this);
  }

  void _applyJson(dynamic data) {
    if (data is! Map) return;
    final hs = <Habit>[];
    final raw = data['habits'];
    if (raw is List) {
      for (final e in raw) {
        if (e is Map) {
          hs.add(Habit.fromJson(Map<String, dynamic>.from(e)));
        }
      }
    }
    habits = hs;
    final st = data['settings'];
    settings = st is Map ? Settings.fromJson(Map<String, dynamic>.from(st)) : Settings();
  }

  Map<String, dynamic> toJson() => {
        'v': 1,
        'habits': habits.map((h) => h.toJson()).toList(),
        'settings': settings.toJson(),
      };

  void _changed({bool reschedule = true}) {
    try {
      _prefs?.setString(_key, jsonEncode(toJson()));
    } catch (_) {}
    notifyListeners();
    if (reschedule) NotificationService.scheduleSoon(this);
  }

  String newId() => '${DateTime.now().microsecondsSinceEpoch}${habits.length}';

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

  // ───────── التسجيل ─────────
  void setValue(Habit h, int day, double v) {
    if (day > todayNum()) return;
    if (v <= 0) {
      h.log.remove(day);
    } else {
      h.log[day] = h.kind == HabitKind.check ? 1.0 : double.parse(v.toStringAsFixed(2));
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

  // ───────── المؤقّت ─────────
  void startTimer(Habit h) {
    h.timerStartMs = DateTime.now().millisecondsSinceEpoch;
    _changed(reschedule: false);
  }

  /// يوقف المؤقّت ويضيف الدقائق إلى اليوم الحالي. يعيد الدقائق المضافة.
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

  // ───────── الإعدادات ─────────
  void updateSettings(void Function(Settings s) fn) {
    fn(settings);
    _changed();
  }

  // ───────── النسخ الاحتياطي ─────────
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

  // ───────── ملخصات ─────────
  Map<String, HabitStats> allStats() {
    final out = <String, HabitStats>{};
    final t = todayNum();
    for (final h in habits) {
      out[h.id] = computeStats(h, settings.weekStart, t);
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
