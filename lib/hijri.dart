import 'util.dart';

const List<String> kHijriMonths = [
  'محرّم', 'صفر', 'ربيع الأول', 'ربيع الثاني', 'جمادى الأولى', 'جمادى الآخرة',
  'رجب', 'شعبان', 'رمضان', 'شوّال', 'ذو القعدة', 'ذو الحجة',
];

class HijriDate {
  final int y;
  final int m;
  final int d;
  const HijriDate(this.y, this.m, this.d);
}

/// تحويل حسابي (جدولي) من الميلادي إلى الهجري. قد يختلف يومًا واحدًا عن
/// الرؤية الرسمية، لذلك يوجد ضبط (+1/-1) في صفحة الصلاة.
HijriDate toHijri(int dayNum, int adjust) {
  final jd = dayNum + 2440588 + adjust;
  int l = jd - 1948440 + 10632;
  final n = (l - 1) ~/ 10631;
  l = l - 10631 * n + 354;
  final j = ((10985 - l) ~/ 5316) * ((50 * l) ~/ 17719) +
      (l ~/ 5670) * ((43 * l) ~/ 15238);
  l = l -
      ((30 - j) ~/ 15) * ((17719 * j) ~/ 50) -
      (j ~/ 16) * ((15238 * j) ~/ 43) +
      29;
  final m = (24 * l) ~/ 709;
  final d = l - (709 * m) ~/ 24;
  final y = 30 * n + j - 30;
  return HijriDate(y, m, d);
}

String hijriText(int day, int adjust) {
  final h = toHijri(day, adjust);
  final mi = clampI(h.m - 1, 0, 11);
  return '${h.d} ${kHijriMonths[mi]} ${h.y} هـ';
}
