import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'models.dart';
import 'prayer.dart';
import 'stats.dart';
import 'store.dart';
import 'util.dart';

void requestNotifPermissionLater() {
  NotificationService.requestPermission();
}

/// إشعارات محلية مجدولة (بدون إنترنت). تُعاد الجدولة عند كل تغيير أو فتح للتطبيق:
/// تذكير العادات للأيام العشرة القادمة (مع تخطّي ما أُنجز)، وحماية السلسلة
/// الساعة 21:30، وأوقات الصلاة للأيام السبعة القادمة.
class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;
  static Timer? _debounce;
  static const int _maxScheduled = 400;

  static Future<void> init() async {
    try {
      tzdata.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Africa/Algiers'));
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      await _plugin.initialize(const InitializationSettings(android: android));
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  static Future<bool> requestPermission() async {
    if (!_ready) return false;
    try {
      final impl = _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
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
        NotificationDetails(android: _habitDetails()),
      );
    } catch (_) {}
  }

  static AndroidNotificationDetails _habitDetails() => const AndroidNotificationDetails(
        'iltizam_habits',
        'تذكير العادات',
        channelDescription: 'تذكيرات العادات وحماية السلسلة',
        importance: Importance.high,
        priority: Priority.high,
      );

  static AndroidNotificationDetails _prayerDetails() => const AndroidNotificationDetails(
        'iltizam_prayer',
        'أوقات الصلاة',
        channelDescription: 'تنبيه عند دخول وقت الصلاة',
        importance: Importance.high,
        priority: Priority.high,
      );

  static void scheduleSoon(AppStore store) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 900), () {
      _reschedule(store);
    });
  }

  static Future<void> _schedule(
      int id, tz.TZDateTime when, String title, String body, AndroidNotificationDetails d) async {
    final details = NotificationDetails(android: d);
    try {
      await _plugin.zonedSchedule(id, title, body, when, details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle);
    } catch (_) {
      try {
        await _plugin.zonedSchedule(id, title, body, when, details,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle);
      } catch (_) {}
    }
  }

  static Future<void> _reschedule(AppStore store) async {
    if (!_ready) return;
    try {
      await _plugin.cancelAll();
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

      for (final h in store.habits) {
        if (h.archived) continue;
        final st = computeStats(h, settings.weekStart, today);
        final pc = PeriodCalc(h.period, settings.weekStart);
        final satisfiedToday = h.period == PeriodType.day ? st.periodMet : (st.periodMet || st.todayDone);

        if (h.reminderKind != 0) {
          for (int off = 0; off < 10 && id < _maxScheduled; off++) {
            final day = today + off;
            if (off == 0 && satisfiedToday) continue;
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
            await _schedule(id++, when, 'التزام 🔥', '${h.emoji} حان وقت: ${h.name}', _habitDetails());
          }
        }

        if (settings.streakGuard &&
            h.period == PeriodType.day &&
            st.currentStreak >= 3) {
          for (int off = 0; off < 3 && id < _maxScheduled; off++) {
            if (off == 0 && satisfiedToday) continue;
            final when = at(today + off, 21 * 60 + 30);
            if (!when.isAfter(now)) continue;
            final streakText = off == 0 ? '${st.currentStreak}' : '${st.currentStreak}+';
            await _schedule(id++, when, '⚠️ سلسلتك في خطر',
                '${h.emoji} ${h.name}: سلسلة $streakText يومًا. لا تكسرها اليوم!', _habitDetails());
          }
        }
      }

      if (settings.prayerNotif) {
        for (int off = 0; off < 7; off++) {
          final day = today + off;
          final p = prayersFor(day, wilaya);
          for (int i = 0; i < 5 && id < _maxScheduled + 60; i++) {
            final minutes = toMinutes(p.byIndex(i));
            final when = at(day, minutes);
            if (!when.isAfter(now)) continue;
            await _schedule(id++, when, 'حان وقت صلاة ${kPrayerNames[i]}',
                '${wilaya.name} • ${fmtClock(minutes)}', _prayerDetails());
          }
        }
      }
    } catch (_) {}
  }
}
