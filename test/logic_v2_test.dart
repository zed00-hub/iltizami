import 'package:flutter_test/flutter_test.dart';
import 'package:iltizam/models.dart';
import 'package:iltizam/models_ext.dart';
import 'package:iltizam/planning.dart';
import 'package:iltizam/stats.dart';
import 'package:iltizam/util.dart';

void main() {
  final today = dayOf(DateTime.utc(2026, 11, 5)); // الخميس
  const ws = 7;

  group('tasks hierarchy', () {
    test('progress from children when byChildren', () {
      final year = Task(id: 'y', title: 'سنة', level: PeriodType.year, anchor: today, createdDay: today, byChildren: true);
      final m1 = Task(id: 'm1', title: 'شهر', level: PeriodType.month, anchor: today, createdDay: today, parentId: 'y', done: true);
      final m2 = Task(id: 'm2', title: 'شهر2', level: PeriodType.month, anchor: today, createdDay: today, parentId: 'y');
      final all = [year, m1, m2];
      expect(taskProgress(year, all), closeTo(0.5, 1e-9));
      expect(taskIsDone(year, all), false);
      m2.done = true;
      expect(taskIsDone(year, all), true);
    });

    test('independent plan ignores children', () {
      final y = Task(id: 'y', title: 'x', level: PeriodType.year, anchor: today, createdDay: today);
      final c = Task(id: 'c', title: 'c', level: PeriodType.month, anchor: today, createdDay: today, parentId: 'y', done: true);
      expect(taskProgress(y, [y, c]), 0.0);
      expect(taskIsDone(y, [y, c]), false);
    });

    test('subtasks give partial progress', () {
      final t = Task(id: 't', title: 't', anchor: today, createdDay: today, subs: [SubTask('a', done: true), SubTask('b')]);
      expect(taskProgress(t, [t]), closeTo(0.5, 1e-9));
    });

    test('overdue only after the period ended', () {
      final d = Task(id: 'd', title: 'd', anchor: today - 1, createdDay: today - 3);
      expect(taskOverdue(d, [d], ws, today), true);
      final w = Task(id: 'w', title: 'w', level: PeriodType.week, anchor: today, createdDay: today);
      expect(taskOverdue(w, [w], ws, today), false);
      final w2 = Task(id: 'w2', title: 'w2', level: PeriodType.week, anchor: today - 14, createdDay: today - 14);
      expect(taskOverdue(w2, [w2], ws, today), true);
    });

    test('parent candidates are higher levels only', () {
      final y = Task(id: 'y', title: 'y', level: PeriodType.year, anchor: today, createdDay: today);
      final m = Task(id: 'm', title: 'm', level: PeriodType.month, anchor: today, createdDay: today);
      final d = Task(id: 'd', title: 'd', anchor: today, createdDay: today);
      final c = parentCandidates([y, m, d], PeriodType.week, null);
      expect(c.map((t) => t.id).toList()..sort(), ['m', 'y']);
    });

    test('shifted keys move by period', () {
      final k0 = shiftedKey(PeriodType.week, ws, today, 0);
      final k1 = shiftedKey(PeriodType.week, ws, today, 1);
      expect(k1 - k0, 7);
      expect(shiftedKey(PeriodType.day, ws, today, -2), today - 2);
    });
  });

  group('medications', () {
    test('stock and days left', () {
      final m = Med(id: 'a', name: 'x', startDay: today, doses: [480, 1200], amount: 1, stock: 10);
      expect(m.daysLeft(), closeTo(5.0, 1e-9));
      final untracked = Med(id: 'b', name: 'y', startDay: today);
      expect(untracked.daysLeft(), -1);
    });

    test('activeOn respects start and end', () {
      final m = Med(id: 'a', name: 'x', startDay: today, endDay: today + 6);
      expect(m.activeOn(today - 1), false);
      expect(m.activeOn(today), true);
      expect(m.activeOn(today + 6), true);
      expect(m.activeOn(today + 7), false);
    });

    test('json roundtrip', () {
      final m = Med(id: 'a', name: 'دواء', startDay: today, doses: [1200, 480], stock: 3.5);
      m.log[Med.key(today, 0)] = 1;
      final m2 = Med.fromJson(m.toJson());
      expect(m2.doses, [480, 1200]);
      expect(m2.stock, 3.5);
      expect(m2.state(today, 0), 1);
    });
  });

  group('vacation freeze', () {
    test('frozen days neither break nor add to a daily streak', () {
      final h = Habit(id: 'v', name: 'x', createdDay: today - 20);
      // أنجز قبل الإجازة بيومين ثم إجازة 3 أيام ثم اليوم
      for (final d in [today - 6, today - 5, today]) {
        h.log[d] = 1;
      }
      bool frozen(int d) => d >= today - 4 && d <= today - 1;
      final withFreeze = computeStats(h, ws, today, frozen: frozen);
      expect(withFreeze.currentStreak, 3);
      final without = computeStats(h, ws, today);
      expect(without.currentStreak, 1);
    });
  });

  group('habit states', () {
    test('missed days are counted and json-roundtrip', () {
      final h = Habit(id: 'm', name: 'x', createdDay: today - 5);
      h.missed.add(today - 1);
      h.missed.add(today - 2);
      final st = computeStats(h, ws, today);
      expect(st.missedDays, 2);
      final h2 = Habit.fromJson(h.toJson());
      expect(h2.missed.length, 2);
      expect(h2.why, '');
    });
  });

  group('misc models', () {
    test('quit habit durations', () {
      final q = QuitHabit(id: 'q', name: 'x', sinceMs: 0);
      expect(q.currentMs(86400000), 86400000);
      q.bestMs = 5 * 86400000;
      expect(q.longestMs(86400000), 5 * 86400000);
    });

    test('khatma total pages', () {
      final k = Khatma(startDay: today);
      k.pages[today] = 10;
      k.pages[today - 1] = 5;
      expect(k.total, 15);
      expect(Khatma.fromJson(k.toJson()).total, 15);
    });

    test('task json roundtrip keeps subs and parent', () {
      final t = Task(id: 't', title: 'ع', anchor: today, createdDay: today, parentId: 'p', quadrant: 2,
          subs: [SubTask('a', done: true)], repeat: 2, remind: 600);
      final t2 = Task.fromJson(t.toJson());
      expect(t2.parentId, 'p');
      expect(t2.quadrant, 2);
      expect(t2.subs.single.done, true);
      expect(t2.remind, 600);
    });

    test('settings json keeps vacations and pin', () {
      final s = Settings(pinHash: 'abc', vacations: [[1, 2]]);
      final s2 = Settings.fromJson(s.toJson());
      expect(s2.pinHash, 'abc');
      expect(s2.vacations.single, [1, 2]);
    });
  });
}
