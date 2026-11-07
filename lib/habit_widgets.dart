import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models.dart';
import 'stats.dart';
import 'store.dart';
import 'ui_common.dart';
import 'util.dart';

Color habitColor(Habit h) => kHabitColors[h.colorIdx % kHabitColors.length];

double stepFor(Habit h) {
  if (h.kind != HabitKind.count) return 1;
  if (h.target >= 200) return 25;
  if (h.target >= 50) return 5;
  return 1;
}

String progressText(Habit h, double pv, bool todayDoneForDay, {bool missed = false}) {
  final u = h.unit.isEmpty ? '' : ' ${h.unit}';
  switch (h.kind) {
    case HabitKind.check:
      if (h.period == PeriodType.day) return todayDoneForDay ? 'تم ✓' : (missed ? 'فاتت ✗' : 'لم يتم بعد');
      return '${num1(pv)} / ${num1(h.target)} ${periodThis(h.period)}';
    case HabitKind.count:
      final tail = h.period == PeriodType.day ? '' : ' ${periodThis(h.period)}';
      return '${num1(pv)} / ${num1(h.target)}$u$tail';
    case HabitKind.timer:
      final tail = h.period == PeriodType.day ? '' : ' ${periodThis(h.period)}';
      return '${fmtMinutes(pv)} / ${fmtMinutes(h.target)}$tail';
  }
}

/// أزرار التسجيل حسب نوع العادة
class HabitActions extends StatelessWidget {
  final Habit habit;
  final int day;
  const HabitActions({super.key, required this.habit, required this.day});

  void _act(BuildContext context, AppStore store, VoidCallback fn) {
    HapticFeedback.lightImpact();
    final before = store.statsFor(habit).currentStreak;
    fn();
    final after = store.statsFor(habit).currentStreak;
    if (after > before && kMilestones.contains(after)) {
      toast(context, '🔥 ما شاء الله! سلسلة ${periodCount(habit.period, after)}');
    }
  }

  Future<void> _manual(BuildContext context, AppStore store) async {
    final cur = habit.log[day] ?? 0;
    final v = await askNumber(
      context,
      title: habit.kind == HabitKind.timer ? 'عدد الدقائق' : 'الكمية',
      initial: cur,
      suffix: habit.kind == HabitKind.timer ? 'دقيقة' : habit.unit,
    );
    if (v == null) return;
    if (!context.mounted) return;
    _act(context, store, () => store.setValue(habit, day, v));
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final color = habitColor(habit);
    final v = habit.log[day] ?? 0;
    final isToday = day == todayNum();

    if (day > todayNum()) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_outlined, color: kMuted, size: 22),
            Text('مخطَّط', style: TextStyle(color: kMuted, fontSize: 10.5)),
          ],
        ),
      );
    }

    switch (habit.kind) {
      case HabitKind.check:
        final cs = store.checkState(habit, day);
        final done = cs == 1;
        final missed = cs == 2;
        final daily = habit.period == PeriodType.day;
        return GestureDetector(
          onTap: () => _act(context, store, () {
            if (daily) {
              store.cycleCheck(habit, day);
            } else {
              store.toggleCheck(habit, day);
            }
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done ? color : (missed ? a(kDanger, 0.16) : Colors.transparent),
              border: Border.all(color: done ? color : (missed ? kDanger : kLine), width: 2),
            ),
            child: Icon(missed ? Icons.close_rounded : Icons.check_rounded,
                size: 28, color: done ? Colors.black : (missed ? kDanger : kMuted)),
          ),
        );

      case HabitKind.count:
        final step = stepFor(habit);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _RoundBtn(
              icon: Icons.remove_rounded,
              color: color,
              onTap: v <= 0 ? null : () => _act(context, store, () => store.addAmount(habit, day, -step)),
            ),
            GestureDetector(
              onTap: () => _manual(context, store),
              child: Container(
                constraints: const BoxConstraints(minWidth: 44),
                alignment: Alignment.center,
                child: Text(num1(v),
                    style: TextStyle(
                        color: v > 0 ? color : kMuted, fontSize: 20, fontWeight: FontWeight.w800)),
              ),
            ),
            _RoundBtn(
              icon: Icons.add_rounded,
              color: color,
              filled: true,
              onTap: () => _act(context, store, () => store.addAmount(habit, day, step)),
            ),
          ],
        );

      case HabitKind.timer:
        final running = habit.timerStartMs != null;
        if (running && isToday) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElapsedText(startMs: habit.timerStartMs!),
              const SizedBox(width: 10),
              _RoundBtn(
                icon: Icons.stop_rounded,
                color: kDanger,
                filled: true,
                onTap: () {
                  HapticFeedback.mediumImpact();
                  final before = store.statsFor(habit).currentStreak;
                  final m = store.stopTimer(habit);
                  final after = store.statsFor(habit).currentStreak;
                  toast(context, m >= 0.1 ? 'أُضيفت ${fmtMinutes(m)} ✓' : 'مدة قصيرة جدًا، لم تُسجَّل');
                  if (after > before && kMilestones.contains(after)) {
                    toast(context, '🔥 ما شاء الله! سلسلة ${periodCount(habit.period, after)}');
                  }
                },
              ),
            ],
          );
        }
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () => _manual(context, store),
              child: Text(v > 0 ? fmtMinutes(v) : '— د',
                  style: TextStyle(
                      color: v > 0 ? color : kMuted, fontSize: 16, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 10),
            if (isToday)
              _RoundBtn(
                icon: Icons.play_arrow_rounded,
                color: color,
                filled: true,
                onTap: () {
                  HapticFeedback.lightImpact();
                  store.startTimer(habit);
                },
              )
            else
              _RoundBtn(icon: Icons.edit_rounded, color: color, onTap: () => _manual(context, store)),
          ],
        );
    }
  }
}

