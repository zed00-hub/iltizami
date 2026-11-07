import 'dart:math' as math;
import 'models.dart';
import 'util.dart';

/// حاسبة الفترات (يوم/أسبوع/شهر/سنة). المفتاح:
/// يوم -> رقم اليوم، أسبوع -> رقم يوم بداية الأسبوع،
/// شهر -> سنة*12+شهر-1، سنة -> السنة.
class PeriodCalc {
  final PeriodType type;
  final int weekStart;
  const PeriodCalc(this.type, this.weekStart);

  int keyOf(int day) {
    switch (type) {
      case PeriodType.day:
        return day;
      case PeriodType.week:
        return day - ((weekdayOf(day) - weekStart + 7) % 7);
      case PeriodType.month:
        final d = dateOf(day);
        return d.year * 12 + d.month - 1;
      case PeriodType.year:
        return dateOf(day).year;
    }
  }

  int startOf(int key) {
    switch (type) {
      case PeriodType.day:
      case PeriodType.week:
        return key;
      case PeriodType.month:
        return dayOf(DateTime.utc(key ~/ 12, key % 12 + 1, 1));
      case PeriodType.year:
        return dayOf(DateTime.utc(key, 1, 1));
    }
  }

  int next(int key) => type == PeriodType.week ? key + 7 : key + 1;
  int prev(int key) => type == PeriodType.week ? key - 7 : key - 1;
  int endOf(int key) => startOf(next(key)) - 1;

  String label(int key) {
    switch (type) {
      case PeriodType.day:
        return '${dateOf(key).day}';
      case PeriodType.week:
        return '${dateOf(key).day}/${dateOf(key).month}';
      case PeriodType.month:
        return kMonthsAr[key % 12].substring(0, math.min(3, kMonthsAr[key % 12].length));
      case PeriodType.year:
        return '$key';
    }
  }
}

Map<int, double> periodValues(Habit h, PeriodCalc pc) {
  final pv = <int, double>{};
  final isCheck = h.kind == HabitKind.check;
  h.log.forEach((day, v) {
    if (v <= 0) return;
    final k = pc.keyOf(day);
    pv[k] = (pv[k] ?? 0) + (isCheck ? 1.0 : v);
  });
  return pv;
}

/// قيمة الفترة التي يقع فيها اليوم المحدد
double periodValueAtDay(Habit h, int weekStart, int day) {
  final pc = PeriodCalc(h.period, weekStart);
  final k = pc.keyOf(day);
  double s = 0;
  h.log.forEach((d, v) {
    if (v > 0 && pc.keyOf(d) == k) s += h.kind == HabitKind.check ? 1.0 : v;
  });
  return s;
}

bool periodMetAtDay(Habit h, int weekStart, int day) {
  final t = h.target <= 0 ? 1.0 : h.target;
  return periodValueAtDay(h, weekStart, day) >= t - 0.000001;
}

/// قيم آخر n فترات، الأقدم أولًا والأحدث أخيرًا
List<double> recentPeriodValues(Habit h, int weekStart, int today, int n) {
  final pc = PeriodCalc(h.period, weekStart);
  final pv = periodValues(h, pc);
  final out = <double>[];
  int k = pc.keyOf(today);
  for (int i = 0; i < n; i++) {
    out.add(pv[k] ?? 0);
    k = pc.prev(k);
  }
  return out.reversed.toList();
}

List<String> recentPeriodLabels(Habit h, int weekStart, int today, int n) {
  final pc = PeriodCalc(h.period, weekStart);
  final out = <String>[];
  int k = pc.keyOf(today);
  for (int i = 0; i < n; i++) {
    out.add(pc.label(k));
    k = pc.prev(k);
  }
  return out.reversed.toList();
}

class HabitStats {
  final int curKey;
  final double periodValue;
  final bool periodMet;
  final bool todayDone;
  final int currentStreak;
  final int bestStreak;
  final int bestStartDay;
  final int bestEndDay;
  final int completedPeriods;
  final double total;
  final int activeDays;
  final double bestDayValue;
  final int bestDayNum;
  final double bestPeriodValue;
  final int bestPeriodKey;
  final double strength;
  final double rateAll;
  final double rateRecent;
  final int bestWeekday;
  final int missedDays;

  const HabitStats({
    required this.curKey,
    required this.periodValue,
    required this.periodMet,
    required this.todayDone,
    required this.currentStreak,
    required this.bestStreak,
    required this.bestStartDay,
    required this.bestEndDay,
    required this.completedPeriods,
    required this.total,
    required this.activeDays,
    required this.bestDayValue,
    required this.bestDayNum,
    required this.bestPeriodValue,
    required this.bestPeriodKey,
    required this.strength,
    required this.rateAll,
    required this.rateRecent,
    required this.bestWeekday,
    required this.missedDays,
  });
}

