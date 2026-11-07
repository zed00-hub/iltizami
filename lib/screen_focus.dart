import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models.dart';
import 'notifications.dart';
import 'planning.dart';
import 'store.dart';
import 'ui_common.dart';
import 'util.dart';

class FocusScreen extends StatefulWidget {
  final String? taskId;
  const FocusScreen({super.key, this.taskId});

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> {
  Timer? _t;
  bool work = true;
  bool running = false;
  int endMs = 0;
  int totalSec = 25 * 60;
  int remaining = 25 * 60;
  int sessions = 0;
  String taskId = '';
  bool _inited = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_inited) {
      _inited = true;
      taskId = widget.taskId ?? '';
      _resetTimes(StoreScope.of(context));
    }
  }

  @override
  void dispose() {
    _t?.cancel();
    if (running) NotificationService.cancelFocus();
    super.dispose();
  }

  void _resetTimes(AppStore store) {
    final mins = work ? store.settings.focusWork : store.settings.focusBreak;
    totalSec = mins * 60;
    remaining = totalSec;
  }

  void _start(AppStore store) {
    endMs = DateTime.now().millisecondsSinceEpoch + remaining * 1000;
    running = true;
    NotificationService.requestPermission();
    NotificationService.scheduleFocus(
      DateTime.fromMillisecondsSinceEpoch(endMs),
      work ? '🍅 انتهت جلسة التركيز' : '☕ انتهت الاستراحة',
      work ? 'أحسنت! خذ استراحة قصيرة.' : 'جاهز لجلسة تركيز جديدة؟',
    );
    _t?.cancel();
    _t = Timer.periodic(const Duration(seconds: 1), (_) => _tick(store));
    setState(() {});
  }

  void _tick(AppStore store) {
    final rem = ((endMs - DateTime.now().millisecondsSinceEpoch) / 1000).ceil();
    if (rem <= 0) {
      _complete(store);
    } else if (mounted) {
      setState(() => remaining = rem);
    }
  }

  void _complete(AppStore store) {
    _t?.cancel();
    running = false;
    if (work) {
      store.addFocus(todayNum(), totalSec ~/ 60, taskId.isEmpty ? null : taskId);
      sessions++;
      HapticFeedback.heavyImpact();
      if (mounted) toast(context, 'أحسنت! جلسة تركيز مكتملة 🍅');
    }
    work = !work;
    _resetTimes(store);
    if (mounted) setState(() {});
  }

  void _pause() {
    _t?.cancel();
    running = false;
    NotificationService.cancelFocus();
    setState(() {});
  }

  void _stop(AppStore store) {
    _t?.cancel();
    final elapsed = totalSec - remaining;
    if (running) NotificationService.cancelFocus();
    running = false;
    if (work && elapsed >= 60) {
      store.addFocus(todayNum(), (elapsed / 60).round(), taskId.isEmpty ? null : taskId);
      toast(context, 'احتُسبت ${(elapsed / 60).round()} دقيقة تركيز');
    }
    _resetTimes(store);
    setState(() {});
  }

  String _clock(int sec) => '${pad2(sec ~/ 60)}:${pad2(sec % 60)}';

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final today = todayNum();
    final color = work ? kEmerald : kGold;
    final prog = totalSec == 0 ? 0.0 : 1 - remaining / totalSec;
    final todayMin = store.focus[today] ?? 0;
    final bars = <double>[];
    final labels = <String>[];
    double weekTotal = 0;
    for (int i = 6; i >= 0; i--) {
      final v = (store.focus[today - i] ?? 0).toDouble();
      bars.add(v);
      weekTotal += v;
      labels.add(kWeekdaysShort[weekdayOf(today - i) - 1]);
    }
    final openTasks = store.tasks.where((t) => !taskIsDone(t, store.tasks)).toList();
    if (taskId.isNotEmpty && !openTasks.any((t) => t.id == taskId)) {
      final cur = store.taskById(taskId);
      if (cur != null) openTasks.add(cur);
    }
    final taskItems = <DropdownMenuItem<String>>[
      const DropdownMenuItem(value: '', child: Text('بدون مهمة محددة')),
      for (final t in openTasks.take(40))
        DropdownMenuItem(value: t.id, child: Text(t.title, overflow: TextOverflow.ellipsis)),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('🍅 مؤقت التركيز')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          Center(
            child: Text(work ? 'وقت التركيز' : 'استراحة',
                style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 14),
          Center(
            child: Ring(
              progress: prog,
              color: color,
              size: 240,
              stroke: 14,
              child: Text(_clock(remaining),
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(color: kText, fontSize: 52, fontWeight: FontWeight.w900)),
            ),
          ),
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!running)
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  ),
                  onPressed: () => _start(store),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(remaining == totalSec ? 'ابدأ' : 'استئناف',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                )
              else
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: kCard2,
                    foregroundColor: kText,
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  ),
                  onPressed: _pause,
                  icon: const Icon(Icons.pause_rounded),
                  label: const Text('إيقاف مؤقت', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                ),
              const SizedBox(width: 12),
              if (running || remaining != totalSec)
                OutlinedButton.icon(
                  onPressed: () => _stop(store),
                  icon: const Icon(Icons.stop_rounded),
                  label: const Text('إنهاء'),
                ),
            ],
          ),
          const SizedBox(height: 22),
          const Text('المهمة', style: TextStyle(color: kMuted, fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: kCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kLine),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                dropdownColor: kCard2,
                value: taskItems.any((e) => e.value == taskId) ? taskId : '',
                items: taskItems,
                onChanged: running ? null : (v) => setState(() => taskId = v ?? ''),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text('مدّة التركيز (دقيقة)', style: TextStyle(color: kMuted, fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final m in const [15, 25, 45, 50, 90])
                ChoiceChip(
                  label: Text('$m'),
                  selected: store.settings.focusWork == m,
                  onSelected: running
                      ? null
                      : (_) {
                          store.updateSettings((s) => s.focusWork = m);
                          if (work) setState(() => _resetTimes(store));
                        },
                ),
            ],
          ),
          const SizedBox(height: 14),
          const Text('الاستراحة (دقيقة)', style: TextStyle(color: kMuted, fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final m in const [5, 10, 15, 20])
                ChoiceChip(
                  label: Text('$m'),
                  selected: store.settings.focusBreak == m,
                  onSelected: running
                      ? null
                      : (_) {
                          store.updateSettings((s) => s.focusBreak = m);
                          if (!work) setState(() => _resetTimes(store));
                        },
                ),
            ],
          ),
          const SectionTitle('إحصائيات التركيز'),
          TwoColumn(children: [
            StatTile(emoji: '🍅', label: 'تركيز اليوم', value: fmtMinutes(todayMin.toDouble()), sub: 'جلسات هذه الجلسة: $sessions'),
            StatTile(emoji: '📅', label: 'آخر 7 أيام', value: fmtMinutes(weekTotal), color: kGold),
          ]),
          AppCard(child: MiniBars(values: bars, labels: labels, color: kEmerald, height: 110)),
        ],
      ),
    );
  }
}
