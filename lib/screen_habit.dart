import 'package:flutter/material.dart';
import 'habit_widgets.dart';
import 'models.dart';
import 'screen_editor.dart';
import 'stats.dart';
import 'store.dart';
import 'ui_common.dart';
import 'util.dart';

class HabitDetailScreen extends StatelessWidget {
  final String habitId;
  const HabitDetailScreen({super.key, required this.habitId});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final h = store.byId(habitId);
    if (h == null) {
      return const Scaffold(body: Center(child: Text('العادة غير موجودة')));
    }
    final ws = store.settings.weekStart;
    final today = todayNum();
    final st = computeStats(h, ws, today);
    final color = habitColor(h);
    final pcLabel = periodAdjUnit(h.period);
    final level = levelFor(xpOf(h, st));

    final nBars = h.period == PeriodType.day ? 14 : (h.period == PeriodType.week ? 12 : (h.period == PeriodType.month ? 12 : 5));
    final bars = recentPeriodValues(h, ws, today, nBars);
    final barLabels = recentPeriodLabels(h, ws, today, nBars);

    // خريطة حرارية: شدة كل يوم
    final intensity = <int, double>{};
    final tgt = h.target <= 0 ? 1.0 : h.target;
    h.log.forEach((d, v) {
      if (v <= 0) return;
      if (h.kind == HabitKind.check || h.period != PeriodType.day) {
        intensity[d] = 1;
      } else {
        intensity[d] = clampD(v / tgt, 0.0, 1.0);
      }
    });

    String bestStreakText() {
      if (st.bestStreak == 0) return 'لا توجد بعد';
      return periodCount(h.period, st.bestStreak);
    }

    String bestStreakSub() {
      if (st.bestStreak == 0) return 'سجّل أول إنجاز';
      return '${fmtShort(st.bestStartDay)} ← ${fmtShort(st.bestEndDay)}';
    }

    final goalLine = goalText(h);

