import 'package:flutter/material.dart';
import 'models.dart';

// ───────── الألوان ─────────
const Color kBg = Color(0xFF070C0A);
const Color kSurface = Color(0xFF0F1713);
const Color kCard = Color(0xFF15201B);
const Color kCard2 = Color(0xFF1C2A24);
const Color kLine = Color(0xFF243630);
const Color kEmerald = Color(0xFF2FD39B);
const Color kGold = Color(0xFFE9C46A);
const Color kText = Color(0xFFEAF3EE);
const Color kMuted = Color(0xFF8FA69B);
const Color kDanger = Color(0xFFFF6B6B);

const List<Color> kHabitColors = [
  Color(0xFF2FD39B),
  Color(0xFFE9C46A),
  Color(0xFF5BC0EB),
  Color(0xFFFF8A65),
  Color(0xFFB388FF),
  Color(0xFFFF6B9D),
  Color(0xFFB8E986),
  Color(0xFF26C6DA),
  Color(0xFFFF6B6B),
  Color(0xFFD7B98E),
];

Color a(Color c, double o) {
  int v = (o * 255).round();
  if (v < 0) v = 0;
  if (v > 255) v = 255;
  return c.withAlpha(v);
}

double clampD(double v, double lo, double hi) => v < lo ? lo : (v > hi ? hi : v);
int clampI(int v, int lo, int hi) => v < lo ? lo : (v > hi ? hi : v);

// ───────── التواريخ ─────────
const List<String> kMonthsAr = [
  'جانفي', 'فيفري', 'مارس', 'أفريل', 'ماي', 'جوان',
  'جويلية', 'أوت', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
];
// الفهرس = weekday - 1 (الإثنين = 0)
const List<String> kWeekdaysAr = [
  'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد',
];
const List<String> kWeekdaysShort = ['إث', 'ثل', 'أر', 'خم', 'جم', 'سب', 'أح'];

int dayOf(DateTime d) =>
    DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/ 86400000;
DateTime dateOf(int day) => DateTime.utc(1970, 1, 1).add(Duration(days: day));
int todayNum() => dayOf(DateTime.now());

/// الإثنين = 1 ... الأحد = 7
int weekdayOf(int day) => ((day + 3) % 7) + 1;

String fmtDay(int day) {
  final d = dateOf(day);
  return '${d.day} ${kMonthsAr[d.month - 1]} ${d.year}';
}

String fmtShort(int day) {
  final d = dateOf(day);
  return '${d.day} ${kMonthsAr[d.month - 1]}';
}

String pad2(int n) => n < 10 ? '0$n' : '$n';

String fmtClock(int minutes) {
  int m = minutes % 1440;
  if (m < 0) m += 1440;
  return '${pad2(m ~/ 60)}:${pad2(m % 60)}';
}

String num1(double v) {
  if (v == v.roundToDouble()) return v.toInt().toString();
  return v.toStringAsFixed(1);
}

String fmtMinutes(double m) {
  if (m < 60) return '${num1(m)} د';
  final h = (m / 60).floor();
  final r = (m - h * 60).round();
  return r == 0 ? '$h س' : '$h س $r د';
}

// ───────── الكلمات ─────────
String periodCount(PeriodType p, int n) {
  switch (p) {
    case PeriodType.day:
      return n == 1 ? 'يوم واحد' : n == 2 ? 'يومان' : (n >= 3 && n <= 10) ? '$n أيام' : '$n يومًا';
    case PeriodType.week:
      return n == 1 ? 'أسبوع واحد' : n == 2 ? 'أسبوعان' : (n >= 3 && n <= 10) ? '$n أسابيع' : '$n أسبوعًا';
    case PeriodType.month:
      return n == 1 ? 'شهر واحد' : n == 2 ? 'شهران' : (n >= 3 && n <= 10) ? '$n أشهر' : '$n شهرًا';
    case PeriodType.year:
      return n == 1 ? 'سنة واحدة' : n == 2 ? 'سنتان' : (n >= 3 && n <= 10) ? '$n سنوات' : '$n سنة';
  }
}

String timesWord(int n) {
  if (n == 1) return 'مرة واحدة';
  if (n == 2) return 'مرتان';
  if (n >= 3 && n <= 10) return '$n مرات';
  return '$n مرة';
}

String periodAdj(PeriodType p) {
  switch (p) {
    case PeriodType.day:
      return 'يومي';
    case PeriodType.week:
      return 'أسبوعي';
    case PeriodType.month:
      return 'شهري';
    case PeriodType.year:
      return 'سنوي';
  }
}

String periodIn(PeriodType p) {
  switch (p) {
    case PeriodType.day:
      return 'في اليوم';
    case PeriodType.week:
      return 'في الأسبوع';
    case PeriodType.month:
      return 'في الشهر';
    case PeriodType.year:
      return 'في السنة';
  }
}

String periodThis(PeriodType p) {
  switch (p) {
    case PeriodType.day:
      return 'اليوم';
    case PeriodType.week:
      return 'هذا الأسبوع';
    case PeriodType.month:
      return 'هذا الشهر';
    case PeriodType.year:
      return 'هذه السنة';
  }
}

String kindName(HabitKind k) {
  switch (k) {
    case HabitKind.check:
      return 'تأكيد';
    case HabitKind.count:
      return 'عدّاد';
    case HabitKind.timer:
      return 'مؤقّت';
  }
}

String goalText(Habit h) {
  final t = h.target;
  switch (h.kind) {
    case HabitKind.check:
      if (h.period == PeriodType.day) return 'كل يوم';
      return '${timesWord(t.round())} ${periodIn(h.period)}';
    case HabitKind.count:
      final u = h.unit.isEmpty ? '' : ' ${h.unit}';
      return '${num1(t)}$u ${periodIn(h.period)}';
    case HabitKind.timer:
      return '${fmtMinutes(t)} ${periodIn(h.period)}';
  }
}

const List<String> kPrayerNames = ['الفجر', 'الظهر', 'العصر', 'المغرب', 'العشاء'];

void toast(BuildContext context, String msg) {
  final m = ScaffoldMessenger.of(context);
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(
    content: Text(msg, textAlign: TextAlign.center, style: const TextStyle(color: kText, fontSize: 15)),
    behavior: SnackBarBehavior.floating,
    backgroundColor: kCard2,
    duration: const Duration(seconds: 2),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  ));
}