HabitStats computeStats(Habit h, int weekStart, int today, {bool Function(int day)? frozen}) {
  final pc = PeriodCalc(h.period, weekStart);
  final useFz = frozen != null && h.period == PeriodType.day;
  bool fz(int day) => useFz && frozen!(day);
  final target = h.target <= 0 ? 1.0 : h.target;
  final pv = periodValues(h, pc);

  double total = 0;
  int activeDays = 0;
  double bestDayValue = 0;
  int bestDayNum = 0;
  int firstLog = today;
  final wd = List<int>.filled(8, 0);
  h.log.forEach((day, v) {
    if (v <= 0) return;
    total += v;
    activeDays++;
    if (v > bestDayValue) {
      bestDayValue = v;
      bestDayNum = day;
    }
    if (day < firstLog) firstLog = day;
    wd[weekdayOf(day)]++;
  });

  bool met(int k) => (pv[k] ?? 0) >= target - 0.000001;

  final curKey = pc.keyOf(today);
  final curMet = met(curKey);

  // السلسلة الحالية (صارمة): الفترة الجارية لا تكسر السلسلة قبل انتهائها
  int streak = curMet ? 1 : 0;
  int k = pc.prev(curKey);
  while (true) {
    if (!met(k) && fz(k)) {
      k = pc.prev(k);
      continue;
    }
    if (!met(k)) break;
    streak++;
    k = pc.prev(k);
  }

  // أفضل سلسلة
  int best = 0;
  int bestStartKey = curKey;
  int bestEndKey = curKey;
  int completed = 0;
  if (pv.isNotEmpty) {
    final keys = pv.keys.toList()..sort();
    final lastKey = keys.last > curKey ? keys.last : curKey;
    int run = 0;
    int runStart = keys.first;
    int kk = keys.first;
    while (kk <= lastKey) {
      if (met(kk)) {
        if (run == 0) runStart = kk;
        run++;
        completed++;
        if (run > best) {
          best = run;
          bestStartKey = runStart;
          bestEndKey = kk;
        }
      } else if (!fz(kk)) {
        run = 0;
      }
      kk = pc.next(kk);
    }
  }
  int bestStartDay = pc.startOf(bestStartKey);
  int bestEndDay = pc.endOf(bestEndKey);
  if (bestEndDay > today) bestEndDay = today;

  // أفضل فترة
  double bestPeriodValue = 0;
  int bestPeriodKey = curKey;
  pv.forEach((key, v) {
    if (v > bestPeriodValue) {
      bestPeriodValue = v;
      bestPeriodKey = key;
    }
  });

  // نسب الالتزام
  final startDay = math.min(h.createdDay, firstLog);
  final startKey = pc.keyOf(startDay);
  double rateOver(int fromKey) {
    int denom = 0;
    int good = 0;
    int kk = fromKey < startKey ? startKey : fromKey;
    while (kk <= curKey) {
      final m = met(kk);
      if (!(kk == curKey && !m) && !(!m && fz(kk))) {
        denom++;
        if (m) good++;
      }
      kk = pc.next(kk);
    }
    return denom == 0 ? 0.0 : good / denom;
  }

  final n = h.period == PeriodType.day
      ? 30
      : h.period == PeriodType.week
          ? 12
          : h.period == PeriodType.month
              ? 6
              : 3;
  int recentFrom = curKey;
  for (int i = 0; i < n - 1; i++) {
    recentFrom = pc.prev(recentFrom);
  }
  final rateAll = rateOver(startKey);
  final rateRecent = rateOver(recentFrom);

  // قوة العادة: متوسط متحرك أسّي (الذاكرة الأسية) لا يُصفّر بسبب تعثّر عارض
  double freq;
  if (h.period == PeriodType.day) {
    freq = 1.0;
  } else if (h.kind == HabitKind.check) {
    final len = h.period == PeriodType.week ? 7.0 : (h.period == PeriodType.month ? 30.0 : 365.0);
    freq = clampD(target / len, 0.02, 1.0);
  } else {
    freq = h.period == PeriodType.week ? 0.5 : (h.period == PeriodType.month ? 0.35 : 0.1);
  }
  final mult = math.pow(0.5, math.sqrt(freq) / 13.0).toDouble();
  final todayDone = (h.log[today] ?? 0) > 0;
  final lastDay = todayDone ? today : today - 1;
  double s = 0;
  for (int d = startDay; d <= lastDay; d++) {
    final v = h.log[d] ?? 0;
    if (v <= 0 && fz(d)) continue;
    double x;
    if (v <= 0) {
      x = 0;
    } else if (h.kind == HabitKind.check || h.period != PeriodType.day) {
      x = 1;
    } else {
      x = clampD(v / target, 0.0, 1.0);
    }
    s = s * mult + x * (1 - mult);
  }

  int missedDays = 0;
  for (final d in h.missed) {
    if (d <= today) missedDays++;
  }

  int bestWeekday = 0;
  int bestWdCount = 0;
  for (int i = 1; i <= 7; i++) {
    if (wd[i] > bestWdCount) {
      bestWdCount = wd[i];
      bestWeekday = i;
    }
  }

  return HabitStats(
    curKey: curKey,
    periodValue: pv[curKey] ?? 0,
    periodMet: curMet,
    todayDone: todayDone,
    currentStreak: streak,
    bestStreak: best,
    bestStartDay: bestStartDay,
    bestEndDay: bestEndDay,
    completedPeriods: completed,
    total: total,
    activeDays: activeDays,
    bestDayValue: bestDayValue,
    bestDayNum: bestDayNum,
    bestPeriodValue: bestPeriodValue,
    bestPeriodKey: bestPeriodKey,
    strength: clampD(s, 0.0, 1.0),
    rateAll: rateAll,
    rateRecent: rateRecent,
    bestWeekday: bestWeekday,
    missedDays: missedDays,
  );
}

