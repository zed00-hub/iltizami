import 'dart:async';
import 'package:flutter/material.dart';
import 'habit_widgets.dart';
import 'models.dart';
import 'models_ext.dart';
import 'stats.dart';
import 'store.dart';
import 'ui_common.dart';
import 'util.dart';

// ═════════════════════════ مخطط خطي ═════════════════════════

class _LinePainter extends CustomPainter {
  final List<double> values;
  final Color color;
  final double goal;
  _LinePainter(this.values, this.color, this.goal);

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    const pad = 14.0;
    double lo = values.first;
    double hi = values.first;
    for (final v in values) {
      if (v < lo) lo = v;
      if (v > hi) hi = v;
    }
    if (goal > 0) {
      if (goal < lo) lo = goal;
      if (goal > hi) hi = goal;
    }
    if (hi - lo < 0.0001) {
      hi += 1;
      lo -= 1;
    }
    final w = size.width - pad * 2;
    final h = size.height - pad * 2;
    double xAt(int i) => values.length == 1 ? size.width / 2 : size.width - pad - i * (w / (values.length - 1));
    double yAt(double v) => pad + h - ((v - lo) / (hi - lo)) * h;

    final grid = Paint()
      ..color = a(kLine, 0.7)
      ..strokeWidth = 1;
    for (int i = 0; i < 3; i++) {
      final y = pad + h * i / 2;
      canvas.drawLine(Offset(pad, y), Offset(size.width - pad, y), grid);
    }
    if (goal > 0) {
      final gy = yAt(goal);
      final gp = Paint()
        ..color = a(kGold, 0.8)
        ..strokeWidth = 1.4;
      double x = pad;
      while (x < size.width - pad) {
        canvas.drawLine(Offset(x, gy), Offset(x + 6, gy), gp);
        x += 11;
      }
    }
    final path = Path();
    // values[0] الأقدم
    for (int i = 0; i < values.length; i++) {
      final p = Offset(xAt(i), yAt(values[i]));
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
    for (int i = 0; i < values.length; i++) {
      final p = Offset(xAt(i), yAt(values[i]));
      canvas.drawCircle(p, 4.5, Paint()..color = kBg);
      canvas.drawCircle(p, 3.2, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _LinePainter old) =>
      old.values != values || old.color != color || old.goal != goal;
}

class LineChart extends StatelessWidget {
  final List<double> values;
  final Color color;
  final double goal;
  final double height;
  const LineChart({super.key, required this.values, required this.color, this.goal = 0, this.height = 130});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(painter: _LinePainter(values, color, goal)),
    );
  }
}

const List<String> kPickEmojis = [
  '📏', '💪', '⚖️', '🩸', '🧪', '❤️', '🦵', '🏋️', '🍎', '💧', '😴', '📈', '🧬', '🥩', '🌡️', '👟',
];

// ═════════════════════════ قياساتي ═════════════════════════

class MetricsScreen extends StatelessWidget {
  const MetricsScreen({super.key});

