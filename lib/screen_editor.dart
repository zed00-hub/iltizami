import 'package:flutter/material.dart';
import 'models.dart';
import 'notifications.dart';
import 'store.dart';
import 'ui_common.dart';
import 'util.dart';

class HabitTemplate {
  final String name;
  final String emoji;
  final HabitKind kind;
  final PeriodType period;
  final double target;
  final String unit;
  final int color;
  final int reminderKind;
  final int reminderMinutes;
  final int reminderPrayer;
  const HabitTemplate(
    this.name,
    this.emoji,
    this.kind,
    this.period,
    this.target,
    this.unit,
    this.color, {
    this.reminderKind = 0,
    this.reminderMinutes = 480,
    this.reminderPrayer = 0,
  });
}

const List<HabitTemplate> kTemplates = [
  HabitTemplate('صلاة الفجر في المسجد', '🕌', HabitKind.check, PeriodType.day, 1, '', 0,
      reminderKind: 2, reminderMinutes: -20, reminderPrayer: 0),
  HabitTemplate('ورد القرآن', '📖', HabitKind.timer, PeriodType.day, 20, '', 1,
      reminderKind: 1, reminderMinutes: 1260),
  HabitTemplate('الرياضة', '🏋️', HabitKind.check, PeriodType.week, 4, '', 3),
  HabitTemplate('شرب الماء', '💧', HabitKind.count, PeriodType.day, 8, 'كوب', 2),
  HabitTemplate('المطالعة', '📚', HabitKind.timer, PeriodType.day, 30, '', 4,
      reminderKind: 1, reminderMinutes: 1320),
  HabitTemplate('أذكار الصباح', '🌅', HabitKind.check, PeriodType.day, 1, '', 1,
      reminderKind: 2, reminderMinutes: 15, reminderPrayer: 0),
  HabitTemplate('أذكار المساء', '🌙', HabitKind.check, PeriodType.day, 1, '', 4,
      reminderKind: 2, reminderMinutes: 20, reminderPrayer: 2),
  HabitTemplate('النوم مبكرًا', '😴', HabitKind.check, PeriodType.day, 1, '', 7,
      reminderKind: 1, reminderMinutes: 1350),
  HabitTemplate('صيام الإثنين والخميس', '🤲', HabitKind.check, PeriodType.week, 2, '', 6),
  HabitTemplate('مراجعة الدروس', '🧠', HabitKind.timer, PeriodType.day, 90, '', 5),
  HabitTemplate('مراجعة أهداف الشهر', '🎯', HabitKind.check, PeriodType.month, 1, '', 8),
  HabitTemplate('ختم القرآن', '📿', HabitKind.check, PeriodType.year, 1, '', 9),
];

const List<String> kEmojis = [
  '🕌', '📖', '🤲', '🌅', '🌙', '💧', '🏋️', '🏃', '🚴', '🧘',
  '📚', '🧠', '💻', '✍️', '🎯', '💰', '🥗', '🍎', '😴', '⏰',
  '🧹', '📞', '🌱', '🚭', '📵', '🎨', '🎧', '🛡️', '🔥', '⭐',
  '💪', '🏆', '🧪', '📝', '🤝', '❤️',
];

Future<void> showHabitEditor(BuildContext context, {Habit? habit, HabitTemplate? template}) {
  return Navigator.of(context).push(MaterialPageRoute<void>(
    fullscreenDialog: true,
    builder: (_) => HabitEditorPage(habit: habit, template: template),
  ));
}

class HabitEditorPage extends StatefulWidget {
  final Habit? habit;
  final HabitTemplate? template;
  const HabitEditorPage({super.key, this.habit, this.template});

  @override
  State<HabitEditorPage> createState() => _HabitEditorPageState();
}

class _HabitEditorPageState extends State<HabitEditorPage> {
  final _name = TextEditingController();
  final _target = TextEditingController(text: '1');
  final _unit = TextEditingController();
  String emoji = '🎯';
  int colorIdx = 0;
  HabitKind kind = HabitKind.check;
  PeriodType period = PeriodType.day;
  int reminderKind = 0;
  int timeMin = 480;
  int offset = 0;
  int prayer = 0;

  bool get editing => widget.habit != null;