class _RoundBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool filled;
  final VoidCallback? onTap;
  const _RoundBtn({required this.icon, required this.color, this.filled = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: filled ? (enabled ? color : kCard2) : Colors.transparent,
          border: Border.all(color: enabled ? color : kLine, width: 1.6),
        ),
        child: Icon(icon,
            size: 22, color: filled ? (enabled ? Colors.black : kMuted) : (enabled ? color : kLine)),
      ),
    );
  }
}

class MiniChip extends StatelessWidget {
  final String text;
  final Color color;
  const MiniChip(this.text, {super.key, this.color = kMuted});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: a(color, 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text,
          style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w700)),
    );
  }
}

class HabitCard extends StatelessWidget {
  final Habit habit;
  final int day;
  final HabitStats stats;
  final int weekStart;
  final VoidCallback onOpen;
  const HabitCard({
    super.key,
    required this.habit,
    required this.day,
    required this.stats,
    required this.weekStart,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final color = habitColor(habit);
    final pv = periodValueAtDay(habit, weekStart, day);
    final target = habit.target <= 0 ? 1.0 : habit.target;
    final frac = clampD(pv / target, 0.0, 1.0);
    final met = pv >= target - 0.000001;
    final doneThatDay = (habit.log[day] ?? 0) > 0;
    final showBar = !(habit.kind == HabitKind.check && habit.period == PeriodType.day);

    return AppCard(
      onTap: onOpen,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      borderColor: met ? a(color, 0.55) : kLine,
      child: Column(
        children: [
          Row(
            children: [
              EmojiBadge(emoji: habit.emoji, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(habit.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: kText, fontSize: 16.5, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 3),
                    Text(progressText(habit, pv, doneThatDay, missed: habit.missed.contains(day)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: met ? color : kMuted, fontSize: 12.5)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              HabitActions(habit: habit, day: day),
            ],
          ),
          if (showBar) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: frac,
                minHeight: 6,
                backgroundColor: a(color, 0.14),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              MiniChip('🔥 ${stats.currentStreak}  ${periodAdjUnit(habit.period)}',
                  color: stats.currentStreak > 0 ? kGold : kMuted),
              const SizedBox(width: 6),
              MiniChip('💪 ${(stats.strength * 100).round()}%', color: color),
              const Spacer(),
              if (habit.reminderKind != 0)
                const Icon(Icons.notifications_active_outlined, size: 16, color: kMuted),
              if (habit.timerStartMs != null && habit.kind == HabitKind.timer)
                const Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: Icon(Icons.timer_outlined, size: 16, color: kEmerald),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

String periodAdjUnit(PeriodType p) {
  switch (p) {
    case PeriodType.day:
      return 'يوم';
    case PeriodType.week:
      return 'أسبوع';
    case PeriodType.month:
      return 'شهر';
    case PeriodType.year:
      return 'سنة';
  }
}