  Future<void> _add(BuildContext context, AppStore store) async {
    final name = TextEditingController();
    final unit = TextEditingController();
    final goal = TextEditingController();
    String emoji = '📏';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: kCard,
            title: const Text('قياس جديد', style: TextStyle(color: kText, fontSize: 17)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: name,
                    autofocus: true,
                    style: const TextStyle(color: kText),
                    decoration: const InputDecoration(hintText: 'الاسم: حجم البايسبس، مخزون الحديد...'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: unit,
                    style: const TextStyle(color: kText),
                    decoration: const InputDecoration(hintText: 'الوحدة: سم، كغ، ng/ml...'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: goal,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: kText),
                    decoration: const InputDecoration(hintText: 'الهدف (اختياري)'),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final e in kPickEmojis)
                        GestureDetector(
                          onTap: () => setD(() => emoji = e),
                          child: Container(
                            width: 38,
                            height: 38,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: e == emoji ? a(kEmerald, 0.2) : kCard2,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: e == emoji ? kEmerald : kLine),
                            ),
                            child: Text(e, style: const TextStyle(fontSize: 18)),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء', style: TextStyle(color: kMuted))),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('إضافة')),
            ],
          ),
        ),
      ),
    );
    if (ok == true && name.text.trim().isNotEmpty) {
      store.addMetric(Metric(
        id: store.newId(),
        name: name.text.trim(),
        unit: unit.text.trim(),
        emoji: emoji,
        goal: double.tryParse(goal.text.trim().replaceAll(',', '.')) ?? 0,
      ));
    }
    name.dispose();
    unit.dispose();
    goal.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('📏 قياساتي')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: kEmerald,
        foregroundColor: Colors.black,
        onPressed: () => _add(context, store),
        icon: const Icon(Icons.add_rounded),
        label: const Text('قياس جديد', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 110),
        children: [
          if (store.metrics.isEmpty)
            const AppCard(
              child: Text(
                'سمِّ أي قياس تريد متابعته بنفسك: حجم البايسبس، الوزن، مخزون الحديد، سكر الدم...\nسجّل قيمته كل فترة وشاهد منحناه وتقدّمك نحو هدفك.',
                textAlign: TextAlign.center,
                style: TextStyle(color: kMuted, height: 1.7),
              ),
            ),
          for (final m in store.metrics)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _MetricCard(metric: m),
            ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final Metric metric;
  const _MetricCard({required this.metric});

  @override
  Widget build(BuildContext context) {
    final days = metric.sortedDays();
    final vals = days.map((d) => metric.entries[d]!).toList();
    final last = vals.isEmpty ? null : vals.last;
    final prev = vals.length >= 2 ? vals[vals.length - 2] : null;
    String delta = '';
    Color dc = kMuted;
    if (last != null && prev != null) {
      final d = last - prev;
      delta = '${d > 0 ? '+' : ''}${num1(double.parse(d.toStringAsFixed(2)))}';
      dc = d == 0 ? kMuted : kEmerald;
    }
    final recent = vals.length > 12 ? vals.sublist(vals.length - 12) : vals;
    return AppCard(
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => MetricDetailScreen(metricId: metric.id))),
      child: Column(
        children: [
          Row(
            children: [
              Text(metric.emoji, style: const TextStyle(fontSize: 26)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(metric.name,
                    style: const TextStyle(color: kText, fontSize: 16.5, fontWeight: FontWeight.w800)),
              ),
              if (last != null) ...[
                if (delta.isNotEmpty) Text('$delta  ', style: TextStyle(color: dc, fontSize: 13, fontWeight: FontWeight.w700)),
                Text('${num1(last)} ${metric.unit}',
                    style: const TextStyle(color: kEmerald, fontSize: 19, fontWeight: FontWeight.w900)),
              ] else
                const Text('لا قياسات', style: TextStyle(color: kMuted)),
            ],
          ),
          if (recent.length >= 2) ...[
            const SizedBox(height: 8),
            LineChart(values: recent, color: kEmerald, goal: metric.goal, height: 80),
          ],
        ],
      ),
    );
  }
}

class MetricDetailScreen extends StatelessWidget {
  final String metricId;
  const MetricDetailScreen({super.key, required this.metricId});

  Metric? _find(AppStore s) {
    for (final m in s.metrics) {
      if (m.id == metricId) return m;
    }
    return null;
  }