  @override
  void initState() {
    super.initState();
    final h = widget.habit;
    if (h != null) {
      _name.text = h.name;
      _target.text = num1(h.target);
      _unit.text = h.unit;
      emoji = h.emoji;
      colorIdx = h.colorIdx;
      kind = h.kind;
      period = h.period;
      reminderKind = h.reminderKind;
      prayer = h.reminderPrayer;
      if (h.reminderKind == 2) {
        offset = h.reminderMinutes;
      } else {
        timeMin = h.reminderMinutes;
      }
    } else if (widget.template != null) {
      _applyTemplate(widget.template!);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    _unit.dispose();
    super.dispose();
  }

  void _applyTemplate(HabitTemplate t) {
    _name.text = t.name;
    emoji = t.emoji;
    colorIdx = t.color;
    kind = t.kind;
    period = t.period;
    _target.text = num1(t.target);
    _unit.text = t.unit;
    reminderKind = t.reminderKind;
    prayer = t.reminderPrayer;
    if (t.reminderKind == 2) {
      offset = t.reminderMinutes;
    } else {
      timeMin = t.reminderMinutes;
    }
  }

  bool get _targetFixed => kind == HabitKind.check && period == PeriodType.day;

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      toast(context, 'اكتب اسم العادة أولًا');
      return;
    }
    double target = 1;
    if (!_targetFixed) {
      target = double.tryParse(_target.text.trim().replaceAll(',', '.')) ?? 0;
      if (target <= 0) {
        toast(context, 'الهدف يجب أن يكون أكبر من صفر');
        return;
      }
      if (kind == HabitKind.check) target = target.roundToDouble();
    }
    final store = StoreScope.of(context);
    final rm = reminderKind == 2 ? offset : timeMin;
    final unit = kind == HabitKind.count ? _unit.text.trim() : '';
    final h = widget.habit;
    if (h != null) {
      h.name = name;
      h.emoji = emoji;
      h.colorIdx = colorIdx;
      h.kind = kind;
      h.period = period;
      h.target = target;
      h.unit = unit;
      h.reminderKind = reminderKind;
      h.reminderMinutes = rm;
      h.reminderPrayer = prayer;
      store.saveHabit();
    } else {
      store.addHabit(Habit(
        id: store.newId(),
        name: name,
        emoji: emoji,
        colorIdx: colorIdx,
        kind: kind,
        period: period,
        target: target,
        unit: unit,
        reminderKind: reminderKind,
        reminderMinutes: rm,
        reminderPrayer: prayer,
        createdDay: todayNum(),
      ));
    }
    if (reminderKind != 0) {
      // طلب إذن الإشعارات عند أول تذكير
      requestNotifPermissionLater();
    }
    Navigator.of(context).pop();
  }

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: kMuted),
        filled: true,
        fillColor: kCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: kLine),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: kLine),
        ),
      );

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 18, 2, 8),
        child: Text(t, style: const TextStyle(color: kMuted, fontSize: 13, fontWeight: FontWeight.w700)),
      );

  @override
  Widget build(BuildContext context) {
    final color = kHabitColors[colorIdx % kHabitColors.length];
    final targetLabel = kind == HabitKind.check
        ? 'عدد مرات الإنجاز المطلوبة ${periodIn(period)}'
        : kind == HabitKind.count
            ? 'الكمية المطلوبة ${periodIn(period)}'
            : 'الدقائق المطلوبة ${periodIn(period)}';

    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'تعديل العادة' : 'عادة جديدة'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('حفظ', style: TextStyle(color: kEmerald, fontSize: 16, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          if (!editing) ...[
            _label('ابدأ بقالب جاهز (اختياري)'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in kTemplates)
                  ActionChip(
                    backgroundColor: kCard,
                    side: const BorderSide(color: kLine),
                    label: Text('${t.emoji} ${t.name}', style: const TextStyle(color: kText, fontSize: 13)),
                    onPressed: () => setState(() => _applyTemplate(t)),
                  ),
              ],
            ),
          ],
          _label('الاسم'),
          TextField(
            controller: _name,
            style: const TextStyle(color: kText, fontSize: 17),
            decoration: _dec('مثال: صلاة الفجر في المسجد'),
          ),
          _label('الرمز'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in kEmojis)
                GestureDetector(
                  onTap: () => setState(() => emoji = e),
                  child: Container(
                    width: 46,
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: e == emoji ? a(color, 0.2) : kCard,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: e == emoji ? color : kLine, width: e == emoji ? 1.8 : 1),
                    ),
                    child: Text(e, style: const TextStyle(fontSize: 22)),
                  ),
                ),
            ],
          ),
          _label('اللون'),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (int i = 0; i < kHabitColors.length; i++)
                GestureDetector(
                  onTap: () => setState(() => colorIdx = i),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: kHabitColors[i],
                      shape: BoxShape.circle,
                      border: Border.all(color: i == colorIdx ? Colors.white : Colors.transparent, width: 2.4),
                    ),
                  ),
                ),
            ],
          ),
          _label('طريقة التتبّع'),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<HabitKind>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: HabitKind.check, label: Text('تأكيد'), icon: Icon(Icons.check_circle_outline)),
                ButtonSegment(value: HabitKind.count, label: Text('عدّاد'), icon: Icon(Icons.numbers_rounded)),
                ButtonSegment(value: HabitKind.timer, label: Text('مؤقّت'), icon: Icon(Icons.timer_outlined)),
              ],
              selected: {kind},
              onSelectionChanged: (s) => setState(() => kind = s.first),
            ),
          ),
          _label('الفترة'),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<PeriodType>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: PeriodType.day, label: Text('يومي')),
                ButtonSegment(value: PeriodType.week, label: Text('أسبوعي')),
                ButtonSegment(value: PeriodType.month, label: Text('شهري')),
                ButtonSegment(value: PeriodType.year, label: Text('سنوي')),
              ],
              selected: {period},
              onSelectionChanged: (s) => setState(() => period = s.first),
            ),
          ),
          if (!_targetFixed) ...[
            _label(targetLabel),
            TextField(
              controller: _target,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: kText, fontSize: 17),
              decoration: _dec('مثال: 4'),
            ),
          ],
          if (kind == HabitKind.count) ...[
            _label('وحدة القياس (اختياري)'),
            TextField(
              controller: _unit,
              style: const TextStyle(color: kText, fontSize: 17),
              decoration: _dec('مثال: كوب، صفحة، كم'),
            ),
          ],
          _label('التذكير'),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<int>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 0, label: Text('بدون')),
                ButtonSegment(value: 1, label: Text('وقت ثابت')),
                ButtonSegment(value: 2, label: Text('مع صلاة')),
              ],
              selected: {reminderKind},
              onSelectionChanged: (s) => setState(() => reminderKind = s.first),
            ),
          ),
          if (reminderKind == 1) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                final t = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay(hour: timeMin ~/ 60, minute: timeMin % 60),
                );
                if (t != null) setState(() => timeMin = t.hour * 60 + t.minute);
              },
              icon: const Icon(Icons.access_time_rounded),
              label: Text(fmtClock(timeMin), style: const TextStyle(fontSize: 18)),
            ),
          ],
          if (reminderKind == 2) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (int i = 0; i < 5; i++)
                  ChoiceChip(
                    label: Text(kPrayerNames[i]),
                    selected: prayer == i,
                    onSelected: (_) => setState(() => prayer = i),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.outlined(
                  onPressed: () => setState(() => offset -= 5),
                  icon: const Icon(Icons.remove_rounded),
                ),
                Container(
                  width: 170,
                  alignment: Alignment.center,
                  child: Text(
                    offset == 0
                        ? 'عند دخول الوقت'
                        : offset > 0
                            ? 'بعد ${offset} دقيقة'
                            : 'قبل ${-offset} دقيقة',
                    style: const TextStyle(color: kText, fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton.outlined(
                  onPressed: () => setState(() => offset += 5),
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
          ],
          if (reminderKind != 0)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text(
                'يُتخطّى التذكير تلقائيًا إذا أنجزت العادة، وتُحسب أوقات الصلاة حسب ولايتك في تبويب الصلاة.',
                style: TextStyle(color: kMuted, fontSize: 12, height: 1.5),
              ),
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
            child: Text(editing ? 'حفظ التعديلات' : 'إضافة العادة',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}
