import 'package:flutter/material.dart';
import 'habit_widgets.dart';
import 'hijri.dart';
import 'models.dart';
import 'prayer.dart';
import 'screen_editor.dart';
import 'screen_habit.dart';
import 'stats.dart';
import 'store.dart';
import 'ui_common.dart';
import 'util.dart';

class TodayScreen extends StatefulWidget {
  final void Function(int tab) goTab;
  const TodayScreen({super.key, required this.goTab});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  int? picked;

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'صباح الخير 🌅';
    if (h < 17) return 'نهارك سعيد ☀️';
    return 'مساء الخير 🌙';
  }

  String _nextPrayer(Settings s) {
    final w = kWilayas[clampI(s.wilaya, 0, kWilayas.length - 1)];
    final now = DateTime.now();
    final nowMin = now.hour * 60 + now.minute;
    final p = prayersFor(todayNum(), w);
    for (int i = 0; i < 5; i++) {
      final m = toMinutes(p.byIndex(i));
      if (m > nowMin) return '🕌 ${kPrayerNames[i]} ${fmtClock(m)}';
    }
    final t = prayersFor(todayNum() + 1, w);
    return '🕌 الفجر ${fmtHour(t.fajr)}';
  }

  double _dayRatio(List<Habit> habits, int day, int ws) {
    int total = 0;
    int done = 0;
    for (final h in habits) {
      if (h.period != PeriodType.day) continue;
      if (day < h.createdDay) continue;
      total++;
      if (periodMetAtDay(h, ws, day)) done++;
    }
    return total == 0 ? 0 : done / total;
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final ws = store.settings.weekStart;
    final today = todayNum();
    final day = picked ?? today;
    final habits = store.active;
    final all = store.allStats();

    int total = habits.length;
    int met = 0;
    for (final h in habits) {
      if (periodMetAtDay(h, ws, day)) met++;
    }
    int xp = 0;
    for (final h in store.habits) {
      final st = all[h.id];
      if (st != null) xp += xpOf(h, st);
    }
    final lvl = levelFor(xp);
    final hijri = hijriText(day, store.settings.hijriAdjust);
    final wd = kWeekdaysAr[weekdayOf(day) - 1];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 110),
      children: [
        // ── الترويسة
        AppCard(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [a(kEmerald, 0.22), kCard],
          ),
          borderColor: a(kEmerald, 0.35),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_greeting(),
                            style: const TextStyle(color: kText, fontSize: 22, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 4),
                        Text('$wd ${fmtDay(day)}',
                            style: const TextStyle(color: kText, fontSize: 13.5)),
                        Text(hijri, style: const TextStyle(color: kGold, fontSize: 12.5)),
                      ],
                    ),
                  ),
                  Ring(
                    progress: total == 0 ? 0 : met / total,
                    color: kEmerald,
                    size: 70,
                    stroke: 8,
                    child: Text('$met/$total',
                        style: const TextStyle(color: kText, fontSize: 15, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: () => widget.goTab(3),
                child: Row(
                  children: [
                    Text('🛡️ ${lvl.title}  •  م${lvl.level}',
                        style: const TextStyle(color: kGold, fontSize: 13, fontWeight: FontWeight.w800)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: lvl.progress,
                          minHeight: 6,
                          backgroundColor: a(kGold, 0.15),
                          valueColor: const AlwaysStoppedAnimation<Color>(kGold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text('${lvl.xp} XP', style: const TextStyle(color: kMuted, fontSize: 11.5)),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => widget.goTab(2),
                child: Text(_nextPrayer(store.settings),
                    style: const TextStyle(color: kMuted, fontSize: 12.5)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ── شريط الأيام
        SizedBox(
          height: 78,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: 21,
            itemBuilder: (context, i) {
              final d = today - i;
              final sel = d == day;
              final ratio = _dayRatio(habits, d, ws);
              return Padding(
                padding: const EdgeInsets.only(left: 8),
                child: GestureDetector(
                  onTap: () => setState(() => picked = d == today ? null : d),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 56,
                    decoration: BoxDecoration(
                      color: sel ? a(kEmerald, 0.16) : kCard,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: sel ? kEmerald : kLine, width: sel ? 1.6 : 1),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(i == 0 ? 'اليوم' : kWeekdaysShort[weekdayOf(d) - 1],
                            style: TextStyle(color: sel ? kEmerald : kMuted, fontSize: 11.5)),
                        const SizedBox(height: 3),
                        Text('${dateOf(d).day}',
                            style: const TextStyle(color: kText, fontSize: 17, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Container(
                          width: 22,
                          height: 4,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            color: ratio >= 1
                                ? kEmerald
                                : ratio > 0
                                    ? a(kEmerald, 0.45)
                                    : kLine,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        if (picked != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: a(kGold, 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.history_rounded, color: kGold, size: 18),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('أنت تعدّل يومًا سابقًا',
                        style: TextStyle(color: kGold, fontSize: 12.5)),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => picked = null),
                    child: const Text('العودة لليوم',
                        style: TextStyle(color: kEmerald, fontSize: 12.5, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            ),
          ),

        if (habits.isEmpty) _empty(context),

        for (final p in PeriodType.values) ..._section(context, store, habits, all, p, day, ws),
      ],
    );
  }

  List<Widget> _section(BuildContext context, AppStore store, List<Habit> habits,
      Map<String, HabitStats> all, PeriodType p, int day, int ws) {
    final list = habits.where((h) => h.period == p).toList();
    if (list.isEmpty) return const [];
    return [
      SectionTitle('مهام ${periodAdj(p)}ة'.replaceAll('يةة', 'ية'),
          trailing: Text('${list.length}', style: const TextStyle(color: kMuted))),
      for (final h in list)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: HabitCard(
            habit: h,
            day: day,
            stats: all[h.id]!,
            weekStart: ws,
            onOpen: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => HabitDetailScreen(habitId: h.id),
            )),
          ),
        ),
    ];
  }

  Widget _empty(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 26),
      child: AppCard(
        child: Column(
          children: [
            const Text('🛡️', style: TextStyle(fontSize: 54)),
            const SizedBox(height: 10),
            const Text('ابدأ رحلة الالتزام',
                style: TextStyle(color: kText, fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            const Text(
              'أضف أول عادة وابنِ سلسلتك يومًا بيوم. اختر قالبًا جاهزًا أو أنشئ عادتك الخاصة.',
              textAlign: TextAlign.center,
              style: TextStyle(color: kMuted, height: 1.6),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                for (final t in kTemplates.take(6))
                  ActionChip(
                    backgroundColor: kCard2,
                    side: const BorderSide(color: kLine),
                    label: Text('${t.emoji} ${t.name}',
                        style: const TextStyle(color: kText, fontSize: 12.5)),
                    onPressed: () => showHabitEditor(context, template: t),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () => showHabitEditor(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('عادة جديدة'),
            ),
          ],
        ),
      ),
    );
  }
}