  Future<void> _record(BuildContext context, AppStore store, Metric m, int day) async {
    final cur = m.entries[day];
    final v = await askNumber(context, title: 'قيمة ${m.name}', initial: cur ?? 0, suffix: m.unit);
    if (v != null && v != 0) store.setEntry(m, day, v);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final m = _find(store);
    if (m == null) return const Scaffold(body: Center(child: Text('غير موجود')));
    final today = todayNum();
    final days = m.sortedDays();
    final vals = days.map((d) => m.entries[d]!).toList();
    final shown = vals.length > 30 ? vals.sublist(vals.length - 30) : vals;
    final first = vals.isEmpty ? null : vals.first;
    final last = vals.isEmpty ? null : vals.last;
    double? mn;
    double? mx;
    for (final v in vals) {
      if (mn == null || v < mn) mn = v;
      if (mx == null || v > mx) mx = v;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${m.emoji} ${m.name}'),
        actions: [
          IconButton(
            onPressed: () async {
              final ok = await confirmDialog(context, 'حذف القياس؟', 'سيُحذف بكل قيمه.', ok: 'حذف', danger: true);
              if (ok && context.mounted) {
                store.deleteMetric(m);
                Navigator.of(context).pop();
              }
            },
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 60),
        children: [
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _record(context, store, m, today),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('سجّل قياس اليوم'),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  final p = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (p != null && context.mounted) _record(context, store, m, dayOf(p));
                },
                icon: const Icon(Icons.event_rounded, size: 18),
                label: const Text('يوم آخر'),
              ),
            ],
          ),
          const SectionTitle('المنحنى'),
          AppCard(
            child: shown.length < 2
                ? const Padding(
                    padding: EdgeInsets.all(18),
                    child: Text('سجّل قيمتين على الأقل ليظهر المنحنى.',
                        textAlign: TextAlign.center, style: TextStyle(color: kMuted)),
                  )
                : LineChart(values: shown, color: kEmerald, goal: m.goal, height: 170),
          ),
          if (m.goal > 0)
            const Padding(
              padding: EdgeInsets.only(top: 6, right: 4),
              child: Text('الخط الذهبي المتقطّع = هدفك.', style: TextStyle(color: kMuted, fontSize: 11.5)),
            ),
          const SectionTitle('الأرقام'),
          TwoColumn(children: [
            StatTile(emoji: '📍', label: 'آخر قياس', value: last == null ? '—' : '${num1(last)} ${m.unit}',
                sub: days.isEmpty ? null : fmtShort(days.last), color: kEmerald),
            StatTile(
              emoji: '↕️',
              label: 'التغيّر منذ البداية',
              value: (first == null || last == null) ? '—' : '${last - first > 0 ? '+' : ''}${num1(double.parse((last - first).toStringAsFixed(2)))} ${m.unit}',
              sub: days.isEmpty ? null : 'منذ ${fmtShort(days.first)}',
            ),
            StatTile(emoji: '⬇️', label: 'الأدنى', value: mn == null ? '—' : '${num1(mn)} ${m.unit}'),
            StatTile(emoji: '⬆️', label: 'الأعلى', value: mx == null ? '—' : '${num1(mx)} ${m.unit}'),
            if (m.goal > 0 && last != null)
              StatTile(
                emoji: '🎯',
                label: 'المتبقّي للهدف',
                value: '${num1(double.parse((m.goal - last).toStringAsFixed(2)))} ${m.unit}',
                sub: 'الهدف ${num1(m.goal)}',
                color: kGold,
              ),
          ]),
          const SectionTitle('السجل'),
          if (days.isEmpty) const Text('لا قيم بعد.', style: TextStyle(color: kMuted)),
          for (final d in days.reversed)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: Row(
                  children: [
                    Text(fmtDay(d), style: const TextStyle(color: kMuted, fontSize: 13)),
                    const Spacer(),
                    Text('${num1(m.entries[d]!)} ${m.unit}',
                        style: const TextStyle(color: kText, fontWeight: FontWeight.w800)),
                    IconButton(
                      onPressed: () => store.setEntry(m, d, null),
                      icon: const Icon(Icons.close_rounded, color: kMuted, size: 18),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ═════════════════════════ يومية المزاج ═════════════════════════

const List<String> kMoodEmoji = ['', '😞', '😕', '😐', '🙂', '😄'];
const List<String> kMoodName = ['', 'سيئ جدًا', 'سيئ', 'عادي', 'جيد', 'ممتاز'];

class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  final _note = TextEditingController();
  int day = todayNum();
  int mood = 0;
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loaded = true;
      _loadDay(StoreScope.of(context));
    }
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _loadDay(AppStore store) {
    final e = store.journal[day];
    mood = e?.mood ?? 0;
    _note.text = e?.note ?? '';
  }

  /// متوسط المزاج في الأيام التي أنجزت فيها ≥80% من العادات اليومية مقابل غيرها
  String _insight(AppStore store) {
    final habits = store.active.where((h) => h.period == PeriodType.day).toList();
    if (habits.isEmpty) return '';
    final ws = store.settings.weekStart;
    double hiSum = 0, loSum = 0;
    int hiN = 0, loN = 0;
    store.journal.forEach((d, e) {
      int tot = 0;
      int done = 0;
      for (final h in habits) {
        if (d < h.createdDay) continue;
        tot++;
        if (periodMetAtDay(h, ws, d)) done++;
      }
      if (tot == 0) return;
      if (done / tot >= 0.8) {
        hiSum += e.mood;
        hiN++;
      } else {
        loSum += e.mood;
        loN++;
      }
    });
    if (hiN < 3 || loN < 3) return 'سجّل مزاجك في المزيد من الأيام (3 أيام التزام عالٍ و3 أيام أقل) لتظهر العلاقة بين مزاجك والتزامك.';
    final hi = hiSum / hiN;
    final lo = loSum / loN;
    final diff = hi - lo;
    final avgHi = hi.toStringAsFixed(1);
    final avgLo = lo.toStringAsFixed(1);
    if (diff >= 0.3) return 'في أيام التزامك العالي ($hiN يومًا) مزاجك $avgHi من 5، مقابل $avgLo في الأيام الأقل. الالتزام يحسّن مزاجك 💚';
    if (diff <= -0.3) return 'مزاجك في أيام الالتزام العالي $avgHi مقابل $avgLo في غيرها. لا علاقة إيجابية واضحة بعد، فاهتم بما يرهقك.';
    return 'مزاجك متقارب بين أيام الالتزام العالي ($avgHi) والأقل ($avgLo).';
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final today = todayNum();
    final entries = store.journal.entries.toList()..sort((a, b) => b.key.compareTo(a.key));
    final bars = <double>[];
    final labels = <String>[];
    double sum = 0;
    int n = 0;
    for (int i = 13; i >= 0; i--) {
      final d = today - i;
      final e = store.journal[d];
      bars.add(e == null ? 0 : e.mood.toDouble());
      labels.add('${dateOf(d).day}');
      if (e != null) {
        sum += e.mood;
        n++;
      }
    }
    final insight = _insight(store);

    return Scaffold(
      appBar: AppBar(title: const Text('📝 يومية المزاج')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 60),
        children: [
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => setState(() {
                    day--;
                    _loadDay(store);
                  }),
                  icon: const Icon(Icons.chevron_right_rounded, color: kText),
                ),
                Expanded(
                  child: Text(day == today ? 'اليوم • ${fmtShort(day)}' : fmtDay(day),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: kText, fontSize: 15.5, fontWeight: FontWeight.w800)),
                ),
                IconButton(
                  onPressed: day >= today
                      ? null
                      : () => setState(() {
                            day++;
                            _loadDay(store);
                          }),
                  icon: Icon(Icons.chevron_left_rounded, color: day >= today ? kLine : kText),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Text('كيف كان مزاجك؟', style: TextStyle(color: kText, fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (int i = 1; i <= 5; i++)
                GestureDetector(
                  onTap: () => setState(() => mood = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 58,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: mood == i ? a(kEmerald, 0.2) : kCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: mood == i ? kEmerald : kLine, width: mood == i ? 1.8 : 1),
                    ),
                    child: Column(
                      children: [
                        Text(kMoodEmoji[i], style: const TextStyle(fontSize: 26)),
                        const SizedBox(height: 3),
                        Text(kMoodName[i],
                            maxLines: 1,
                            style: TextStyle(color: mood == i ? kEmerald : kMuted, fontSize: 10)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _note,
            maxLines: 5,
            style: const TextStyle(color: kText, height: 1.6),
            decoration: InputDecoration(
              hintText: 'تأمّل اليوم: ما الذي أنجزته؟ ما الذي تشكر عليه؟ ما الذي ستتعلّمه؟',
              hintStyle: const TextStyle(color: kMuted, fontSize: 13),
              filled: true,
              fillColor: kCard,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: kLine)),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    if (mood == 0) {
                      toast(context, 'اختر مزاجك أولًا');
                      return;
                    }
                    store.setJournal(day, mood, _note.text);
                    toast(context, 'حُفظت يوميتك ✓');
                  },
                  child: const Text('حفظ'),
                ),
              ),
              if (store.journal.containsKey(day)) ...[
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () {
                    store.clearJournal(day);
                    setState(() {
                      mood = 0;
                      _note.clear();
                    });
                  },
                  child: const Text('مسح'),
                ),
              ],
            ],
          ),
          const SectionTitle('مزاجك آخر 14 يومًا'),
          AppCard(child: MiniBars(values: bars, labels: labels, color: kEmerald, height: 110)),
          const SizedBox(height: 8),
          if (n > 0)
            Text('المتوسط: ${(sum / n).toStringAsFixed(1)} من 5 (${kMoodEmoji[clampI((sum / n).round(), 1, 5)]})',
                style: const TextStyle(color: kMuted, fontSize: 13)),
          if (insight.isNotEmpty) ...[
            const SectionTitle('المزاج والالتزام'),
            AppCard(child: Text(insight, style: const TextStyle(color: kText, height: 1.7, fontSize: 13.5))),
          ],
          if (entries.isNotEmpty) const SectionTitle('السجل'),
          for (final e in entries.take(30))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                padding: const EdgeInsets.all(12),
                onTap: () => setState(() {
                  day = e.key;
                  _loadDay(store);
                }),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(kMoodEmoji[e.value.mood], style: const TextStyle(fontSize: 26)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(fmtDay(e.key), style: const TextStyle(color: kMuted, fontSize: 12)),
                          if (e.value.note.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(e.value.note,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: kText, height: 1.5)),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ═════════════════════════ عادات للترك ═════════════════════════

String cleanText(int ms) {
  final totalMin = ms ~/ 60000;
  final d = totalMin ~/ 1440;
  final h = (totalMin % 1440) ~/ 60;
  final m = totalMin % 60;
  if (d > 0) return '$d يوم و$h س';
  if (h > 0) return '$h س و$m د';
  return '$m د';
}

const List<int> kCleanMilestones = [1, 3, 7, 14, 30, 60, 90, 180, 365, 730];

class QuitScreen extends StatefulWidget {
  const QuitScreen({super.key});

  @override
  State<QuitScreen> createState() => _QuitScreenState();
}

class _QuitScreenState extends State<QuitScreen> {
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  Future<void> _add(BuildContext context, AppStore store) async {
    final name = TextEditingController();
    final why = TextEditingController();
    String emoji = '🚭';
    int sinceDay = todayNum();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: kCard,
            title: const Text('عادة أريد تركها', style: TextStyle(color: kText, fontSize: 17)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: name,
                    autofocus: true,
                    style: const TextStyle(color: kText),
                    decoration: const InputDecoration(hintText: 'مثال: التدخين، وقت الهاتف الزائد'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: why,
                    style: const TextStyle(color: kText),
                    decoration: const InputDecoration(hintText: 'لماذا أتركها؟ (دافعك)'),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    children: [
                      for (final e in const ['🚭', '📵', '🍬', '☕', '🎮', '🍔', '🚫', '🧠'])
                        GestureDetector(
                          onTap: () => setD(() => emoji = e),
                          child: Container(
                            width: 38,
                            height: 38,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: e == emoji ? a(kEmerald, 0.2) : kCard2,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: e == emoji ? kEmerald : kLine),
                            ),
                            child: Text(e, style: const TextStyle(fontSize: 18)),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () async {
                      final d = dateOf(sinceDay);
                      final p = await showDatePicker(
                        context: ctx,
                        initialDate: DateTime(d.year, d.month, d.day),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (p != null) setD(() => sinceDay = dayOf(p));
                    },
                    icon: const Icon(Icons.event_rounded, size: 18),
                    label: Text('نظيف منذ: ${fmtShort(sinceDay)}'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء', style: TextStyle(color: kMuted))),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('ابدأ')),
            ],
          ),
        ),
      ),
    );
    if (ok == true && name.text.trim().isNotEmpty) {
      final now = DateTime.now();
      final since = sinceDay == todayNum()
          ? now.millisecondsSinceEpoch
          : DateTime(dateOf(sinceDay).year, dateOf(sinceDay).month, dateOf(sinceDay).day).millisecondsSinceEpoch;
      store.addQuit(QuitHabit(
        id: store.newId(),
        name: name.text.trim(),
        emoji: emoji,
        why: why.text.trim(),
        sinceMs: since,
      ));
    }
    name.dispose();
    why.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    return Scaffold(
      appBar: AppBar(title: const Text('🚫 عادات للترك')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: kEmerald,
        foregroundColor: Colors.black,
        onPressed: () => _add(context, store),
        icon: const Icon(Icons.add_rounded),
        label: const Text('عادة للترك', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 110),
        children: [
          if (store.quits.isEmpty)
            const AppCard(
              child: Text('أضف عادة تريد التخلّص منها، وسيحسب لك التطبيق مدّة نظافتك لحظةً بلحظة، وأطول مدة حقّقتها.',
                  textAlign: TextAlign.center, style: TextStyle(color: kMuted, height: 1.7)),
            ),
          for (final q in store.quits)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _quitCard(context, store, q, nowMs),
            ),
        ],
      ),
    );
  }

  Widget _quitCard(BuildContext context, AppStore store, QuitHabit q, int nowMs) {
    final cur = q.currentMs(nowMs);
    final curDays = cur ~/ 86400000;
    int next = kCleanMilestones.last * 2;
    int prevM = 0;
    for (final m in kCleanMilestones) {
      if (curDays < m) {
        next = m;
        break;
      }
      prevM = m;
    }
    final prog = next == prevM ? 1.0 : clampD((cur / 86400000 - prevM) / (next - prevM), 0.0, 1.0);
    return AppCard(
      gradient: LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [a(kEmerald, 0.16), kCard],
      ),
      borderColor: a(kEmerald, 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(q.emoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(q.name, style: const TextStyle(color: kText, fontSize: 18, fontWeight: FontWeight.w900)),
              ),
              PopupMenuButton<String>(
                color: kCard2,
                icon: const Icon(Icons.more_vert_rounded, color: kMuted),
                onSelected: (v) async {
                  if (v == 'delete') {
                    final ok = await confirmDialog(context, 'حذف؟', 'ستُحذف هذه العادة وسجلّها.', ok: 'حذف', danger: true);
                    if (ok) store.deleteQuit(q);
                  }
                },
                itemBuilder: (_) => const [PopupMenuItem(value: 'delete', child: Text('حذف', style: TextStyle(color: kDanger)))],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(cleanText(cur), style: const TextStyle(color: kEmerald, fontSize: 32, fontWeight: FontWeight.w900)),
          const Text('نظيف حتى الآن', style: TextStyle(color: kMuted, fontSize: 12.5)),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: prog,
              minHeight: 7,
              backgroundColor: a(kEmerald, 0.14),
              valueColor: const AlwaysStoppedAnimation<Color>(kEmerald),
            ),
          ),
          const SizedBox(height: 4),
          Text('المحطة القادمة: $next يومًا', style: const TextStyle(color: kMuted, fontSize: 11.5)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              MiniChip('🏆 أطول مدة: ${cleanText(q.longestMs(nowMs))}', color: kGold),
              MiniChip('انتكاسات: ${q.relapses.length}', color: kMuted),
            ],
          ),
          if (q.why.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text('لأن: ${q.why}', style: const TextStyle(color: kText, height: 1.6, fontSize: 13)),
            ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(foregroundColor: kDanger, side: const BorderSide(color: kDanger)),
              onPressed: () async {
                final ok = await confirmDialog(
                  context,
                  'سجّل انتكاسة؟',
                  'سيبدأ العدّاد من جديد، وتبقى أطول مدة محفوظة لك. الانتكاسة ليست نهاية الطريق.',
                  ok: 'سجّل',
                  danger: true,
                );
                if (ok) store.relapse(q);
              },
              child: const Text('انتكست'),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════ ختمة القرآن ═════════════════════════

class KhatmaScreen extends StatelessWidget {
  const KhatmaScreen({super.key});

  Future<void> _start(BuildContext context, AppStore store, int days) async {
    store.startKhatma(days);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final k = store.khatma;
    final today = todayNum();

    if (k == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('📖 ختمة القرآن')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 40),
          children: [
            AppCard(
              child: Column(
                children: [
                  const Text('📖', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 8),
                  const Text('ابدأ ختمة جديدة', style: TextStyle(color: kText, fontSize: 20, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text('المصحف $kQuranPages صفحة. اختر المدة التي تريد أن تختم فيها.',
                      textAlign: TextAlign.center, style: const TextStyle(color: kMuted, height: 1.6)),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      for (final d in const [30, 60, 90, 180, 365])
                        ActionChip(
                          backgroundColor: kCard2,
                          label: Text('$d يومًا  •  ${(kQuranPages / d).ceil()} ص/يوم'),
                          onPressed: () => _start(context, store, d),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () async {
                      final v = await askNumber(context, title: 'عدد الأيام', initial: 30, suffix: 'يوم');
                      if (v != null && v >= 1 && context.mounted) _start(context, store, v.round());
                    },
                    child: const Text('مدة أخرى', style: TextStyle(color: kEmerald)),
                  ),
                ],
              ),
            ),
            if (store.khatmaDone > 0)
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Center(
                  child: Text('ختمات مكتملة: ${store.khatmaDone} 🌟',
                      style: const TextStyle(color: kGold, fontSize: 15, fontWeight: FontWeight.w800)),
                ),
              ),
          ],
        ),
      );
    }

    final total = k.total;
    final pct = clampD(total / kQuranPages, 0.0, 1.0);
    final elapsed = clampI(today - k.startDay + 1, 1, 100000);
    final remainingDays = k.targetDays - elapsed + 1;
    final remainingPages = (kQuranPages - total) < 0 ? 0 : kQuranPages - total;
    final perDayNeeded = remainingDays <= 0 ? remainingPages : (remainingPages / remainingDays).ceil();
    final avg = total / elapsed;
    final eta = avg <= 0 ? null : today + (remainingPages / avg).ceil();
    final targetEnd = k.startDay + k.targetDays - 1;
    final todayPages = k.pages[today] ?? 0;
    final bars = <double>[];
    final labels = <String>[];
    for (int i = 13; i >= 0; i--) {
      bars.add((k.pages[today - i] ?? 0).toDouble());
      labels.add('${dateOf(today - i).day}');
    }
    final done = total >= kQuranPages;

    return Scaffold(
      appBar: AppBar(
        title: const Text('📖 ختمة القرآن'),
        actions: [
          PopupMenuButton<String>(
            color: kCard2,
            onSelected: (v) async {
              if (v == 'cancel') {
                final ok = await confirmDialog(context, 'إلغاء الختمة؟', 'ستُحذف صفحاتها المسجّلة.', ok: 'إلغاء الختمة', danger: true);
                if (ok) store.cancelKhatma();
              }
            },
            itemBuilder: (_) => const [PopupMenuItem(value: 'cancel', child: Text('إلغاء الختمة', style: TextStyle(color: kDanger)))],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 60),
        children: [
          AppCard(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [a(kEmerald, 0.2), kCard],
            ),
            borderColor: a(kEmerald, 0.4),
            child: Row(
              children: [
                Ring(
                  progress: pct,
                  color: kEmerald,
                  size: 104,
                  stroke: 10,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${(pct * 100).round()}%',
                          style: const TextStyle(color: kText, fontSize: 22, fontWeight: FontWeight.w900)),
                      Text('$total / $kQuranPages', style: const TextStyle(color: kMuted, fontSize: 11)),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('اليوم $elapsed من ${k.targetDays}',
                          style: const TextStyle(color: kText, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text('تنتهي ${fmtShort(targetEnd)}', style: const TextStyle(color: kMuted, fontSize: 12.5)),
                      const SizedBox(height: 8),
                      if (!done)
                        Text(
                          remainingDays > 0
                              ? 'المطلوب يوميًا: $perDayNeeded صفحة'
                              : 'تجاوزت المدة المحددة',
                          style: const TextStyle(color: kGold, fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SectionTitle('قراءة اليوم'),
          AppCard(
            child: Column(
              children: [
                Text('$todayPages صفحة', style: const TextStyle(color: kEmerald, fontSize: 30, fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final n in const [1, 2, 5, 10, 20])
                      FilledButton.tonal(
                        onPressed: () => store.addPages(today, n),
                        child: Text('+$n'),
                      ),
                    OutlinedButton(
                      onPressed: todayPages == 0 ? null : () => store.addPages(today, -1),
                      child: const Text('-1'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SectionTitle('الإيقاع'),
          TwoColumn(children: [
            StatTile(emoji: '⚡', label: 'متوسطك اليومي', value: '${avg.toStringAsFixed(1)} ص', color: kEmerald),
            StatTile(
              emoji: '🏁',
              label: 'ختمك المتوقّع',
              value: done ? 'اكتملت 🎉' : (eta == null ? '—' : fmtShort(eta)),
              sub: eta == null || done ? null : (eta <= targetEnd ? 'في الموعد' : 'بعد الموعد بـ${eta - targetEnd} يوم'),
              color: (eta != null && eta > targetEnd && !done) ? kDanger : kGold,
            ),
          ]),
          AppCard(child: MiniBars(values: bars, labels: labels, color: kEmerald, target: perDayNeeded.toDouble(), height: 110)),
          const Padding(
            padding: EdgeInsets.only(top: 6, right: 4),
            child: Text('الخط الذهبي = الصفحات اليومية المطلوبة لتختم في موعدك.',
                style: TextStyle(color: kMuted, fontSize: 11.5)),
          ),
          if (done) ...[
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: kGold, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 16)),
              onPressed: () {
                store.finishKhatma();
                toast(context, 'تقبّل الله منك! 🌟');
              },
              child: const Text('أتممت الختمة 🎉', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
            ),
          ],
          if (store.khatmaDone > 0)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Center(child: Text('ختمات مكتملة: ${store.khatmaDone} 🌟', style: const TextStyle(color: kGold))),
            ),
        ],
      ),
    );
  }
}
