import 'package:flutter/material.dart';
import 'habit_widgets.dart';
import 'models_ext.dart';
import 'notifications.dart';
import 'store.dart';
import 'ui_common.dart';
import 'util.dart';

Color medColor(Med m) => kHabitColors[m.colorIdx % kHabitColors.length];

/// نسبة أخذ الجرعات في آخر [days] يومًا (الجرعات التي حان وقتها فقط)
double adherenceOf(Med m, int today, int days) {
  final now = DateTime.now();
  final nowMin = now.hour * 60 + now.minute;
  int sched = 0;
  int taken = 0;
  for (int d = today - days + 1; d <= today; d++) {
    if (!m.activeOn(d)) continue;
    for (int i = 0; i < m.doses.length; i++) {
      if (d == today && m.doses[i] > nowMin) continue;
      sched++;
      if (m.state(d, i) == 1) taken++;
    }
  }
  return sched == 0 ? 0.0 : taken / sched;
}

class MedsScreen extends StatelessWidget {
  const MedsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final today = todayNum();
    final list = store.meds.where((m) => !m.archived).toList();
    final arch = store.meds.where((m) => m.archived).toList();
    final nowMin = DateTime.now().hour * 60 + DateTime.now().minute;

    return Scaffold(
      appBar: AppBar(title: const Text('💊 الأدوية والتذكيرات')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: kEmerald,
        foregroundColor: Colors.black,
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(fullscreenDialog: true, builder: (_) => const MedEditorPage()),
        ),
        icon: const Icon(Icons.add_rounded),
        label: const Text('دواء جديد', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 110),
        children: [
          if (list.isEmpty)
            const AppCard(
              child: Column(
                children: [
                  Text('💊', style: TextStyle(fontSize: 42)),
                  SizedBox(height: 8),
                  Text('أضف دواءً أو أي تذكير بجرعات متعددة في اليوم.\nتبقى الجرعات داخل صفحة كل دواء ولا تزاحم شاشتك الرئيسية.',
                      textAlign: TextAlign.center, style: TextStyle(color: kMuted, height: 1.7)),
                ],
              ),
            ),
          for (final m in list)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _MedCard(med: m, today: today, nowMin: nowMin),
            ),
          if (arch.isNotEmpty) ...[
            const SectionTitle('منتهية / مؤرشفة'),
            for (final m in arch)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AppCard(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  onTap: () => Navigator.of(context)
                      .push(MaterialPageRoute<void>(builder: (_) => MedDetailScreen(medId: m.id))),
                  child: Row(
                    children: [
                      Text(m.emoji, style: const TextStyle(fontSize: 22)),
                      const SizedBox(width: 10),
                      Expanded(child: Text(m.name, style: const TextStyle(color: kMuted, fontWeight: FontWeight.w700))),
                      TextButton(
                        onPressed: () {
                          m.archived = false;
                          store.save();
                        },
                        child: const Text('استعادة', style: TextStyle(color: kEmerald)),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _MedCard extends StatelessWidget {
  final Med med;
  final int today;
  final int nowMin;
  const _MedCard({required this.med, required this.today, required this.nowMin});

  @override
  Widget build(BuildContext context) {
    final color = medColor(med);
    final active = med.activeOn(today);
    int taken = 0;
    int skipped = 0;
    for (int i = 0; i < med.doses.length; i++) {
      final s = med.state(today, i);
      if (s == 1) taken++;
      if (s == 2) skipped++;
    }
    int? nextIdx;
    for (int i = 0; i < med.doses.length; i++) {
      if (med.state(today, i) == 0) {
        nextIdx = i;
        break;
      }
    }
    final left = med.daysLeft();
    final low = left >= 0 && left <= 3;

    String sub;
    if (!active) {
      sub = med.startDay > today ? 'يبدأ ${fmtShort(med.startDay)}' : 'انتهى العلاج';
    } else if (nextIdx == null) {
      sub = 'اكتملت جرعات اليوم ✓';
    } else {
      sub = 'التالية ${fmtClock(med.doses[nextIdx])}';
    }

    return AppCard(
      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => MedDetailScreen(medId: med.id))),
      borderColor: low ? a(kDanger, 0.55) : kLine,
      child: Row(
        children: [
          EmojiBadge(emoji: med.emoji, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(med.name,
                    style: const TextStyle(color: kText, fontSize: 16.5, fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(sub, style: TextStyle(color: nextIdx == null && active ? color : kMuted, fontSize: 12.5)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    MiniChip('$taken / ${med.doses.length} اليوم', color: color),
                    if (skipped > 0) MiniChip('تخطّي $skipped', color: kGold),
                    if (low) MiniChip('المخزون ${left.floor()} يوم', color: kDanger),
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_left_rounded, color: kMuted),
        ],
      ),
    );
  }
}

// ═════════════════════════ صفحة الدواء ═════════════════════════

class MedDetailScreen extends StatefulWidget {
  final String medId;
  const MedDetailScreen({super.key, required this.medId});

  @override
  State<MedDetailScreen> createState() => _MedDetailScreenState();
}

class _MedDetailScreenState extends State<MedDetailScreen> {
  int? picked;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final m = store.medById(widget.medId);
    if (m == null) {
      return const Scaffold(body: Center(child: Text('الدواء غير موجود')));
    }
    final today = todayNum();
    final day = picked ?? today;
    final color = medColor(m);
    final nowMin = DateTime.now().hour * 60 + DateTime.now().minute;
    final left = m.daysLeft();
    final adh7 = adherenceOf(m, today, 7);
    final adh30 = adherenceOf(m, today, 30);

    // أيام العلاج المتبقية
    String courseText;
    double? courseProg;
    if (m.endDay == 0) {
      courseText = 'علاج مفتوح منذ ${fmtShort(m.startDay)}';
    } else {
      final totalDays = m.endDay - m.startDay + 1;
      final elapsed = clampI(today - m.startDay + 1, 0, totalDays);
      final remain = m.endDay - today;
      courseText = today > m.endDay
          ? 'انتهى العلاج في ${fmtShort(m.endDay)}'
          : 'اليوم ${elapsed > 0 ? elapsed : 0} من $totalDays • يتبقّى $remain يوم';
      courseProg = totalDays <= 0 ? 0.0 : elapsed / totalDays;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${m.emoji} ${m.name}'),
        actions: [
          PopupMenuButton<String>(
            color: kCard2,
            onSelected: (v) async {
              if (v == 'edit') {
                Navigator.of(context).push(MaterialPageRoute<void>(
                    fullscreenDialog: true, builder: (_) => MedEditorPage(med: m)));
              } else if (v == 'archive') {
                m.archived = !m.archived;
                store.save();
                if (context.mounted) Navigator.of(context).pop();
              } else if (v == 'delete') {
                final ok = await confirmDialog(context, 'حذف الدواء؟', 'سيُحذف سجل جرعاته نهائيًا.',
                    ok: 'حذف', danger: true);
                if (ok && context.mounted) {
                  store.deleteMed(m);
                  Navigator.of(context).pop();
                }
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Text('تعديل')),
              PopupMenuItem(value: 'archive', child: Text(m.archived ? 'استعادة' : 'أرشفة / إنهاء')),
              const PopupMenuItem(value: 'delete', child: Text('حذف', style: TextStyle(color: kDanger))),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 60),
        children: [
          // ── اختيار اليوم
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => setState(() => picked = day - 1),
                  icon: const Icon(Icons.chevron_right_rounded, color: kText),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: picked == null ? null : () => setState(() => picked = null),
                    child: Text(
                      day == today ? 'اليوم • ${fmtShort(day)}' : '${kWeekdaysAr[weekdayOf(day) - 1]} ${fmtShort(day)}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: kText, fontSize: 15.5, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: day >= today ? null : () => setState(() => picked = day + 1 >= today ? null : day + 1),
                  icon: Icon(Icons.chevron_left_rounded, color: day >= today ? kLine : kText),
                ),
              ],
            ),
          ),

          // ── الجرعات
          SectionTitle('الجرعات', trailing: Text('${num1(m.amount)} ${m.unit} لكل جرعة', style: const TextStyle(color: kMuted, fontSize: 12))),
          if (!m.activeOn(day))
            const AppCard(
              child: Text('هذا اليوم خارج مدة العلاج.', style: TextStyle(color: kMuted)),
            )
          else
            for (int i = 0; i < m.doses.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _DoseRow(med: m, day: day, idx: i, color: color, nowMin: nowMin, today: today),
              ),

          // ── المخزون
          const SectionTitle('المخزون'),
          AppCard(
            child: m.stock < 0
                ? Row(
                    children: [
                      const Expanded(
                        child: Text('لا يتم تتبّع المخزون لهذا الدواء.', style: TextStyle(color: kMuted)),
                      ),
                      TextButton(
                        onPressed: () async {
                          final v = await askNumber(context, title: 'كم ${m.unit} لديك الآن؟', initial: 0, suffix: m.unit);
                          if (v != null && v > 0) {
                            m.stock = v;
                            store.save();
                          }
                        },
                        child: const Text('ابدأ التتبّع', style: TextStyle(color: kEmerald)),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      Row(
                        children: [
                          Text('${num1(m.stock)} ${m.unit}',
                              style: TextStyle(
                                  color: left <= 3 ? kDanger : kText, fontSize: 24, fontWeight: FontWeight.w900)),
                          const Spacer(),
                          Text(left < 1 ? 'لا يكفي ليوم كامل' : 'يكفي ≈ ${left.floor()} يومًا',
                              style: TextStyle(color: left <= 3 ? kDanger : kMuted, fontSize: 13)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final v = await askNumber(context,
                                    title: 'كم ${m.unit} أضفت؟', initial: 0, suffix: m.unit);
                                if (v != null && v > 0) {
                                  m.stock += v;
                                  store.save();
                                }
                              },
                              icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
                              label: const Text('أضفت علبة'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            onPressed: () async {
                              final v = await askNumber(context,
                                  title: 'اضبط المخزون الحالي', initial: m.stock, suffix: m.unit);
                              if (v != null) {
                                m.stock = v < 0 ? 0 : v;
                                store.save();
                              }
                            },
                            child: const Text('ضبط'),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),

          // ── مدة العلاج والالتزام
          const SectionTitle('مدة العلاج'),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(courseText, style: const TextStyle(color: kText, fontSize: 14)),
                if (courseProg != null) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: courseProg,
                      minHeight: 7,
                      backgroundColor: a(color, 0.14),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SectionTitle('الالتزام بالجرعات'),
          TwoColumn(children: [
            StatTile(emoji: '📅', label: 'آخر 7 أيام', value: '${(adh7 * 100).round()}%', color: color),
            StatTile(emoji: '🗓️', label: 'آخر 30 يومًا', value: '${(adh30 * 100).round()}%'),
          ]),
          if (m.notes.isNotEmpty) ...[
            const SectionTitle('ملاحظات'),
            AppCard(child: Text(m.notes, style: const TextStyle(color: kText, height: 1.6))),
          ],
        ],
      ),
    );
  }
}

class _DoseRow extends StatelessWidget {
  final Med med;
  final int day;
  final int idx;
  final Color color;
  final int nowMin;
  final int today;
  const _DoseRow({
    required this.med,
    required this.day,
    required this.idx,
    required this.color,
    required this.nowMin,
    required this.today,
  });

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final s = med.state(day, idx);
    final minutes = med.doses[idx];
    final isToday = day == today;
    final due = isToday && s == 0 && minutes <= nowMin;
    final isLate = isToday && s == 0 && minutes + 60 <= nowMin;
    final bc = s == 1 ? color : (s == 2 ? kGold : (isLate ? kDanger : kLine));

    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      borderColor: bc,
      child: Column(
        children: [
          Row(
            children: [
              Text(fmtClock(minutes),
                  textDirection: TextDirection.ltr,
                  style: TextStyle(color: s == 0 ? kText : kMuted, fontSize: 24, fontWeight: FontWeight.w900)),
              const SizedBox(width: 10),
              Text('جرعة ${idx + 1}', style: const TextStyle(color: kMuted, fontSize: 12.5)),
              const Spacer(),
              if (s == 1) const MiniChip('أُخذت ✓', color: kEmerald),
              if (s == 2) const MiniChip('تخطّيتها', color: kGold),
              if (s == 0 && isLate) const MiniChip('متأخرة', color: kDanger),
              if (s == 0 && !isLate && due) const MiniChip('حان وقتها', color: kGold),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: s == 1 ? color : a(color, 0.16),
                    foregroundColor: s == 1 ? Colors.black : color,
                  ),
                  onPressed: () => store.setDose(med, day, idx, s == 1 ? 0 : 1),
                  child: Text(s == 1 ? 'تراجع' : 'أخذتها'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => store.setDose(med, day, idx, s == 2 ? 0 : 2),
                  child: Text(s == 2 ? 'تراجع' : 'تخطّيتها'),
                ),
              ),
              if (isToday && s == 0) ...[
                const SizedBox(width: 8),
                IconButton.outlined(
                  tooltip: 'أجّل ${med.snoozeMin} د',
                  onPressed: () async {
                    await NotificationService.requestPermission();
                    await NotificationService.snoozeIn(
                      '💊 ${med.name}',
                      'جرعة ${fmtClock(minutes)} • ${num1(med.amount)} ${med.unit}',
                      med.snoozeMin,
                    );
                    if (context.mounted) toast(context, 'سأذكّرك بعد ${med.snoozeMin} دقيقة');
                  },
                  icon: const Icon(Icons.snooze_rounded, size: 20),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════ محرّر الدواء ═════════════════════════

class MedEditorPage extends StatefulWidget {
  final Med? med;
  const MedEditorPage({super.key, this.med});

  @override
  State<MedEditorPage> createState() => _MedEditorPageState();
}

class _MedEditorPageState extends State<MedEditorPage> {
  final _name = TextEditingController();
  final _amount = TextEditingController(text: '1');
  final _unit = TextEditingController(text: 'حبة');
  final _stock = TextEditingController();
  final _days = TextEditingController();
  final _notes = TextEditingController();
  String emoji = '💊';
  int colorIdx = 2;
  List<int> doses = [480];
  int startDay = todayNum();
  bool openEnded = true;
  bool trackStock = false;
  int snooze = 10;

  bool get editing => widget.med != null;

  @override
  void initState() {
    super.initState();
    final m = widget.med;
    if (m != null) {
      _name.text = m.name;
      _amount.text = num1(m.amount);
      _unit.text = m.unit;
      emoji = m.emoji;
      colorIdx = m.colorIdx;
      doses = List<int>.from(m.doses);
      startDay = m.startDay;
      openEnded = m.endDay == 0;
      if (!openEnded) _days.text = '${m.endDay - m.startDay + 1}';
      trackStock = m.stock >= 0;
      if (trackStock) _stock.text = num1(m.stock);
      snooze = m.snoozeMin;
      _notes.text = m.notes;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _unit.dispose();
    _stock.dispose();
    _days.dispose();
    _notes.dispose();
    super.dispose();
  }

  double _num(TextEditingController c, double def) => double.tryParse(c.text.trim().replaceAll(',', '.')) ?? def;

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      toast(context, 'اكتب اسم الدواء');
      return;
    }
    if (doses.isEmpty) {
      toast(context, 'أضف جرعة واحدة على الأقل');
      return;
    }
    final amount = _num(_amount, 1);
    if (amount <= 0) {
      toast(context, 'كمية الجرعة يجب أن تكون أكبر من صفر');
      return;
    }
    int endDay = 0;
    if (!openEnded) {
      final n = _num(_days, 0).round();
      if (n <= 0) {
        toast(context, 'اكتب عدد أيام العلاج');
        return;
      }
      endDay = startDay + n - 1;
    }
    final stock = trackStock ? _num(_stock, 0) : -1.0;
    final sorted = List<int>.from(doses)..sort();
    final store = StoreScope.of(context);
    final unit = _unit.text.trim().isEmpty ? 'حبة' : _unit.text.trim();
    final m = widget.med;
    if (m != null) {
      m.name = name;
      m.emoji = emoji;
      m.colorIdx = colorIdx;
      m.doses = sorted;
      m.amount = amount;
      m.unit = unit;
      m.startDay = startDay;
      m.endDay = endDay;
      m.stock = stock;
      m.snoozeMin = snooze;
      m.notes = _notes.text.trim();
      store.save();
    } else {
      store.addMed(Med(
        id: store.newId(),
        name: name,
        emoji: emoji,
        colorIdx: colorIdx,
        doses: sorted,
        amount: amount,
        unit: unit,
        startDay: startDay,
        endDay: endDay,
        stock: stock,
        snoozeMin: snooze,
        notes: _notes.text.trim(),
      ));
    }
    requestNotifPermissionLater();
    Navigator.of(context).pop();
  }

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: kMuted),
        filled: true,
        fillColor: kCard,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: kLine)),
        enabledBorder:
            OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: kLine)),
      );

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 18, 2, 8),
        child: Text(t, style: const TextStyle(color: kMuted, fontSize: 13, fontWeight: FontWeight.w700)),
      );

  Future<void> _pickTime(int index) async {
    final cur = index >= 0 ? doses[index] : 480;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: cur ~/ 60, minute: cur % 60));
    if (t == null) return;
    final v = t.hour * 60 + t.minute;
    setState(() {
      if (index >= 0) {
        doses[index] = v;
      } else if (!doses.contains(v)) {
        doses.add(v);
      }
      doses.sort();
    });
  }

  @override
  Widget build(BuildContext context) {
    final color = kHabitColors[colorIdx % kHabitColors.length];
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'تعديل الدواء' : 'دواء جديد'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('حفظ', style: TextStyle(color: kEmerald, fontSize: 16, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
        children: [
          _label('الاسم'),
          TextField(
            controller: _name,
            autofocus: !editing,
            style: const TextStyle(color: kText, fontSize: 17),
            decoration: _dec('مثال: دواء x، فيتامين د'),
          ),
          _label('الرمز واللون'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in const ['💊', '💉', '🧴', '💧', '🩹', '👁️', '🦷', '🌿', '⏰', '🩺'])
                GestureDetector(
                  onTap: () => setState(() => emoji = e),
                  child: Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: e == emoji ? a(color, 0.2) : kCard,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: e == emoji ? color : kLine),
                    ),
                    child: Text(e, style: const TextStyle(fontSize: 21)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (int i = 0; i < kHabitColors.length; i++)
                GestureDetector(
                  onTap: () => setState(() => colorIdx = i),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: kHabitColors[i],
                      shape: BoxShape.circle,
                      border: Border.all(color: i == colorIdx ? Colors.white : Colors.transparent, width: 2.2),
                    ),
                  ),
                ),
            ],
          ),
          _label('الجرعة الواحدة'),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _amount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: kText, fontSize: 17),
                  decoration: _dec('الكمية'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _unit,
                  style: const TextStyle(color: kText, fontSize: 17),
                  decoration: _dec('الوحدة (حبة، مل...)'),
                ),
              ),
            ],
          ),
          _label('أوقات الجرعات في اليوم'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (int i = 0; i < doses.length; i++)
                InputChip(
                  label: Text(fmtClock(doses[i]), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                  onPressed: () => _pickTime(i),
                  onDeleted: doses.length > 1 ? () => setState(() => doses.removeAt(i)) : null,
                ),
              ActionChip(
                avatar: const Icon(Icons.add_rounded, size: 18),
                label: const Text('جرعة'),
                onPressed: () => _pickTime(-1),
              ),
            ],
          ),
          _label('بداية العلاج'),
          OutlinedButton.icon(
            onPressed: () async {
              final d = dateOf(startDay);
              final p = await showDatePicker(
                context: context,
                initialDate: DateTime(d.year, d.month, d.day),
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (p != null) setState(() => startDay = dayOf(p));
            },
            icon: const Icon(Icons.event_rounded),
            label: Text(fmtDay(startDay)),
          ),
          const SizedBox(height: 6),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeColor: kEmerald,
            title: const Text('علاج مفتوح (بدون نهاية)', style: TextStyle(color: kText)),
            value: openEnded,
            onChanged: (v) => setState(() => openEnded = v),
          ),
          if (!openEnded)
            TextField(
              controller: _days,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: kText, fontSize: 17),
              decoration: _dec('مدة العلاج بالأيام (مثال: 7)'),
            ),
          const SizedBox(height: 6),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeColor: kEmerald,
            title: const Text('تتبّع المخزون', style: TextStyle(color: kText)),
            subtitle: const Text('يُخصم تلقائيًا عند كل جرعة، وينبّهك قبل نفاده',
                style: TextStyle(color: kMuted, fontSize: 12)),
            value: trackStock,
            onChanged: (v) => setState(() => trackStock = v),
          ),
          if (trackStock)
            TextField(
              controller: _stock,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: kText, fontSize: 17),
              decoration: _dec('كم لديك الآن؟'),
            ),
          _label('مدّة التأجيل من الإشعار (دقيقة)'),
          Wrap(
            spacing: 8,
            children: [
              for (final m in const [5, 10, 15, 30])
                ChoiceChip(label: Text('$m'), selected: snooze == m, onSelected: (_) => setState(() => snooze = m)),
            ],
          ),
          _label('ملاحظات (قبل/بعد الأكل...)'),
          TextField(
            controller: _notes,
            maxLines: 2,
            style: const TextStyle(color: kText),
            decoration: _dec('اختياري'),
          ),
          const SizedBox(height: 26),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            ),
            onPressed: _save,
            child: Text(editing ? 'حفظ التعديلات' : 'إضافة الدواء',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}
