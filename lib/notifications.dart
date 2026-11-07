import 'dart:async';
import 'dart:ui';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'models.dart';
import 'models_ext.dart';
import 'planning.dart';
import 'prayer.dart';
import 'stats.dart';
import 'store.dart';
import 'util.dart';

void requestNotifPermissionLater() {
  NotificationService.requestPermission();
}

/// المعرّفات >= 700000 محفوظة (جلسة التركيز + التأجيل) ولا تُمسح عند إعادة الجدولة
const int _focusId = 700001;

/// تعمل في معالج خلفي عند الضغط على زر "أجّل" داخل الإشعار.
/// الحمولة: "دقائق|العنوان|النص"
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse r) async {
  if (r.actionId != 'snooze') return;
  try {
    DartPluginRegistrant.ensureInitialized();
    tzdata.initializeTimeZones();
    final loc = tz.getLocation('Africa/Algiers');
    tz.setLocalLocation(loc);
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(
      const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
    );
    final parts = (r.payload ?? '').split('|');
    final mins = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 10;
    final title = parts.length > 1 ? parts[1] : 'التزام';
    final body = parts.length > 2 ? parts.sublist(2).join('|') : '';
    final when = tz.TZDateTime.now(loc).add(Duration(minutes: mins));
    final id = 800000 + (DateTime.now().millisecondsSinceEpoch % 100000);
    await plugin.zonedSchedule(
      id,
      title,
      body,
      when,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'iltizam_snooze',
          'تذكير مؤجّل',
          channelDescription: 'تذكيرات تم تأجيلها',
          importance: Importance.high,
          priority: Priority.high,
          actions: [AndroidNotificationAction('snooze', 'أجّل $mins د')],
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: r.payload,
    );
  } catch (_) {}
}

