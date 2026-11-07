import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models.dart';
import 'models_ext.dart';
import 'planning.dart';
import 'stats.dart';
import 'store.dart';
import 'ui_common.dart';
import 'util.dart';

// ═════════════════════════ حساب المراجعة ═════════════════════════

class WeekReview {
  final int start;
  final int end;
  final double habitRate;
  final List<MapEntry<Habit, double>> perHabit;
  final int tasksDone;
  final int dueTotal;
  final int dueDone;
  final int focusMin;
  final double moodAvg;
  final int moodN;
  final int prayJama;
  final int prayLogged;
  final double medAdh;
  final bool hasMeds;

  const WeekReview({
    required this.start,
    required this.end,
    required this.habitRate,
    required this.perHabit,
    required this.tasksDone,
    required this.dueTotal,
    required this.dueDone,
    required this.focusMin,
    required this.moodAvg,
    required this.moodN,
    required this.prayJama,
    required this.prayLogged,
    required this.medAdh,
    required this.hasMeds,
  });
}

WeekReview computeWeekReview(AppStore store, int start, int end, int today) {
  final ws = store.settings.weekStart;
  final last = end < today ? end : today;
  final per = <MapEntry<Habit, double>>[];
  for (final h in store.active) {
    if (h.createdDay > last) continue;
    if (h.period == PeriodType.day) {
      int considered = 0;
      int done = 0;
      for (int d = start; d <= last; d++) {
        if (d < h.createdDay || store.isFrozen(d)) continue;
        considered++;
        if (periodMetAtDay(h, ws, d)) done++;
      }
      if (considered > 0) per.add(MapEntry(h, done / considered));
    } else {
      final t = h.target <= 0 ? 1.0 : h.target;
      per.add(MapEntry(h, clampD(periodValueAtDay(h, ws, last) / t, 0.0, 1.0)));
    }
  }
  double rate = 0;
  if (per.isNotEmpty) {
    double s = 0;
    for (final e in per) {
      s += e.value;
    }
    rate = s / per.length;
  }

  int tasksDone = 0;
  int dueTotal = 0;
  int dueDone = 0;
  for (final t in store.tasks) {
    if (t.done && t.doneDay >= start && t.doneDay <= end) tasksDone++;
    if (t.level == PeriodType.day && t.anchor >= start && t.anchor <= end) {
      dueTotal++;
      if (taskIsDone(t, store.tasks)) dueDone++;
    }
  }

  int focus = 0;
  for (int d = start; d <= end; d++) {
    focus += store.focus[d] ?? 0;
  }

  double moodSum = 0;
  int moodN = 0;
  for (int d = start; d <= end; d++) {
    final e = store.journal[d];
    if (e != null) {
      moodSum += e.mood;
      moodN++;
    }
  }

  int jama = 0;
  int logged = 0;
  for (int d = start; d <= end; d++) {
    final s = store.prayerLog[d];
    if (s == null) continue;
    for (int i = 0; i < 5; i++) {
      if (s[i] != '0') logged++;
      if (s[i] == '1') jama++;
    }
  }

  final nowMin = DateTime.now().hour * 60 + DateTime.now().minute;
  int sched = 0;
  int taken = 0;
  bool hasMeds = false;
  for (final m in store.meds) {
    if (m.archived) continue;
    for (int d = start; d <= last; d++) {
      if (!m.activeOn(d)) continue;
      hasMeds = true;
      for (int i = 0; i < m.doses.length; i++) {
        if (d == today && m.doses[i] > nowMin) continue;
        sched++;
        if (m.state(d, i) == 1) taken++;
      }
    }
  }

  return WeekReview(
    start: start,
    end: end,
    habitRate: rate,
    perHabit: per,
    tasksDone: tasksDone,
    dueTotal: dueTotal,
    dueDone: dueDone,
    focusMin: focus,
    moodAvg: moodN == 0 ? 0 : moodSum / moodN,
    moodN: moodN,
    prayJama: jama,
    prayLogged: logged,
    medAdh: sched == 0 ? 0 : taken / sched,
    hasMeds: hasMeds && sched > 0,
  );
}

