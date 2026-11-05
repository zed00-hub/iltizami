import 'dart:math' as math;
import 'util.dart';

class Wilaya {
  final String name;
  final double lat;
  final double lng;
  const Wilaya(this.name, this.lat, this.lng);
}

/// الولايات الـ58 (الفهرس = رقم الولاية - 1)
const List<Wilaya> kWilayas = [
  Wilaya('أدرار', 27.87, -0.29),
  Wilaya('الشلف', 36.16, 1.33),
  Wilaya('الأغواط', 33.80, 2.88),
  Wilaya('أم البواقي', 35.88, 7.11),
  Wilaya('باتنة', 35.56, 6.17),
  Wilaya('بجاية', 36.75, 5.08),
  Wilaya('بسكرة', 34.85, 5.73),
  Wilaya('بشار', 31.62, -2.22),
  Wilaya('البليدة', 36.47, 2.83),
  Wilaya('البويرة', 36.37, 3.90),
  Wilaya('تمنراست', 22.79, 5.52),
  Wilaya('تبسة', 35.40, 8.12),
  Wilaya('تلمسان', 34.88, -1.32),
  Wilaya('تيارت', 35.37, 1.32),
  Wilaya('تيزي وزو', 36.71, 4.05),
  Wilaya('الجزائر العاصمة', 36.75, 3.06),
  Wilaya('الجلفة', 34.67, 3.26),
  Wilaya('جيجل', 36.82, 5.77),
  Wilaya('سطيف', 36.19, 5.41),
  Wilaya('سعيدة', 34.83, 0.15),
  Wilaya('سكيكدة', 36.88, 6.91),
  Wilaya('سيدي بلعباس', 35.19, -0.63),
  Wilaya('عنابة', 36.90, 7.77),
  Wilaya('قالمة', 36.46, 7.43),
  Wilaya('قسنطينة', 36.37, 6.61),
  Wilaya('المدية', 36.27, 2.75),
  Wilaya('مستغانم', 35.93, 0.09),
  Wilaya('المسيلة', 35.70, 4.54),
  Wilaya('معسكر', 35.40, 0.14),
  Wilaya('ورقلة', 31.95, 5.32),
  Wilaya('وهران', 35.70, -0.63),
  Wilaya('البيض', 33.68, 1.02),
  Wilaya('إليزي', 26.51, 8.48),
  Wilaya('برج بوعريريج', 36.07, 4.76),
  Wilaya('بومرداس', 36.76, 3.48),
  Wilaya('الطارف', 36.77, 8.31),
  Wilaya('تندوف', 27.67, -8.15),
  Wilaya('تيسمسيلت', 35.61, 1.81),
  Wilaya('الوادي', 33.37, 6.86),
  Wilaya('خنشلة', 35.43, 7.14),
  Wilaya('سوق أهراس', 36.29, 7.95),
  Wilaya('تيبازة', 36.59, 2.45),
  Wilaya('ميلة', 36.45, 6.26),
  Wilaya('عين الدفلى', 36.26, 1.97),
  Wilaya('النعامة', 33.27, -0.31),
  Wilaya('عين تموشنت', 35.30, -1.14),
  Wilaya('غرداية', 32.49, 3.67),
  Wilaya('غليزان', 35.74, 0.56),
  Wilaya('تيميمون', 29.26, 0.23),
  Wilaya('برج باجي مختار', 21.33, 0.95),
  Wilaya('أولاد جلال', 34.43, 5.07),
  Wilaya('بني عباس', 30.13, -2.17),
  Wilaya('عين صالح', 27.20, 2.48),
  Wilaya('عين قزام', 19.57, 5.77),
  Wilaya('تقرت', 33.10, 6.06),
  Wilaya('جانت', 24.55, 9.48),
  Wilaya('المغير', 33.95, 5.92),
  Wilaya('المنيعة', 30.58, 2.88),
];

/// أوقات يوم واحد بالساعات العشرية (توقيت الجزائر UTC+1 ثابت)
class DayPrayers {
  final double fajr;
  final double sunrise;
  final double dhuhr;
  final double asr;
  final double maghrib;
  final double isha;
  const DayPrayers(this.fajr, this.sunrise, this.dhuhr, this.asr, this.maghrib, this.isha);

