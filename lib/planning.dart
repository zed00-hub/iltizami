import 'package:flutter/material.dart';
import 'models.dart';
import 'models_ext.dart';
import 'stats.dart';
import 'util.dart';

const List<String> kQuadNames = ['بدون تصنيف', 'افعلها الآن', 'خطّط لها', 'فوّضها', 'احذفها'];
const List<String> kQuadSub = [
  '',
  'عاجلة ومهمة',
  'مهمة وغير عاجلة',
  'عاجلة وغير مهمة',
  'غير عاجلة وغير مهمة',
];
const List<Color> kQuadColors = [kMuted, Color(0xFFFF6B6B), Color(0xFF2FD39B), Color(0xFFE9C46A), Color(0xFF8FA69B)];

int taskKey(Task t, int ws) => PeriodCalc(t.level, ws).keyOf(t.anchor);

List<Task> kidsOf(Task t, List<Task> all) => all.where((x) => x.parentId == t.id).toList();

/// تقدّم المهمة من 0 إلى 1
double taskProgress(Task t, List<Task> all, [int depth = 0]) {
  if (depth > 6) return t.done ? 1.0 : 0.0;
  final kids = kidsOf(t, all);
  if (t.byChildren && kids.isNotEmpty) {
    double s = 0;
    for (final k in kids) {
      s += taskProgress(k, all, depth + 1);
    }
    return s / kids.length;
  }
  if (t.done) return 1.0;
  if (t.subs.isNotEmpty) {
    final d = t.subs.where((x) => x.done).length;
    return d / t.subs.length;
  }
  return 0.0;
}

bool taskIsDone(Task t, List<Task> all) {
  final kids = kidsOf(t, all);
  if (t.byChildren && kids.isNotEmpty) return taskProgress(t, all) >= 0.999999;
  return t.done;
}

bool taskOverdue(Task t, List<Task> all, int ws, int today) {
  if (taskIsDone(t, all)) return false;
  final pc = PeriodCalc(t.level, ws);
  return pc.endOf(pc.keyOf(t.anchor)) < today;
}

/// مفتاح الفترة بعد إزاحة offset فترات عن الفترة الجارية
int shiftedKey(PeriodType level, int ws, int today, int offset) {
  final pc = PeriodCalc(level, ws);
  int k = pc.keyOf(today);
  if (offset > 0) {
    for (int i = 0; i < offset; i++) {
      k = pc.next(k);
    }
  } else {
    for (int i = 0; i < -offset; i++) {
      k = pc.prev(k);
    }
  }
  return k;
}

/// اليوم المناسب لإنشاء مهمة داخل فترة معروضة
int anchorForKey(PeriodType level, int ws, int today, int key) {
  final pc = PeriodCalc(level, ws);
  if (pc.keyOf(today) == key) return today;
  return pc.startOf(key);
}

String periodTitle(PeriodType level, int key, int ws, int today) {
  final pc = PeriodCalc(level, ws);
  switch (level) {
    case PeriodType.day:
      if (key == today) return 'اليوم';
      if (key == today + 1) return 'غدًا';
      if (key == today - 1) return 'أمس';
      return '${kWeekdaysAr[weekdayOf(key) - 1]} ${fmtShort(key)}';
    case PeriodType.week:
      final range = '${fmtShort(key)} ← ${fmtShort(pc.endOf(key))}';
      return key == pc.keyOf(today) ? 'هذا الأسبوع ($range)' : range;
    case PeriodType.month:
      final t = '${kMonthsAr[key % 12]} ${key ~/ 12}';
      return key == pc.keyOf(today) ? 'هذا الشهر ($t)' : t;
    case PeriodType.year:
      return key == pc.keyOf(today) ? 'هذه السنة ($key)' : '$key';
  }
}

String levelWord(PeriodType p) {
  switch (p) {
    case PeriodType.day:
      return 'يومية';
    case PeriodType.week:
      return 'أسبوعية';
    case PeriodType.month:
      return 'شهرية';
    case PeriodType.year:
      return 'سنوية';
  }
}

String repeatWord(int r) {
  switch (r) {
    case 1:
      return 'تتكرر يوميًا';
    case 2:
      return 'تتكرر أسبوعيًا';
    case 3:
      return 'تتكرر شهريًا';
    default:
      return 'بدون تكرار';
  }
}

/// المهام الصالحة كأب للمهمة بمستوى معيّن: مستواها أعلى (سنة > شهر > أسبوع > يوم)
List<Task> parentCandidates(List<Task> all, PeriodType level, String? selfId) {
  // PeriodType: day=0, week=1, month=2, year=3 -> الأب يجب أن يكون index أكبر
  return all.where((t) => t.id != selfId && t.level.index > level.index && !t.done).toList();
}