// ═════════════════════════ شاشة المراجعة الأسبوعية ═════════════════════════

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  int which = 0; // 0 الأسبوع الجاري، 1 الأسبوع الماضي
  final _note = TextEditingController();
  int _loadedKey = -1;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final ws = store.settings.weekStart;
    final today = todayNum();
    final pc = PeriodCalc(PeriodType.week, ws);
    final curKey = pc.keyOf(today);
    final key = which == 0 ? curKey : curKey - 7;
    final rv = computeWeekReview(store, key, key + 6, today);
    final prev = computeWeekReview(store, key - 7, key - 1, today);

    if (_loadedKey != key) {
      _loadedKey = key;
      _note.text = store.reviews[key] ?? '';
    }

    final sorted = [...rv.perHabit]..sort((x, y) => y.value.compareTo(x.value));
    final best = sorted.isEmpty ? null : sorted.first;
    final worst = sorted.length < 2 ? null : sorted.last;
    final delta = rv.habitRate - prev.habitRate;

    String verdict;
    if (rv.perHabit.isEmpty) {
      verdict = 'لا بيانات كافية لهذا الأسبوع بعد.';
    } else if (rv.habitRate >= 0.85) {
      verdict = 'أسبوع دبّابة! 🛡️ التزامك ممتاز.';
    } else if (rv.habitRate >= 0.6) {
      verdict = 'أسبوع جيد، وفيه مجال لرفع المستوى.';
    } else {
      verdict = 'أسبوع صعب. لا بأس، المهم أن تبدأ الأسبوع القادم بقوة.';
    }

    return Scaffold(
      appBar: AppBar(title: const Text('🗓️ مراجعة الأسبوع')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 60),
        children: [
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<int>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 0, label: Text('هذا الأسبوع')),
                ButtonSegment(value: 1, label: Text('الأسبوع الماضي')),
              ],
              selected: {which},
              onSelectionChanged: (s) => setState(() => which = s.first),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text('${fmtShort(rv.start)} ← ${fmtShort(rv.end)}',
                style: const TextStyle(color: kMuted, fontSize: 12.5)),
          ),
          const SizedBox(height: 10),
          AppCard(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [a(kEmerald, 0.2), kCard],
            ),
            borderColor: a(kEmerald, 0.4),
            child: Row(
              children: [
                Ring(
                  progress: rv.habitRate,
                  color: kEmerald,
                  size: 96,
                  stroke: 10,
                  child: Text('${(rv.habitRate * 100).round()}%',
                      style: const TextStyle(color: kText, fontSize: 22, fontWeight: FontWeight.w900)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(verdict, style: const TextStyle(color: kText, fontSize: 15, fontWeight: FontWeight.w800, height: 1.5)),
                      if (prev.perHabit.isNotEmpty && rv.perHabit.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            delta.abs() < 0.01
                                ? 'مثل الأسبوع الذي قبله'
                                : (delta > 0
                                    ? '▲ أفضل من الأسبوع السابق بـ${(delta * 100).round()}%'
                                    : '▼ أقل من الأسبوع السابق بـ${(-delta * 100).round()}%'),
                            style: TextStyle(color: delta >= 0 ? kEmerald : kDanger, fontSize: 12.5),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SectionTitle('ملخّص'),
          TwoColumn(children: [
            if (best != null)
              StatTile(emoji: '🏆', label: 'أفضل عادة', value: '${best.key.emoji} ${best.key.name}',
                  sub: '${(best.value * 100).round()}%', color: kGold),
            if (worst != null)
              StatTile(emoji: '🎯', label: 'تحتاج اهتمامًا', value: '${worst.key.emoji} ${worst.key.name}',
                  sub: '${(worst.value * 100).round()}%', color: kDanger),
            StatTile(
              emoji: '✅',
              label: 'مهام منجزة',
              value: '${rv.tasksDone}',
              sub: rv.dueTotal == 0 ? null : 'مجدولة: ${rv.dueDone}/${rv.dueTotal}',
            ),
            StatTile(emoji: '🍅', label: 'وقت التركيز', value: fmtMinutes(rv.focusMin.toDouble())),
            if (rv.moodN > 0)
              StatTile(
                emoji: '📝',
                label: 'متوسط المزاج',
                value: '${rv.moodAvg.toStringAsFixed(1)} / 5',
                sub: '${rv.moodN} أيام مسجّلة',
              ),
            if (rv.prayLogged > 0)
              StatTile(
                emoji: '🕌',
                label: 'الصلوات في جماعة',
                value: '${rv.prayJama} / ${rv.prayLogged}',
                sub: '${(rv.prayJama / rv.prayLogged * 100).round()}%',
                color: kEmerald,
              ),
            if (rv.hasMeds)
              StatTile(emoji: '💊', label: 'الالتزام بالأدوية', value: '${(rv.medAdh * 100).round()}%'),
          ]),
          if (sorted.isNotEmpty) ...[
            const SectionTitle('كل العادات'),
            for (final e in sorted)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AppCard(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      Text(e.key.emoji, style: const TextStyle(fontSize: 22)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(e.key.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: kText, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 5),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(5),
                              child: LinearProgressIndicator(
                                value: e.value,
                                minHeight: 6,
                                backgroundColor: a(kEmerald, 0.14),
                                valueColor: const AlwaysStoppedAnimation<Color>(kEmerald),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text('${(e.value * 100).round()}%',
                          style: const TextStyle(color: kEmerald, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
              ),
          ],
          const SectionTitle('تأمّلك للأسبوع'),
          const Text('ما الذي نجح؟ ما الذي عطّلك؟ ما الشيء الواحد الذي ستغيّره الأسبوع القادم؟',
              style: TextStyle(color: kMuted, fontSize: 12.5, height: 1.6)),
          const SizedBox(height: 8),
          TextField(
            controller: _note,
            maxLines: 5,
            style: const TextStyle(color: kText, height: 1.6),
            decoration: InputDecoration(
              filled: true,
              fillColor: kCard,
              hintText: 'اكتب هنا...',
              hintStyle: const TextStyle(color: kMuted),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: kLine)),
            ),
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: () {
              store.setReview(key, _note.text);
              toast(context, 'حُفظ تأمّلك ✓');
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════ تصدير التقارير ═════════════════════════

String _csvCell(String s) {
  final t = s.replaceAll('"', '""');
  return (t.contains(',') || t.contains('"') || t.contains('\n')) ? '"$t"' : t;
}

String _iso(int day) => dateOf(day).toIso8601String().substring(0, 10);

/// تقرير نصي لشهر محدّد
String buildMonthReport(AppStore store, int year, int month) {
  final ws = store.settings.weekStart;
  final today = todayNum();
  final first = dayOf(DateTime.utc(year, month, 1));
  final lastDay = dayOf(DateTime.utc(year, month + 1, 0));
  final end = lastDay < today ? lastDay : today;
  final b = StringBuffer();
  b.writeln('📊 تقرير شهر ${kMonthsAr[month - 1]} $year — التزام');
  b.writeln('━━━━━━━━━━━━━━');
  b.writeln('');
  b.writeln('العادات:');
  for (final h in store.habits) {
    if (h.createdDay > end) continue;
    final st = store.statsFor(h);
    if (h.period == PeriodType.day) {
      int considered = 0;
      int done = 0;
      for (int d = first; d <= end; d++) {
        if (d < h.createdDay || store.isFrozen(d)) continue;
        considered++;
        if (periodMetAtDay(h, ws, d)) done++;
      }
      final pct = considered == 0 ? 0 : (done / considered * 100).round();
      b.writeln('• ${h.emoji} ${h.name}: $done/$considered يوم ($pct%) • أفضل سلسلة ${st.bestStreak}');
    } else {
      double sum = 0;
      int days = 0;
      h.log.forEach((d, v) {
        if (d >= first && d <= end && v > 0) {
          sum += v;
          days++;
        }
      });
      final txt = h.kind == HabitKind.check
          ? '$days تسجيل'
          : (h.kind == HabitKind.timer ? fmtMinutes(sum) : '${num1(sum)} ${h.unit}');
      b.writeln('• ${h.emoji} ${h.name} (${periodAdj(h.period)}): $txt • أفضل سلسلة ${st.bestStreak}');
    }
  }
  int tasksDone = 0;
  for (final t in store.tasks) {
    if (t.done && t.doneDay >= first && t.doneDay <= end) tasksDone++;
  }
  int focus = 0;
  double moodSum = 0;
  int moodN = 0;
  int jama = 0;
  int logged = 0;
  for (int d = first; d <= end; d++) {
    focus += store.focus[d] ?? 0;
    final e = store.journal[d];
    if (e != null) {
      moodSum += e.mood;
      moodN++;
    }
    final s = store.prayerLog[d];
    if (s != null) {
      for (int i = 0; i < 5; i++) {
        if (s[i] != '0') logged++;
        if (s[i] == '1') jama++;
      }
    }
  }
  b.writeln('');
  b.writeln('✅ مهام منجزة: $tasksDone');
  b.writeln('🍅 وقت التركيز: ${fmtMinutes(focus.toDouble())}');
  if (moodN > 0) b.writeln('📝 متوسط المزاج: ${(moodSum / moodN).toStringAsFixed(1)} / 5 ($moodN يومًا)');
  if (logged > 0) b.writeln('🕌 الصلوات: $jama في جماعة من $logged مسجّلة');
  for (final m in store.metrics) {
    final ds = m.sortedDays().where((d) => d >= first && d <= end).toList();
    if (ds.isEmpty) continue;
    final f = m.entries[ds.first]!;
    final l = m.entries[ds.last]!;
    b.writeln('${m.emoji} ${m.name}: ${num1(f)} ← ${num1(l)} ${m.unit}');
  }
  for (final q in store.quits) {
    b.writeln('🚫 ${q.name}: نظيف منذ ${cleanDays(q.currentMs(DateTime.now().millisecondsSinceEpoch))} يومًا');
  }
  return b.toString();
}

int cleanDays(int ms) => ms ~/ 86400000;

/// ملف CSV كامل بكل السجلات
String buildCsv(AppStore store) {
  final b = StringBuffer();
  b.writeln('النوع,الاسم,التاريخ,القيمة,الحالة');
  for (final h in store.habits) {
    final days = h.log.keys.toList()..sort();
    for (final d in days) {
      b.writeln('عادة,${_csvCell(h.name)},${_iso(d)},${num1(h.log[d]!)},تمت');
    }
    final ms = h.missed.toList()..sort();
    for (final d in ms) {
      b.writeln('عادة,${_csvCell(h.name)},${_iso(d)},0,فاتت');
    }
  }
  for (final m in store.meds) {
    final keys = m.log.keys.toList()..sort();
    for (final k in keys) {
      final parts = k.split(':');
      final d = int.tryParse(parts[0]);
      final idx = parts.length > 1 ? int.tryParse(parts[1]) : null;
      if (d == null || idx == null || idx >= m.doses.length) continue;
      b.writeln('دواء,${_csvCell(m.name)},${_iso(d)} ${fmtClock(m.doses[idx])},${num1(m.amount)},${m.log[k] == 1 ? 'أُخذت' : 'تخطّيت'}');
    }
  }
  for (final m in store.metrics) {
    for (final d in m.sortedDays()) {
      b.writeln('قياس,${_csvCell(m.name)},${_iso(d)},${num1(m.entries[d]!)},${_csvCell(m.unit)}');
    }
  }
  final jd = store.journal.keys.toList()..sort();
  for (final d in jd) {
    b.writeln('مزاج,يومية,${_iso(d)},${store.journal[d]!.mood},${_csvCell(store.journal[d]!.note)}');
  }
  for (final t in store.tasks) {
    b.writeln('مهمة,${_csvCell(t.title)},${_iso(t.anchor)},${t.level.index},${t.done ? 'منجزة' : 'مفتوحة'}');
  }
  return b.toString();
}

Future<void> showReportSheet(BuildContext context) async {
  final store = StoreScope.of(context);
  final now = DateTime.now();
  final prevMonth = DateTime(now.year, now.month - 1, 1);
  final choice = await showModalBottomSheet<int>(
    context: context,
    backgroundColor: kSurface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
    builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('تصدير تقرير', style: TextStyle(color: kText, fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.summarize_rounded, color: kEmerald),
              title: Text('تقرير ${kMonthsAr[now.month - 1]} ${now.year}', style: const TextStyle(color: kText)),
              onTap: () => Navigator.pop(ctx, 1),
            ),
            ListTile(
              leading: const Icon(Icons.history_rounded, color: kGold),
              title: Text('تقرير ${kMonthsAr[prevMonth.month - 1]} ${prevMonth.year}', style: const TextStyle(color: kText)),
              onTap: () => Navigator.pop(ctx, 2),
            ),
            ListTile(
              leading: const Icon(Icons.table_chart_rounded, color: kMuted),
              title: const Text('كل السجلات (CSV للإكسل)', style: TextStyle(color: kText)),
              onTap: () => Navigator.pop(ctx, 3),
            ),
          ],
        ),
      ),
    ),
  );
  if (choice == null || !context.mounted) return;
  String text;
  String title;
  if (choice == 1) {
    text = buildMonthReport(store, now.year, now.month);
    title = 'تقرير الشهر';
  } else if (choice == 2) {
    text = buildMonthReport(store, prevMonth.year, prevMonth.month);
    title = 'تقرير الشهر الماضي';
  } else {
    text = buildCsv(store);
    title = 'ملف CSV';
  }
  await Clipboard.setData(ClipboardData(text: text));
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: kCard,
        title: Text('$title (نُسخ إلى الحافظة ✓)', style: const TextStyle(color: kText, fontSize: 15)),
        content: SizedBox(
          width: double.maxFinite,
          height: 320,
          child: SingleChildScrollView(
            child: SelectableText(text, style: const TextStyle(color: kText, fontSize: 12.5, height: 1.7)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق')),
        ],
      ),
    ),
  );
}