/// إشعارات محلية مجدولة (بدون إنترنت). تُعاد الجدولة عند كل تغيير أو فتح للتطبيق.
/// الأولوية عند ازدحام الحدّ: الأدوية ثم المهام ثم المراجعة ثم العادات ثم الصلاة.
class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;
  static Timer? _debounce;
  static const int _maxScheduled = 420;

  static Future<void> init() async {
    try {
      tzdata.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Africa/Algiers'));
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      await _plugin.initialize(
        const InitializationSettings(android: android),
        onDidReceiveNotificationResponse: (r) {},
        onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
      );
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  static Future<bool> requestPermission() async {
    if (!_ready) return false;
    try {
      final impl = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      final ok = await impl?.requestNotificationsPermission();
      return ok ?? true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> test() async {
    if (!_ready) return;
    try {
      await _plugin.show(
        999999,
        'التزام 🔥',
        'الإشعارات تعمل بنجاح. استمر يا بطل!',
        NotificationDetails(android: _details('iltizam_habits', 'تذكير العادات', 10, false)),
      );
    } catch (_) {}
  }

  static AndroidNotificationDetails _details(String channel, String name, int snoozeMin, bool snooze) {
    return AndroidNotificationDetails(
      channel,
      name,
      channelDescription: name,
      importance: Importance.high,
      priority: Priority.high,
      actions: snooze ? [AndroidNotificationAction('snooze', 'أجّل $snoozeMin د')] : null,
    );
  }

  static Future<void> scheduleFocus(DateTime when, String title, String body) async {
    if (!_ready) return;
    try {
      final loc = tz.getLocation('Africa/Algiers');
      await _plugin.zonedSchedule(
        _focusId,
        title,
        body,
        tz.TZDateTime.from(when, loc),
        NotificationDetails(android: _details('iltizam_focus', 'مؤقت التركيز', 10, false)),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (_) {}
  }

  /// تأجيل يدوي من داخل التطبيق: إشعار واحد بعد عدد دقائق
  static Future<void> snoozeIn(String title, String body, int minutes) async {
    if (!_ready) return;
    try {
      final loc = tz.getLocation('Africa/Algiers');
      final when = tz.TZDateTime.now(loc).add(Duration(minutes: minutes));
      final id = 800000 + (DateTime.now().millisecondsSinceEpoch % 100000);
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        when,
        NotificationDetails(android: _details('iltizam_snooze', 'تذكير مؤجّل', minutes, true)),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: '$minutes|$title|$body',
      );
    } catch (_) {}
  }

  static Future<void> cancelFocus() async {
    if (!_ready) return;
    try {
      await _plugin.cancel(_focusId);
    } catch (_) {}
  }

  static void scheduleSoon(AppStore store) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 900), () {
      _reschedule(store);
    });
  }

  static Future<void> _schedule(int id, tz.TZDateTime when, String title, String body,
      AndroidNotificationDetails d, {String? payload}) async {
    final details = NotificationDetails(android: d);
    try {
      await _plugin.zonedSchedule(id, title, body, when, details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle, payload: payload);
    } catch (_) {
      try {
        await _plugin.zonedSchedule(id, title, body, when, details,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle, payload: payload);
      } catch (_) {}
    }
  }

  static Future<void> _reschedule(AppStore store) async {
    if (!_ready) return;
    try {
      final pending = await _plugin.pendingNotificationRequests();
      for (final p in pending) {
        if (p.id < 700000) await _plugin.cancel(p.id);
      }
    } catch (_) {
      return;
    }
    try {
      final loc = tz.getLocation('Africa/Algiers');
      final now = tz.TZDateTime.now(loc);
      final today = dayOf(DateTime(now.year, now.month, now.day));
      final settings = store.settings;
      final wilaya = kWilayas[clampI(settings.wilaya, 0, kWilayas.length - 1)];
      int id = 1;

      tz.TZDateTime at(int day, int minutes) {
        final dt = dateOf(day);
        return tz.TZDateTime(loc, dt.year, dt.month, dt.day, minutes ~/ 60, minutes % 60);
      }

      // ── 1) الأدوية (أعلى أولوية)
      for (final m in store.meds) {
        if (m.archived) continue;
        for (int off = 0; off < 7 && id < _maxScheduled; off++) {
          final day = today + off;
          if (!m.activeOn(day)) continue;
          for (int i = 0; i < m.doses.length && id < _maxScheduled; i++) {
            if (m.state(day, i) != 0) continue;
            final when = at(day, m.doses[i]);
            if (!when.isAfter(now)) continue;
            final amount = num1(m.amount);
            final title = '💊 ${m.name}';
            final body = 'الجرعة ${i + 1} من ${m.doses.length} • $amount ${m.unit}';
            await _schedule(id++, when, title, body, _details('iltizam_meds', 'تذكير الأدوية', m.snoozeMin, true),
                payload: '${m.snoozeMin}|$title|$body');
          }
        }
        final left = m.daysLeft();
        if (left >= 0 && left <= 3 && id < _maxScheduled) {
          var when = at(today, 9 * 60);
          if (!when.isAfter(now)) when = at(today + 1, 9 * 60);
          final n = left.floor();
          await _schedule(id++, when, '⚠️ مخزون ${m.name} يوشك أن ينفد',
              n <= 0 ? 'لا يكفي لجرعة كاملة. اشترِ غيره.' : 'يكفي حوالي $n يوم فقط.',
              _details('iltizam_meds', 'تذكير الأدوية', m.snoozeMin, false));
        }
      }

      // ── 2) مهام يومية بتذكير
      for (final t in store.tasks) {
        if (t.level != PeriodType.day || t.remind < 0 || taskIsDone(t, store.tasks)) continue;
        if (t.anchor < today || t.anchor > today + 6 || id >= _maxScheduled) continue;
        final when = at(t.anchor, t.remind);
        if (!when.isAfter(now)) continue;
        await _schedule(id++, when, '📌 مهمة اليوم', t.title,
            _details('iltizam_tasks', 'تذكير المهام', 10, true),
            payload: '10|📌 مهمة|${t.title}');
      }

      // ── 3) المراجعة الأسبوعية (الجمعة 8 مساءً)
      if (settings.weekReview) {
        int count = 0;
        for (int off = 0; off < 14 && count < 2 && id < _maxScheduled; off++) {
          final day = today + off;
          if (weekdayOf(day) != 5) continue;
          final when = at(day, 20 * 60);
          if (!when.isAfter(now)) continue;
          await _schedule(id++, when, '🗓️ مراجعتك الأسبوعية جاهزة', 'لخّص أسبوعك وخطّط للقادم.',
              _details('iltizam_review', 'المراجعة الأسبوعية', 10, false));
          count++;
        }
      }

      // ── 4) العادات: التذكير وحماية السلسلة
      for (final h in store.habits) {
        if (h.archived) continue;
        final st = store.statsFor(h);
        final pc = PeriodCalc(h.period, settings.weekStart);
        final satisfiedToday = h.period == PeriodType.day ? st.periodMet : (st.periodMet || st.todayDone);
        final skipToday = satisfiedToday || h.missed.contains(today);
        final why = h.why.isEmpty ? '' : '\nلأن: ${h.why}';

        if (h.reminderKind != 0) {
          for (int off = 0; off < 10 && id < _maxScheduled; off++) {
            final day = today + off;
            if (off == 0 && skipToday) continue;
            if (store.isFrozen(day)) continue;
            if (off > 0 && st.periodMet && pc.keyOf(day) == pc.keyOf(today)) continue;
            int minutes;
            if (h.reminderKind == 1) {
              minutes = h.reminderMinutes;
            } else {
              minutes = toMinutes(prayersFor(day, wilaya).byIndex(h.reminderPrayer)) + h.reminderMinutes;
            }
            if (minutes < 0 || minutes >= 1440) continue;
            final when = at(day, minutes);
            if (!when.isAfter(now)) continue;
            await _schedule(id++, when, 'التزام 🔥', '${h.emoji} حان وقت: ${h.name}$why',
                _details('iltizam_habits', 'تذكير العادات', 10, true),
                payload: '10|التزام 🔥|${h.emoji} ${h.name}');
          }
        }

        if (settings.streakGuard && h.period == PeriodType.day && st.currentStreak >= 3) {
          for (int off = 0; off < 3 && id < _maxScheduled; off++) {
            if (off == 0 && skipToday) continue;
            if (store.isFrozen(today + off)) continue;
            final when = at(today + off, 21 * 60 + 30);
            if (!when.isAfter(now)) continue;
            final streakText = off == 0 ? '${st.currentStreak}' : '${st.currentStreak}+';
            await _schedule(id++, when, '⚠️ سلسلتك في خطر',
                '${h.emoji} ${h.name}: سلسلة $streakText يومًا. لا تكسرها اليوم!$why',
                _details('iltizam_habits', 'تذكير العادات', 10, false));
          }
        }
      }

      // ── 5) أوقات الصلاة
      if (settings.prayerNotif) {
        for (int off = 0; off < 7; off++) {
          final day = today + off;
          final p = prayersFor(day, wilaya);
          for (int i = 0; i < 5 && id < _maxScheduled + 40; i++) {
            final minutes = toMinutes(p.byIndex(i));
            final when = at(day, minutes);
            if (!when.isAfter(now)) continue;
            await _schedule(id++, when, 'حان وقت صلاة ${kPrayerNames[i]}', '${wilaya.name} • ${fmtClock(minutes)}',
                _details('iltizam_prayer', 'أوقات الصلاة', 10, false));
          }
        }
      }
    } catch (_) {}
  }
}