    return Scaffold(
      appBar: AppBar(
        title: Text('${h.emoji} ${h.name}', overflow: TextOverflow.ellipsis),
        actions: [
          PopupMenuButton<String>(
            color: kCard2,
            onSelected: (v) async {
              if (v == 'edit') {
                showHabitEditor(context, habit: h);
              } else if (v == 'archive') {
                store.setArchived(h, !h.archived);
                if (context.mounted) {
                  toast(context, h.archived ? 'أُرشفت العادة' : 'أُعيدت العادة');
                  Navigator.of(context).pop();
                }
              } else if (v == 'delete') {
                final ok = await confirmDialog(
                    context, 'حذف العادة؟', 'سيُحذف كل سجلّها وأرقامها القياسية نهائيًا.',
                    ok: 'حذف', danger: true);
                if (ok && context.mounted) {
                  store.deleteHabit(h);
                  Navigator.of(context).pop();
                }
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Text('تعديل')),
              PopupMenuItem(value: 'archive', child: Text(h.archived ? 'إلغاء الأرشفة' : 'أرشفة')),
              const PopupMenuItem(value: 'delete', child: Text('حذف', style: TextStyle(color: kDanger))),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 60),
        children: [
          // ── البطل
          AppCard(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [a(color, 0.24), kCard],
            ),
            borderColor: a(color, 0.4),
            child: Column(
              children: [
                Row(
                  children: [
                    Ring(
                      progress: st.strength,
                      color: color,
                      size: 92,
                      stroke: 9,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('${(st.strength * 100).round()}%',
                              style: const TextStyle(color: kText, fontSize: 21, fontWeight: FontWeight.w900)),
                          Text(strengthLabel(st.strength), style: TextStyle(color: color, fontSize: 11)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('السلسلة الحالية', style: TextStyle(color: kMuted, fontSize: 12.5)),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('🔥 ${st.currentStreak}',
                                  style: const TextStyle(color: kGold, fontSize: 34, fontWeight: FontWeight.w900)),
                              const SizedBox(width: 6),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Text(pcLabel == 'يوم' ? 'يوم متتالي' : '$pcLabel متتالي',
                                    style: const TextStyle(color: kMuted, fontSize: 13)),
                              ),
                            ],
                          ),
                          Text('الهدف: $goalLine', style: const TextStyle(color: kMuted, fontSize: 12.5)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(progressText(h, st.periodValue, st.todayDone),
                        style: TextStyle(color: st.periodMet ? color : kText, fontWeight: FontWeight.w700)),
                    HabitActions(habit: h, day: today),
                  ],
                ),
              ],
            ),
          ),

          const SectionTitle('الأرقام القياسية 🏆'),
          TwoColumn(children: [
            StatTile(
              emoji: '👑',
              label: 'أفضل سلسلة',
              value: bestStreakText(),
              sub: bestStreakSub(),
              color: kGold,
            ),
            StatTile(
              emoji: '🔥',
              label: 'السلسلة الحالية',
              value: st.currentStreak == 0 ? 'صفر' : periodCount(h.period, st.currentStreak),
              sub: st.currentStreak > 0 && st.currentStreak >= st.bestStreak
                  ? 'أنت في أفضل مستوياتك!'
                  : (st.bestStreak > st.currentStreak
                      ? 'تبقّى ${st.bestStreak - st.currentStreak + 1} لتحطيم رقمك'
                      : 'ابدأ اليوم'),
              color: kEmerald,
            ),
            StatTile(
              emoji: '⭐',
              label: h.period == PeriodType.day ? 'أفضل يوم' : 'أفضل ${periodAdjUnit(h.period)}',
              value: h.kind == HabitKind.check
                  ? (h.period == PeriodType.day ? (st.activeDays > 0 ? 'تم' : '—') : '${num1(st.bestPeriodValue)} مرة')
                  : (h.kind == HabitKind.timer
                      ? fmtMinutes(h.period == PeriodType.day ? st.bestDayValue : st.bestPeriodValue)
                      : '${num1(h.period == PeriodType.day ? st.bestDayValue : st.bestPeriodValue)} ${h.unit}'),
              sub: h.period == PeriodType.day && st.bestDayNum > 0 ? fmtShort(st.bestDayNum) : null,
            ),
            StatTile(
              emoji: '✅',
              label: 'فترات مكتملة',
              value: '${st.completedPeriods}',
              sub: 'من أصل ${st.activeDays} تسجيل',
            ),
            StatTile(
              emoji: '📈',
              label: 'نسبة الالتزام الكلية',
              value: '${(st.rateAll * 100).round()}%',
              sub: 'منذ البداية',
              color: color,
            ),
            StatTile(
              emoji: '⚡',
              label: 'آخر فترة',
              value: '${(st.rateRecent * 100).round()}%',
              sub: h.period == PeriodType.day ? 'آخر 30 يومًا' : (h.period == PeriodType.week ? 'آخر 12 أسبوعًا' : 'الفترات الأخيرة'),
              color: st.rateRecent >= st.rateAll ? kEmerald : kDanger,
            ),
            if (h.kind != HabitKind.check)
              StatTile(
                emoji: '∑',
                label: 'المجموع الكلي',
                value: h.kind == HabitKind.timer ? fmtMinutes(st.total) : '${num1(st.total)} ${h.unit}',
              ),
            if (st.bestWeekday > 0)
              StatTile(
                emoji: '📅',
                label: 'أقوى أيامك',
                value: kWeekdaysAr[st.bestWeekday - 1],
                sub: 'الأكثر تسجيلًا',
              ),
          ]),

          const SectionTitle('المستوى والنقاط'),
          AppCard(
            child: Row(
              children: [
                Text('🛡️', style: TextStyle(fontSize: 32, color: color)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${level.title}  •  المستوى ${level.level}',
                          style: const TextStyle(color: kGold, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: level.progress,
                          minHeight: 7,
                          backgroundColor: a(kGold, 0.15),
                          valueColor: const AlwaysStoppedAnimation<Color>(kGold),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('${level.into} / ${level.span} XP للمستوى التالي',
                          style: const TextStyle(color: kMuted, fontSize: 11.5)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          SectionTitle(h.period == PeriodType.day
              ? 'آخر 14 يومًا'
              : h.period == PeriodType.week
                  ? 'آخر 12 أسبوعًا'
                  : h.period == PeriodType.month
                      ? 'آخر 12 شهرًا'
                      : 'آخر السنوات'),
          AppCard(
            child: MiniBars(
              values: bars,
              labels: barLabels,
              color: color,
              target: h.target <= 0 ? 1 : h.target,
              height: 140,
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 6, right: 4),
            child: Text('الخط الذهبي = هدفك. العمود الكامل اللون = الهدف تحقّق.',
                style: TextStyle(color: kMuted, fontSize: 11.5)),
          ),

          const SectionTitle('خريطة الالتزام'),
          AppCard(
            child: Heatmap(
              intensity: intensity,
              today: today,
              weekStart: ws,
              color: color,
              onTapDay: (d) => _editDay(context, store, h, d),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 6, right: 4),
            child: Text('اضغط على أي مربع لتعديل ذلك اليوم.',
                style: TextStyle(color: kMuted, fontSize: 11.5)),
          ),
        ],
      ),
    );
  }

  Future<void> _editDay(BuildContext context, AppStore store, Habit h, int day) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: kSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${kWeekdaysAr[weekdayOf(day) - 1]} ${fmtDay(day)}',
                    style: const TextStyle(color: kText, fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 16),
                ListenableBuilder(
                  listenable: store,
                  builder: (_, __) => HabitActions(habit: h, day: day),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    store.setValue(h, day, 0);
                    Navigator.pop(ctx);
                  },
                  child: const Text('مسح هذا اليوم', style: TextStyle(color: kDanger)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
