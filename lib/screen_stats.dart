import 'package:flutter/material.dart';
import 'habit_widgets.dart';
import 'models.dart';
import 'screen_habit.dart';
import 'stats.dart';
import 'store.dart';
import 'ui_common.dart';
import 'util.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final ws = store.settings.weekStart;
    final today = todayNum();
    final habits = store.active;
    final all = store.allStats();

    if (habits.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('أضف عادات لتظهر تحليلاتك هنا 📊',
              textAlign: TextAlign.center, style: TextStyle(color: kMuted, fontSize: 16)),
        ),
      );
    }

    // ── مؤشرات عامة
    int totalEntries = 0;
    double avgStrength = 0;
    HabitStats? bestSt;
    Habit? bestH;
    for (final h in habits) {
      final st = all[h.id]!;
      totalEntries += st.activeDays;
      avgStrength += st.strength;
      if (bestSt == null || st.bestStreak > bestSt.bestStreak) {
        bestSt = st;
        bestH = h;
      }
    }
    avgStrength /= habits.length;

    // ── آخر 30 يومًا للعادات اليومية
    final daily = habits.where((h) => h.period == PeriodType.day).toList();
    final last30 = <double>[];
    final labels30 = <String>[];
    for (int i = 29; i >= 0; i--) {
      final d = today - i;
      int tot = 0;
      int done = 0;
      for (final h in daily) {
        if (d < h.createdDay) continue;
        tot++;
        if (periodMetAtDay(h, ws, d)) done++;
      }
      last30.add(tot == 0 ? 0 : done / tot * 100);
      labels30.add(i % 5 == 0 ? '${dateOf(d).day}' : '');
    }

    // ── خريطة حرارية عامة
    final overall = <int, double>{};
    for (int i = 0; i < 18 * 7; i++) {
      final d = today - i;
      int tot = 0;
      int done = 0;
      for (final h in daily) {
        if (d < h.createdDay) continue;
        tot++;
        if (periodMetAtDay(h, ws, d)) done++;
      }
      if (tot > 0 && done > 0) overall[d] = done / tot;
    }

    // ── أيام الأسبوع
    final wdDone = List<int>.filled(8, 0);
    final wdTot = List<int>.filled(8, 0);
    for (int i = 0; i < 90; i++) {
      final d = today - i;
      final w = weekdayOf(d);
      for (final h in daily) {
        if (d < h.createdDay) continue;
        wdTot[w]++;
        if (periodMetAtDay(h, ws, d)) wdDone[w]++;
      }
    }
    final wdVals = <double>[];
    final wdLabels = <String>[];
    // ترتيب العرض: من بداية الأسبوع المختار
    for (int i = 0; i < 7; i++) {
      final w = ((ws - 1 + i) % 7) + 1;
      wdVals.add(wdTot[w] == 0 ? 0 : wdDone[w] / wdTot[w] * 100);
      wdLabels.add(kWeekdaysShort[w - 1]);
    }
    int bestW = 1;
    double bestWv = -1;
    int worstW = 1;
    double worstWv = 101;
    for (int w = 1; w <= 7; w++) {
      if (wdTot[w] == 0) continue;
      final v = wdDone[w] / wdTot[w] * 100;
      if (v > bestWv) {
        bestWv = v;
        bestW = w;
      }
      if (v < worstWv) {
        worstWv = v;
        worstW = w;
      }
    }

    // ── ترتيب العادات
    final ranked = [...habits]..sort((a, b) => all[b.id]!.strength.compareTo(all[a.id]!.strength));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 110),
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 6, 4, 4),
          child: Text('التحليلات', style: TextStyle(color: kText, fontSize: 26, fontWeight: FontWeight.w900)),
        ),
        const SectionTitle('نظرة عامة'),
        TwoColumn(children: [
          StatTile(
            emoji: '💪',
            label: 'متوسط قوة العادات',
            value: '${(avgStrength * 100).round()}%',
            sub: strengthLabel(avgStrength),
            color: kEmerald,
          ),
          StatTile(emoji: '✅', label: 'إجمالي التسجيلات', value: '$totalEntries', sub: 'عبر كل العادات'),
          StatTile(
            emoji: '👑',
            label: 'أطول سلسلة على الإطلاق',
            value: bestSt == null || bestSt.bestStreak == 0 ? '—' : periodCount(bestH!.period, bestSt.bestStreak),
            sub: bestH == null || bestSt!.bestStreak == 0 ? null : '${bestH.emoji} ${bestH.name}',
            color: kGold,
          ),
          StatTile(emoji: '📋', label: 'عادات نشطة', value: '${habits.length}', sub: 'أرشيف: ${store.archived.length}'),
        ]),
        if (daily.isNotEmpty) ...[
          const SectionTitle('نسبة إنجاز العادات اليومية (30 يومًا)'),
          AppCard(
            child: MiniBars(
              values: last30,
              labels: labels30,
              color: kEmerald,
              target: 100,
              height: 130,
            ),
          ),
          const SectionTitle('خريطة الالتزام العامة'),
          AppCard(
            child: Heatmap(intensity: overall, today: today, weekStart: ws, color: kEmerald),
          ),
          const SectionTitle('أيام الأسبوع (آخر 90 يومًا)'),
          AppCard(
            child: Column(
              children: [
                MiniBars(values: wdVals, labels: wdLabels, color: kGold, height: 110),
                const SizedBox(height: 10),
                if (bestWv >= 0)
                  Text(
                    'أقوى يوم: ${kWeekdaysAr[bestW - 1]} (${bestWv.round()}%)  •  أضعف يوم: ${kWeekdaysAr[worstW - 1]} (${worstWv.round()}%)',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: kMuted, fontSize: 12.5, height: 1.5),
                  ),
              ],
            ),
          ),
        ],
        const SectionTitle('ترتيب العادات حسب القوة'),
        for (final h in ranked)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => HabitDetailScreen(habitId: h.id),
              )),
              child: Row(
                children: [
                  Text(h.emoji, style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(h.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: kText, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(5),
                          child: LinearProgressIndicator(
                            value: all[h.id]!.strength,
                            minHeight: 6,
                            backgroundColor: a(habitColor(h), 0.14),
                            valueColor: AlwaysStoppedAnimation<Color>(habitColor(h)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('${(all[h.id]!.strength * 100).round()}%',
                      style: TextStyle(color: habitColor(h), fontWeight: FontWeight.w900, fontSize: 16)),
                ],
              ),
            ),
          ),
        const SectionTitle('كيف تُحسب قوة العادة؟'),
        const AppCard(
          child: Text(
            'قوة العادة متوسّط متحرّك أُسّي: كل يوم تنجز فيه يرفع الرقم، وكل يوم تفوّته يخفضه قليلًا فقط. '
            'لذلك لا يُصفَّر تعب أشهر بسبب تعثّر واحد، لكن الانقطاع الطويل يُنزله تدريجيًا. '
            'أمّا السلسلة فصارمة: أي فترة فائتة تُعيدها إلى الصفر.',
            style: TextStyle(color: kMuted, height: 1.7, fontSize: 13),
          ),
        ),
      ],
    );
  }
}