  /// 0 فجر، 1 ظهر، 2 عصر، 3 مغرب، 4 عشاء
  double byIndex(int i) {
    switch (i) {
      case 0:
        return fajr;
      case 1:
        return dhuhr;
      case 2:
        return asr;
      case 3:
        return maghrib;
      default:
        return isha;
    }
  }
}

double _rad(double d) => d * math.pi / 180.0;
double _deg(double r) => r * 180.0 / math.pi;
double _fixAngle(double v) => v - 360.0 * (v / 360.0).floorToDouble();
double _fixHour(double v) => v - 24.0 * (v / 24.0).floorToDouble();

double _julian(int year, int month, int day) {
  int y = year;
  int m = month;
  if (m <= 2) {
    y -= 1;
    m += 12;
  }
  final aa = (y / 100).floor();
  final bb = 2 - aa + (aa / 4).floor();
  return (365.25 * (y + 4716)).floor() + (30.6001 * (m + 1)).floor() + day + bb - 1524.5;
}

/// [declination, equationOfTime]
List<double> _sunPos(double jd) {
  final d = jd - 2451545.0;
  final g = _fixAngle(357.529 + 0.98560028 * d);
  final q = _fixAngle(280.459 + 0.98564736 * d);
  final l = _fixAngle(q + 1.915 * math.sin(_rad(g)) + 0.020 * math.sin(_rad(2 * g)));
  final e = 23.439 - 0.00000036 * d;
  final ra = _deg(math.atan2(math.cos(_rad(e)) * math.sin(_rad(l)), math.cos(_rad(l)))) / 15.0;
  final eqt = q / 15.0 - _fixHour(ra);
  final decl = _deg(math.asin(math.sin(_rad(e)) * math.sin(_rad(l))));
  return [decl, eqt];
}

const double _tz = 1.0; // الجزائر UTC+1 بدون توقيت صيفي

/// حساب الأوقات: الفجر 18° والعشاء 17° (طريقة وزارة الشؤون الدينية الجزائرية)،
/// والعصر بالمذهب المالكي (ظل = 1). الدقة تقريبية ± دقيقة أو دقيقتين.
DayPrayers prayersFor(int dayNum, Wilaya w) {
  final dt = dateOf(dayNum);
  final jd = _julian(dt.year, dt.month, dt.day) - w.lng / (15.0 * 24.0);
  final lat = w.lat;

  double midDay(double t) => _fixHour(12.0 - _sunPos(jd + t)[1]);

  double sunAngleTime(double angle, double t, bool ccw) {
    final decl = _sunPos(jd + t)[0];
    final noon = midDay(t);
    double term = (-math.sin(_rad(angle)) - math.sin(_rad(decl)) * math.sin(_rad(lat))) /
        (math.cos(_rad(decl)) * math.cos(_rad(lat)));
    if (term > 1) term = 1;
    if (term < -1) term = -1;
    return noon + (ccw ? -1.0 : 1.0) * _deg(math.acos(term)) / 15.0;
  }

  double asrTime(double t) {
    final decl = _sunPos(jd + t)[0];
    final x = 1.0 + math.tan(_rad((lat - decl).abs()));
    final angle = -_deg(math.atan(1.0 / x));
    return sunAngleTime(angle, t, false);
  }

  double fajr = 5, sunrise = 6, dhuhr = 12, asr = 13, sunset = 18, isha = 18;
  for (int i = 0; i < 2; i++) {
    final tFajr = fajr / 24, tSunrise = sunrise / 24, tDhuhr = dhuhr / 24;
    final tAsr = asr / 24, tSunset = sunset / 24, tIsha = isha / 24;
    fajr = sunAngleTime(18.0, tFajr, true);
    sunrise = sunAngleTime(0.833, tSunrise, true);
    dhuhr = midDay(tDhuhr);
    asr = asrTime(tAsr);
    sunset = sunAngleTime(0.833, tSunset, false);
    isha = sunAngleTime(17.0, tIsha, false);
  }
  final shift = _tz - w.lng / 15.0;
  return DayPrayers(
    _fixHour(fajr + shift),
    _fixHour(sunrise + shift),
    _fixHour(dhuhr + shift),
    _fixHour(asr + shift),
    _fixHour(sunset + shift),
    _fixHour(isha + shift),
  );
}

/// الساعة العشرية -> دقائق اليوم (تقريب لأقرب دقيقة)
int toMinutes(double h) => (h * 60).round();

String fmtHour(double h) => fmtClock(toMinutes(h));
