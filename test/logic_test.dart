import 'package:flutter_test/flutter_test.dart';
import 'package:iltizam/hijri.dart';
import 'package:iltizam/models.dart';
import 'package:iltizam/prayer.dart';
import 'package:iltizam/stats.dart';
import 'package:iltizam/util.dart';

void main() {
  final today = dayOf(DateTime.utc(2026, 11, 5)); // الخميس
  const ws = 7; // الأسبوع يبدأ الأحد

  test('weekday mapping', () {
    expect(weekdayOf(today), 4); // الخميس
  });

  test('daily streak counts consecutive days', () {
    final h = Habit(id: 'a', name: 'فجر', createdDay: today - 10);
    for (final d in [today, today - 1, today - 2]) {
      h.log[d] = 1;
    }
    final st = computeStats(h, ws, today);
    expect(st.currentStreak, 3);
    expect(st.bestStreak, 3);
  });

  test('strict streak: a missed day resets it', () {
    final h = Habit(id: 'b', name: 'x', createdDay: today - 10);
    h.log[today - 1] = 1;
    h.log[today - 3] = 1;
    final st = computeStats(h, ws, today);
    expect(st.currentStreak, 1);
    expect(st.bestStreak, 1);
  });

  test('today not yet done does not break the streak', () {
    final h = Habit(id: 'c', name: 'x', createdDay: today - 10);
    for (final d in [today - 1, today - 2, today - 3]) {
      h.log[d] = 1;
    }
    final st = computeStats(h, ws, today);
    expect(st.currentStreak, 3);
  });

  test('weekly goal: 4 sessions per week, consecutive weeks', () {
    final h = Habit(
      id: 'd',
      name: 'رياضة',
      period: PeriodType.week,
      target: 4,
      createdDay: today - 30,
    );
    final curKey = today - ((weekdayOf(today) - ws + 7) % 7);
    for (final wk in [curKey - 7, curKey - 14]) {
      for (int i = 0; i < 4; i++) {
        h.log[wk + i] = 1;
      }
    }
    final st = computeStats(h, ws, today);
    expect(st.completedPeriods, 2);
    expect(st.bestStreak, 2);
    expect(st.currentStreak, 2);
    expect(st.periodMet, false);
  });

  test('habit strength is exponential and forgives one slip', () {
    final h = Habit(id: 'e', name: 'x', createdDay: today - 70);
    for (int d = today - 60; d <= today; d++) {
      h.log[d] = 1;
    }
    final full = computeStats(h, ws, today).strength;
    expect(full, greaterThan(0.9));
    h.log.remove(today - 5);
    final slip = computeStats(h, ws, today).strength;
    expect(slip, lessThan(full));
    expect(slip, greaterThan(0.8));
  });

  test('hijri conversion', () {
    final h = toHijri(dayOf(DateTime.utc(2025, 3, 1)), 0);
    expect(h.y, 1446);
    expect(h.m, 9);
    expect(h.d, 1);
  });

  test('prayer times for Algiers are plausible', () {
    final p = prayersFor(today, kWilayas[15]);
    expect((toMinutes(p.dhuhr) - (12 * 60 + 31)).abs(), lessThanOrEqualTo(3));
    expect((toMinutes(p.fajr) - (5 * 60 + 47)).abs(), lessThanOrEqualTo(4));
    expect(p.maghrib, greaterThan(p.asr));
    expect(p.isha, greaterThan(p.maghrib));
  });

  test('habit json roundtrip', () {
    final h = Habit(id: 'z', name: 'تجربة', createdDay: today, kind: HabitKind.count, target: 8);
    h.log[today] = 3;
    final h2 = Habit.fromJson(h.toJson());
    expect(h2.name, 'تجربة');
    expect(h2.kind, HabitKind.count);
    expect(h2.log[today], 3.0);
  });
}
