import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'hijri.dart';
import 'notifications.dart';
import 'prayer.dart';
import 'store.dart';
import 'ui_common.dart';
import 'util.dart';

class PrayerScreen extends StatelessWidget {
  const PrayerScreen({super.key});

  Future<void> _pickWilaya(BuildContext context, AppStore store) async {
    final chosen = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: kSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.75,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(18),
                child: Text('اختر ولايتك',
                    style: TextStyle(color: kText, fontSize: 18, fontWeight: FontWeight.w800)),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: kWilayas.length,
                  itemBuilder: (_, i) => ListTile(
                    title: Text('${pad2(i + 1)} - ${kWilayas[i].name}',
                        style: TextStyle(
                            color: i == store.settings.wilaya ? kEmerald : kText,
                            fontWeight: i == store.settings.wilaya ? FontWeight.w800 : FontWeight.w500)),
                    onTap: () => Navigator.pop(ctx, i),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (chosen != null) {
      store.updateSettings((s) => s.wilaya = chosen);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final s = store.settings;
    final w = kWilayas[clampI(s.wilaya, 0, kWilayas.length - 1)];
    final today = todayNum();
    final p = prayersFor(today, w);

    final now = DateTime.now();
    final nowMin = now.hour * 60 + now.minute;
    int next = -1;
    for (int i = 0; i < 5; i++) {
      if (toMinutes(p.byIndex(i)) > nowMin) {
        next = i;
        break;
      }
    }
    String nextText;
    if (next >= 0) {
      final diff = toMinutes(p.byIndex(next)) - nowMin;
      nextText = 'صلاة ${kPrayerNames[next]} بعد ${diff ~/ 60 > 0 ? '${diff ~/ 60} س ' : ''}${diff % 60} د';
    } else {
      final t = prayersFor(today + 1, w);
      final diff = 1440 - nowMin + toMinutes(t.fajr);
      nextText = 'صلاة الفجر بعد ${diff ~/ 60} س ${diff % 60} د';
    }

    final rows = <List<String>>[
      ['الفجر', fmtHour(p.fajr)],
      ['الشروق', fmtHour(p.sunrise)],
      ['الظهر', fmtHour(p.dhuhr)],
      ['العصر', fmtHour(p.asr)],
      ['المغرب', fmtHour(p.maghrib)],
      ['العشاء', fmtHour(p.isha)],
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 110),
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 6, 4, 10),
          child: Text('الصلاة والتقويم', style: TextStyle(color: kText, fontSize: 26, fontWeight: FontWeight.w900)),
        ),
        AppCard(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [a(kGold, 0.2), kCard],
          ),
          borderColor: a(kGold, 0.4),
          child: Column(
            children: [
              Text(hijriText(today, s.hijriAdjust),
                  style: const TextStyle(color: kGold, fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text('${kWeekdaysAr[weekdayOf(today) - 1]} ${fmtDay(today)}',
                  style: const TextStyle(color: kText, fontSize: 14)),
              const SizedBox(height: 12),
              Text(nextText,
                  style: const TextStyle(color: kEmerald, fontSize: 15, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('ضبط التاريخ الهجري:', style: TextStyle(color: kMuted, fontSize: 12.5)),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () => store.updateSettings((x) => x.hijriAdjust = clampI(x.hijriAdjust - 1, -2, 2)),
                    icon: const Icon(Icons.remove_circle_outline, color: kMuted, size: 20),
                  ),
                  Text(s.hijriAdjust > 0 ? '+${s.hijriAdjust}' : '${s.hijriAdjust}',
                      style: const TextStyle(color: kText, fontWeight: FontWeight.w800)),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () => store.updateSettings((x) => x.hijriAdjust = clampI(x.hijriAdjust + 1, -2, 2)),
                    icon: const Icon(Icons.add_circle_outline, color: kMuted, size: 20),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        AppCard(
          onTap: () => _pickWilaya(context, store),
          child: Row(
            children: [
              const Icon(Icons.location_on_rounded, color: kEmerald),
              const SizedBox(width: 10),
              Expanded(
                child: Text('${pad2(s.wilaya + 1)} - ${w.name}',
                    style: const TextStyle(color: kText, fontSize: 16, fontWeight: FontWeight.w800)),
              ),
              const Text('تغيير', style: TextStyle(color: kEmerald, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
        const SectionTitle('صلواتي'),
        const PrayerTracker(),
        const SectionTitle('مواقيت اليوم'),
        for (int i = 0; i < rows.length; i++)
          Builder(builder: (context) {
            // الشروق ليس صلاة؛ نحسب الفهرس الفعلي للصلاة القادمة
            final prayerIdx = i == 0 ? 0 : (i == 1 ? -1 : i - 1);
            final isNext = prayerIdx == next && prayerIdx >= 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                borderColor: isNext ? kEmerald : kLine,
                child: Row(
                  children: [
                    Text(rows[i][0],
                        style: TextStyle(
                            color: prayerIdx == -1 ? kMuted : kText,
                            fontSize: 17,
                            fontWeight: FontWeight.w800)),
                    if (isNext)
                      const Padding(
                        padding: EdgeInsets.only(right: 10),
                        child: MiniNext(),
                      ),
                    const Spacer(),
                    Text(rows[i][1],
                        textDirection: TextDirection.ltr,
                        style: TextStyle(
                            color: isNext ? kEmerald : kText,
                            fontSize: 20,
                            fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
            );
          }),
        const SectionTitle('التنبيهات'),
        AppCard(
          child: Column(
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: kEmerald,
                title: const Text('تنبيه دخول وقت الصلاة', style: TextStyle(color: kText)),
                subtitle: const Text('إشعار عند كل أذان (محلي، بدون إنترنت)',
                    style: TextStyle(color: kMuted, fontSize: 12)),
                value: s.prayerNotif,
                onChanged: (v) async {
                  if (v) await NotificationService.requestPermission();
                  store.updateSettings((x) => x.prayerNotif = v);
                },
              ),
              const Divider(color: kLine),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () async {
                    await NotificationService.requestPermission();
                    await NotificationService.test();
                    if (context.mounted) toast(context, 'أُرسل إشعار تجريبي');
                  },
                  icon: const Icon(Icons.notifications_active_outlined, color: kGold),
                  label: const Text('إشعار تجريبي', style: TextStyle(color: kGold)),
                ),
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 14, 4, 0),
          child: Text(
            'الحساب بزاوية 18° للفجر و17° للعشاء والعصر بالمذهب المالكي، على إحداثيات مركز الولاية. '
            'الدقة تقريبية (± دقيقة أو دقيقتين)، فاعتمد على أذان المسجد عند الفرق.',
            style: TextStyle(color: kMuted, fontSize: 11.5, height: 1.6),
          ),
        ),
      ],
    );
  }
}

class MiniNext extends StatelessWidget {
  const MiniNext({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: a(kEmerald, 0.16),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Text('القادمة', style: TextStyle(color: kEmerald, fontSize: 11, fontWeight: FontWeight.w800)),
    );
  }
}


// ═════════════════════════ متابعة الصلوات الخمس ═════════════════════════

const List<String> kPrayStateName = ['لم تُحدَّد', 'في جماعة', 'منفردة', 'فاتت'];

class PrayerTracker extends StatefulWidget {
  const PrayerTracker({super.key});

  @override
  State<PrayerTracker> createState() => _PrayerTrackerState();
}

class _PrayerTrackerState extends State<PrayerTracker> {
  int day = todayNum();

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final today = todayNum();
    final w = kWilayas[clampI(store.settings.wilaya, 0, kWilayas.length - 1)];
    final times = prayersFor(day, w);
    final st = store.prayerState(day);

    // إحصائيات آخر 30 يومًا
    int loggedDays = 0;
    int fullDays = 0;
    int jama = 0;
    int logged = 0;
    final doneBy = List<int>.filled(5, 0);
    final seenBy = List<int>.filled(5, 0);
    for (int i = 0; i < 30; i++) {
      final s = store.prayerLog[today - i];
      if (s == null) continue;
      loggedDays++;
      bool full = true;
      for (int p = 0; p < 5; p++) {
        final c = s[p];
        if (c != '0') {
          logged++;
          seenBy[p]++;
        }
        if (c == '1') jama++;
        if (c == '1' || c == '2') {
          doneBy[p]++;
        } else {
          full = false;
        }
      }
      if (full) fullDays++;
    }
    // سلسلة الأيام الكاملة (اليوم غير المكتمل لا يكسرها)
    int streak = 0;
    for (int i = 0; i < 400; i++) {
      final s = store.prayerLog[today - i];
      final full = s != null && s.split('').every((c) => c == '1' || c == '2');
      if (full) {
        streak++;
      } else if (i == 0) {
        continue;
      } else {
        break;
      }
    }
    int weakest = -1;
    double weakRate = 2;
    for (int p = 0; p < 5; p++) {
      if (seenBy[p] < 3) continue;
      final r = doneBy[p] / seenBy[p];
      if (r < weakRate) {
        weakRate = r;
        weakest = p;
      }
    }

    Color stateColor(String c) {
      switch (c) {
        case '1':
          return kEmerald;
        case '2':
          return kGold;
        case '3':
          return kDanger;
        default:
          return kMuted;
      }
    }

    return Column(
      children: [
        AppCard(
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () => setState(() => day--),
                    icon: const Icon(Icons.chevron_right_rounded, color: kText),
                  ),
                  Expanded(
                    child: Text(day == today ? 'اليوم • ${fmtShort(day)}' : fmtDay(day),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: kText, fontWeight: FontWeight.w800)),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: day >= today ? null : () => setState(() => day++),
                    icon: Icon(Icons.chevron_left_rounded, color: day >= today ? kLine : kText),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              for (int i = 0; i < 5; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 64,
                        child: Text(kPrayerNames[i],
                            style: const TextStyle(color: kText, fontSize: 16, fontWeight: FontWeight.w800)),
                      ),
                      Text(fmtHour(times.byIndex(i)),
                          textDirection: TextDirection.ltr,
                          style: const TextStyle(color: kMuted, fontSize: 13)),
                      const Spacer(),
                      GestureDetector(
                        onTap: () {
                          if (day > today) return;
                          HapticFeedback.lightImpact();
                          store.cyclePrayer(day, i);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 108,
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: a(stateColor(st[i]), st[i] == '0' ? 0.0 : 0.16),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: stateColor(st[i]).withAlpha(st[i] == '0' ? 90 : 255)),
                          ),
                          child: Text(
                            st[i] == '1' ? '🕌 جماعة' : (st[i] == '2' ? 'منفردة' : (st[i] == '3' ? '✗ فاتت' : '—')),
                            style: TextStyle(
                                color: stateColor(st[i]), fontSize: 13.5, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 4),
              const Text('اضغط لتغيير الحالة: جماعة ← منفردة ← فاتت ← مسح',
                  style: TextStyle(color: kMuted, fontSize: 11)),
            ],
          ),
        ),
        const SizedBox(height: 10),
        TwoColumn(children: [
          StatTile(
            emoji: '🕌',
            label: 'في جماعة (30 يومًا)',
            value: logged == 0 ? '—' : '${(jama / logged * 100).round()}%',
            sub: logged == 0 ? 'سجّل صلواتك' : '$jama من $logged',
            color: kEmerald,
          ),
          StatTile(
            emoji: '🔥',
            label: 'أيام الخمس كاملة',
            value: '$streak',
            sub: 'متتالية • $fullDays من $loggedDays يومًا مسجّلًا',
            color: kGold,
          ),
          if (weakest >= 0)
            StatTile(
              emoji: '🎯',
              label: 'الأضعف محافظةً',
              value: kPrayerNames[weakest],
              sub: '${(weakRate * 100).round()}%',
              color: kDanger,
            ),
        ]),
      ],
    );
  }
}