String strengthLabel(double s) {
  if (s >= 0.9) return 'حديدية';
  if (s >= 0.7) return 'قوية';
  if (s >= 0.45) return 'متوسطة';
  if (s >= 0.2) return 'تتشكّل';
  return 'ضعيفة';
}

// ───────── النقاط والمستويات ─────────
const List<String> kLevelTitles = [
  'مبتدئ', 'متحمّس', 'ثابت', 'صلب', 'حديدي', 'مُدرَّع', 'دبابة',
  'دبابة ثقيلة', 'أسطورة', 'لا يُقهَر',
];

int _need(int level) => (100 * (level - 1) * level) ~/ 2;

class LevelInfo {
  final int xp;
  final int level;
  final int into;
  final int span;
  final String title;
  const LevelInfo(this.xp, this.level, this.into, this.span, this.title);
  double get progress => span == 0 ? 0 : into / span;
}

int xpOf(Habit h, HabitStats st) {
  return st.activeDays * 10 + st.completedPeriods * 25 + (st.bestStreak ~/ 7) * 30;
}

LevelInfo levelFor(int xp) {
  int lvl = 1;
  while (xp >= _need(lvl + 1)) {
    lvl++;
  }
  final title = lvl <= kLevelTitles.length ? kLevelTitles[lvl - 1] : 'أسطورة التزام';
  return LevelInfo(xp, lvl, xp - _need(lvl), _need(lvl + 1) - _need(lvl), title);
}

class BadgeInfo {
  final String emoji;
  final String title;
  final String desc;
  final bool earned;
  const BadgeInfo(this.emoji, this.title, this.desc, this.earned);
}

List<BadgeInfo> computeBadges(List<Habit> habits, Map<String, HabitStats> stats) {
  int bestDay = 0;
  int bestWeek = 0;
  int bestMonth = 0;
  int entries = 0;
  for (final h in habits) {
    final st = stats[h.id];
    if (st == null) continue;
    entries += st.activeDays;
    if (h.period == PeriodType.day && st.bestStreak > bestDay) bestDay = st.bestStreak;
    if (h.period == PeriodType.week && st.bestStreak > bestWeek) bestWeek = st.bestStreak;
    if (h.period == PeriodType.month && st.bestStreak > bestMonth) bestMonth = st.bestStreak;
  }
  return [
    BadgeInfo('🌱', 'البداية', 'أول تسجيل لك', entries >= 1),
    BadgeInfo('🔥', '3 أيام', 'سلسلة 3 أيام متتالية', bestDay >= 3),
    BadgeInfo('⚡', 'أسبوع كامل', 'سلسلة 7 أيام', bestDay >= 7),
    BadgeInfo('💪', '14 يومًا', 'سلسلة أسبوعين', bestDay >= 14),
    BadgeInfo('🛡️', 'شهر حديدي', 'سلسلة 30 يومًا', bestDay >= 30),
    BadgeInfo('🏔️', '60 يومًا', 'سلسلة شهرين', bestDay >= 60),
    BadgeInfo('👑', '100 يوم', 'سلسلة 100 يوم', bestDay >= 100),
    BadgeInfo('🚀', 'سنة كاملة', 'سلسلة 365 يومًا', bestDay >= 365),
    BadgeInfo('📅', '4 أسابيع', 'هدف أسبوعي 4 أسابيع متتالية', bestWeek >= 4),
    BadgeInfo('🗓️', '12 أسبوعًا', 'هدف أسبوعي 12 أسبوعًا متتاليًا', bestWeek >= 12),
    BadgeInfo('🏆', '6 أشهر', 'هدف شهري 6 أشهر متتالية', bestMonth >= 6),
    BadgeInfo('✨', '100 تسجيل', 'مئة تسجيل إجمالًا', entries >= 100),
    BadgeInfo('💎', '500 تسجيل', 'خمسمئة تسجيل إجمالًا', entries >= 500),
    BadgeInfo('🌟', '1000 تسجيل', 'ألف تسجيل إجمالًا', entries >= 1000),
  ];
}

const List<int> kMilestones = [3, 7, 14, 21, 30, 50, 60, 100, 200, 365];
