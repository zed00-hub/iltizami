import 'package:flutter/material.dart';
import 'models.dart';
import 'models_ext.dart';
import 'planning.dart';
import 'screen_focus.dart';
import 'stats.dart';
import 'store.dart';
import 'ui_common.dart';
import 'util.dart';

Future<void> showTaskEditor(
  BuildContext context, {
  Task? task,
  PeriodType? level,
  int? anchor,
  String? parentId,
  String? title,
}) {
  return Navigator.of(context).push(MaterialPageRoute<void>(
    fullscreenDialog: true,
    builder: (_) => TaskEditorPage(
      task: task,
      level: level,
      anchor: anchor,
      parentId: parentId,
      title: title,
    ),
  ));
}

// ═════════════════════════ شاشة الخطط ═════════════════════════

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  PeriodType level = PeriodType.day;
  int offset = 0;
  int view = 0; // 0 قائمة، 1 مصفوفة أيزنهاور
  String? cat;

  int _sortKey(Task t, List<Task> all) {
    final done = taskIsDone(t, all) ? 10 : 0;
    final q = t.quadrant == 0 ? 5 : t.quadrant;
    return done + q;
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final ws = store.settings.weekStart;
    final today = todayNum();
    final all = store.tasks;
    final key = shiftedKey(level, ws, today, offset);

    final cats = <String>{};
    for (final t in all) {
      if (t.category.isNotEmpty) cats.add(t.category);
    }
    if (cat != null && !cats.contains(cat)) cat = null;

    bool catOk(Task t) => cat == null || t.category == cat;
    final inPeriod = all.where((t) => t.level == level && taskKey(t, ws) == key && catOk(t)).toList()
      ..sort((a, b) => _sortKey(a, all).compareTo(_sortKey(b, all)));
    final overdue = offset == 0
        ? (all
            .where((t) => t.level == level && taskKey(t, ws) < key && taskOverdue(t, all, ws, today) && catOk(t))
            .toList()
          ..sort((a, b) => a.anchor.compareTo(b.anchor)))
        : <Task>[];

    final doneCount = inPeriod.where((t) => taskIsDone(t, all)).length;
    final total = inPeriod.length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'idea_fab',
            backgroundColor: kCard2,
            foregroundColor: kGold,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const IdeasScreen()),
            ),
            child: const Text('💡', style: TextStyle(fontSize: 18)),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'task_fab',
            backgroundColor: kEmerald,
            foregroundColor: Colors.black,
            onPressed: () => showTaskEditor(
              context,
              level: level,
              anchor: anchorForKey(level, ws, today, key),
            ),
            icon: const Icon(Icons.add_rounded),
            label: const Text('مهمة جديدة', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 150),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 12),
            child: Row(
              children: [
                const Expanded(
                  child: Text('الخطط والمهام',
                      style: TextStyle(color: kText, fontSize: 26, fontWeight: FontWeight.w900)),
                ),
                if (store.ideas.isNotEmpty)
                  Text('💡 ${store.ideas.length}', style: const TextStyle(color: kGold, fontSize: 14)),
              ],
            ),
          ),
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
              selected: {level},
              onSelectionChanged: (s) => setState(() {
                level = s.first;
                offset = 0;
              }),
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => setState(() => offset--),
                  icon: const Icon(Icons.chevron_right_rounded, color: kText),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: offset == 0 ? null : () => setState(() => offset = 0),
                    child: Column(
                      children: [
                        Text(periodTitle(level, key, ws, today),
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: kText, fontSize: 15, fontWeight: FontWeight.w800)),
                        if (offset != 0)
                          const Text('اضغط للعودة للفترة الحالية',
                              style: TextStyle(color: kEmerald, fontSize: 11)),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => offset++),
                  icon: const Icon(Icons.chevron_left_rounded, color: kText),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Ring(
                progress: total == 0 ? 0 : doneCount / total,
                color: kEmerald,
                size: 54,
                stroke: 6,
                child: Text('$doneCount/$total',
                    style: const TextStyle(color: kText, fontSize: 12, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SegmentedButton<int>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: 0, label: Text('قائمة'), icon: Icon(Icons.view_list_rounded)),
                    ButtonSegment(value: 1, label: Text('أيزنهاور'), icon: Icon(Icons.grid_view_rounded)),
                  ],
                  selected: {view},
                  onSelectionChanged: (s) => setState(() => view = s.first),
                ),
              ),
            ],
          ),
          if (cats.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: ChoiceChip(
                      label: const Text('كل التصنيفات'),
                      selected: cat == null,
                      onSelected: (_) => setState(() => cat = null),
                    ),
                  ),
                  for (final c in cats)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: ChoiceChip(
                        label: Text(c),
                        selected: cat == c,
                        onSelected: (_) => setState(() => cat = cat == c ? null : c),
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (overdue.isNotEmpty) ...[
            SectionTitle('متأخرة', trailing: Text('${overdue.length}', style: const TextStyle(color: kDanger))),
            for (final t in overdue) Padding(padding: const EdgeInsets.only(bottom: 8), child: TaskTile(task: t)),
          ],
          if (view == 0) ...[
            SectionTitle('مهام ${levelWord(level)}'),
            if (inPeriod.isEmpty) _empty() else
              for (final t in inPeriod) Padding(padding: const EdgeInsets.only(bottom: 8), child: TaskTile(task: t)),
          ] else
            ..._matrix(inPeriod, all),
        ],
      ),
    );
  }

  Widget _empty() => const AppCard(
        child: Column(
          children: [
            Text('📝', style: TextStyle(fontSize: 36)),
            SizedBox(height: 6),
            Text('لا مهام في هذه الفترة بعد. اضغط "مهمة جديدة" لتخطّط.',
                textAlign: TextAlign.center, style: TextStyle(color: kMuted, height: 1.6)),
          ],
        ),
      );

  List<Widget> _matrix(List<Task> inPeriod, List<Task> all) {
    Widget quad(int q) {
      final list = inPeriod.where((t) => t.quadrant == q).toList();
      final c = kQuadColors[q];
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: a(c, 0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: a(c, 0.55)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(kQuadNames[q], style: TextStyle(color: c, fontSize: 14.5, fontWeight: FontWeight.w900)),
            Text(kQuadSub[q], style: const TextStyle(color: kMuted, fontSize: 10.5)),
            const SizedBox(height: 8),
            if (list.isEmpty)
              const Text('—', style: TextStyle(color: kMuted))
            else
              for (final t in list) TaskTile(task: t, compact: true),
          ],
        ),
      );
    }

    final none = inPeriod.where((t) => t.quadrant == 0).toList();
    return [
      const SectionTitle('مصفوفة أيزنهاور'),
      IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [Expanded(child: quad(2)), const SizedBox(width: 8), Expanded(child: quad(1))],
        ),
      ),
      const SizedBox(height: 8),
      IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [Expanded(child: quad(4)), const SizedBox(width: 8), Expanded(child: quad(3))],
        ),
      ),
      if (none.isNotEmpty) ...[
        const SectionTitle('بدون تصنيف'),
        for (final t in none) Padding(padding: const EdgeInsets.only(bottom: 8), child: TaskTile(task: t)),
      ],
      const Padding(
        padding: EdgeInsets.only(top: 8, right: 4),
        child: Text('لنقل مهمة إلى ربع آخر: افتحها وعدّل تصنيف الأولوية.',
            style: TextStyle(color: kMuted, fontSize: 11.5)),
      ),
    ];
  }
}

// ═════════════════════════ بطاقة المهمة ═════════════════════════

class TaskTile extends StatelessWidget {
  final Task task;
  final bool compact;
  const TaskTile({super.key, required this.task, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final all = store.tasks;
    final ws = store.settings.weekStart;
    final today = todayNum();
    final done = taskIsDone(task, all);
    final prog = taskProgress(task, all);
    final kids = kidsOf(task, all);
    final parent = task.parentId == null ? null : store.taskById(task.parentId!);
    final overdue = taskOverdue(task, all, ws, today);
    final qc = kQuadColors[task.quadrant];
    final auto = task.byChildren && kids.isNotEmpty;

    void toggle() {
      if (auto) {
        toast(context, 'تقدّم هذه الخطة يُحسب من المهام التي تحتها');
        return;
      }
      store.toggleTask(task);
    }

    final box = GestureDetector(
      onTap: toggle,
      child: Container(
        width: compact ? 22 : 28,
        height: compact ? 22 : 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: done ? kEmerald : Colors.transparent,
          border: Border.all(color: done ? kEmerald : (task.quadrant > 0 ? qc : kLine), width: 2),
        ),
        child: done ? Icon(Icons.check_rounded, size: compact ? 15 : 19, color: Colors.black) : null,
      ),
    );

    final title = Text(task.title,
        maxLines: compact ? 2 : 3,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: done ? kMuted : kText,
          fontSize: compact ? 13 : 15.5,
          fontWeight: FontWeight.w700,
          decoration: done ? TextDecoration.lineThrough : null,
        ));

    if (compact) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: InkWell(
          onTap: () => showTaskEditor(context, task: task),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [box, const SizedBox(width: 8), Expanded(child: title)],
          ),
        ),
      );
    }

    final chips = <Widget>[];
    if (task.quadrant > 0) chips.add(MiniChipX(kQuadNames[task.quadrant], qc));
    if (task.category.isNotEmpty) chips.add(MiniChipX('# ${task.category}', kMuted));
    if (task.repeat != 0) chips.add(MiniChipX('🔁 ${repeatWord(task.repeat)}', kMuted));
    if (task.remind >= 0 && task.level == PeriodType.day) chips.add(MiniChipX('⏰ ${fmtClock(task.remind)}', kGold));
    if (task.focusMin > 0) chips.add(MiniChipX('🍅 ${task.focusMin} د', kMuted));
    if (parent != null) chips.add(MiniChipX('↑ ${parent.title}', kEmerald));
    if (kids.isNotEmpty) {
      final d = kids.where((k) => taskIsDone(k, all)).length;
      chips.add(MiniChipX('${kids.length} تحتها • $d منجزة', kGold));
    }
    if (overdue) chips.add(const MiniChipX('متأخرة', kDanger));

    return AppCard(
      padding: const EdgeInsets.fromLTRB(12, 12, 6, 12),
      borderColor: overdue ? a(kDanger, 0.5) : (done ? a(kEmerald, 0.35) : kLine),
      onTap: () => showTaskEditor(context, task: task),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              box,
              const SizedBox(width: 12),
              Expanded(child: Padding(padding: const EdgeInsets.only(top: 3), child: title)),
              PopupMenuButton<String>(
                color: kCard2,
                icon: const Icon(Icons.more_vert_rounded, color: kMuted, size: 20),
                onSelected: (v) async {
                  if (v == 'edit') {
                    showTaskEditor(context, task: task);
                  } else if (v == 'focus') {
                    Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => FocusScreen(taskId: task.id),
                    ));
                  } else if (v == 'sub') {
                    final lower = PeriodType.values[task.level.index > 0 ? task.level.index - 1 : 0];
                    showTaskEditor(context, level: lower, anchor: taskAnchorForChild(task, lower, ws, today), parentId: task.id);
                  } else if (v == 'delete') {
                    final ok = await confirmDialog(context, 'حذف المهمة؟', 'ستُحذف "${task.title}" نهائيًا.',
                        ok: 'حذف', danger: true);
                    if (ok) store.deleteTask(task);
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('تعديل')),
                  const PopupMenuItem(value: 'focus', child: Text('🍅 ابدأ تركيزًا')),
                  if (task.level != PeriodType.day)
                    const PopupMenuItem(value: 'sub', child: Text('إضافة مهمة تحتها')),
                  const PopupMenuItem(value: 'delete', child: Text('حذف', style: TextStyle(color: kDanger))),
                ],
              ),
            ],
          ),
          if (chips.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8, right: 40),
              child: Wrap(spacing: 6, runSpacing: 6, children: chips),
            ),
          if (task.subs.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8, right: 40),
              child: Column(
                children: [
                  for (int i = 0; i < task.subs.length; i++)
                    InkWell(
                      onTap: () => store.toggleSub(task, i),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            Icon(task.subs[i].done ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                                size: 19, color: task.subs[i].done ? kEmerald : kMuted),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(task.subs[i].t,
                                  style: TextStyle(
                                    color: task.subs[i].done ? kMuted : kText,
                                    fontSize: 13,
                                    decoration: task.subs[i].done ? TextDecoration.lineThrough : null,
                                  )),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          if (prog > 0 && prog < 1 && (kids.isNotEmpty || task.subs.isNotEmpty))
            Padding(
              padding: const EdgeInsets.only(top: 8, right: 40, left: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: LinearProgressIndicator(
                  value: prog,
                  minHeight: 5,
                  backgroundColor: a(kEmerald, 0.14),
                  valueColor: const AlwaysStoppedAnimation<Color>(kEmerald),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// يوم مناسب لمهمة فرعية داخل فترة الأب
int taskAnchorForChild(Task parent, PeriodType childLevel, int ws, int today) {
  final pc = PeriodCalc(parent.level, ws);
  final key = pc.keyOf(parent.anchor);
  final start = pc.startOf(key);
  final end = pc.endOf(key);
  if (today >= start && today <= end) return today;
  return start;
}

class MiniChipX extends StatelessWidget {
  final String text;
  final Color color;
  const MiniChipX(this.text, this.color, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: a(color, 0.13), borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

// ═════════════════════════ محرّر المهمة ═════════════════════════

class TaskEditorPage extends StatefulWidget {
  final Task? task;
  final PeriodType? level;
  final int? anchor;
  final String? parentId;
  final String? title;
  const TaskEditorPage({super.key, this.task, this.level, this.anchor, this.parentId, this.title});

  @override
  State<TaskEditorPage> createState() => _TaskEditorPageState();
}

class _TaskEditorPageState extends State<TaskEditorPage> {
  final _title = TextEditingController();
  final _notes = TextEditingController();
  final _cat = TextEditingController();
  final _newSub = TextEditingController();
  PeriodType level = PeriodType.day;
  int anchor = todayNum();
  int quadrant = 0;
  String parentId = '';
  bool byChildren = false;
  int repeat = 0;
  List<SubTask> subs = [];
  bool remindOn = false;
  int remindMin = 480;

  bool get editing => widget.task != null;

  @override
  void initState() {
    super.initState();
    final t = widget.task;
    if (t != null) {
      _title.text = t.title;
      _notes.text = t.notes;
      _cat.text = t.category;
      level = t.level;
      anchor = t.anchor;
      quadrant = t.quadrant;
      parentId = t.parentId ?? '';
      byChildren = t.byChildren;
      repeat = t.repeat;
      subs = t.subs.map((s) => SubTask(s.t, done: s.done)).toList();
      remindOn = t.remind >= 0;
      remindMin = t.remind >= 0 ? t.remind : 480;
    } else {
      level = widget.level ?? PeriodType.day;
      anchor = widget.anchor ?? todayNum();
      parentId = widget.parentId ?? '';
      _title.text = widget.title ?? '';
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    _cat.dispose();
    _newSub.dispose();
    super.dispose();
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

  void _save() {
    final name = _title.text.trim();
    if (name.isEmpty) {
      toast(context, 'اكتب عنوان المهمة');
      return;
    }
    final store = StoreScope.of(context);
    final pend = _newSub.text.trim();
    if (pend.isNotEmpty) subs.add(SubTask(pend));
    final rem = (remindOn && level == PeriodType.day) ? remindMin : -1;
    final pid = (level == PeriodType.year || parentId.isEmpty) ? null : parentId;
    final t = widget.task;
    if (t != null) {
      t.title = name;
      t.notes = _notes.text.trim();
      t.category = _cat.text.trim();
      t.level = level;
      t.anchor = anchor;
      t.quadrant = quadrant;
      t.parentId = pid;
      t.byChildren = byChildren;
      t.repeat = repeat;
      t.subs = subs;
      t.remind = rem;
      if (subs.isNotEmpty && subs.every((s) => s.done)) {
        t.done = true;
        if (t.doneDay == 0) t.doneDay = todayNum();
      }
      store.save();
    } else {
      store.addTask(Task(
        id: store.newId(),
        title: name,
        level: level,
        anchor: anchor,
        parentId: pid,
        byChildren: byChildren,
        quadrant: quadrant,
        category: _cat.text.trim(),
        notes: _notes.text.trim(),
        repeat: repeat,
        subs: subs,
        createdDay: todayNum(),
        remind: rem,
      ));
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final ws = store.settings.weekStart;
    final today = todayNum();
    final cands = parentCandidates(store.tasks, level, widget.task?.id);
    if (parentId.isNotEmpty && !cands.any((t) => t.id == parentId)) {
      // الأب الحالي لم يعد صالحًا لهذا المستوى
      final current = store.taskById(parentId);
      if (current == null || current.level.index <= level.index) parentId = '';
    }
    final parentItems = <DropdownMenuItem<String>>[
      const DropdownMenuItem(value: '', child: Text('بدون (مستقلة)')),
      for (final c in cands)
        DropdownMenuItem(
          value: c.id,
          child: Text('${levelWord(c.level)}: ${c.title}', overflow: TextOverflow.ellipsis),
        ),
    ];
    if (parentId.isNotEmpty && !cands.any((t) => t.id == parentId)) {
      final cur = store.taskById(parentId);
      if (cur != null) {
        parentItems.add(DropdownMenuItem(
          value: cur.id,
          child: Text('${levelWord(cur.level)}: ${cur.title}', overflow: TextOverflow.ellipsis),
        ));
      }
    }
    final cats = <String>{};
    for (final t in store.tasks) {
      if (t.category.isNotEmpty) cats.add(t.category);
    }
    final hasKids = editing && store.childrenOfTask(widget.task!.id).isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'تعديل المهمة' : 'مهمة جديدة'),
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
          _label('العنوان'),
          TextField(
            controller: _title,
            autofocus: !editing,
            style: const TextStyle(color: kText, fontSize: 17),
            decoration: _dec('مثال: إنهاء مراجعة الفصل الأول'),
          ),
          _label('المستوى'),
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
              selected: {level},
              onSelectionChanged: (s) => setState(() => level = s.first),
            ),
          ),
          _label('الفترة'),
          OutlinedButton.icon(
            onPressed: () async {
              final d = dateOf(anchor);
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime(d.year, d.month, d.day),
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (picked != null) setState(() => anchor = dayOf(picked));
            },
            icon: const Icon(Icons.event_rounded),
            label: Text(periodTitle(level, PeriodCalc(level, ws).keyOf(anchor), ws, today)),
          ),
          if (level == PeriodType.day) ...[
            const SizedBox(height: 6),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeColor: kEmerald,
              title: const Text('تذكير بالمهمة', style: TextStyle(color: kText)),
              subtitle: remindOn
                  ? Text('الساعة ${fmtClock(remindMin)}', style: const TextStyle(color: kGold))
                  : null,
              value: remindOn,
              onChanged: (v) async {
                if (v) {
                  final t = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay(hour: remindMin ~/ 60, minute: remindMin % 60),
                  );
                  if (t == null) return;
                  setState(() {
                    remindMin = t.hour * 60 + t.minute;
                    remindOn = true;
                  });
                } else {
                  setState(() => remindOn = false);
                }
              },
            ),
          ],
          _label('الأولوية (مصفوفة أيزنهاور)'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (int q = 0; q < 5; q++)
                ChoiceChip(
                  label: Text(q == 0 ? 'بدون' : '${kQuadNames[q]} • ${kQuadSub[q]}'),
                  selected: quadrant == q,
                  selectedColor: a(kQuadColors[q], 0.25),
                  onSelected: (_) => setState(() => quadrant = q),
                ),
            ],
          ),
          _label('التصنيف (اختياري)'),
          TextField(
            controller: _cat,
            style: const TextStyle(color: kText, fontSize: 16),
            decoration: _dec('مثال: دراسة، عمل، صحة'),
          ),
          if (cats.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 8,
                children: [
                  for (final c in cats)
                    ActionChip(label: Text(c), onPressed: () => setState(() => _cat.text = c)),
                ],
              ),
            ),
          if (level != PeriodType.year) ...[
            _label('تتبع خطة أكبر (اختياري)'),
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
                  value: parentItems.any((e) => e.value == parentId) ? parentId : '',
                  items: parentItems,
                  onChanged: (v) => setState(() => parentId = v ?? ''),
                ),
              ),
            ),
          ],
          if (hasKids || level != PeriodType.day) ...[
            const SizedBox(height: 6),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeColor: kEmerald,
              title: const Text('تقدّمها يتأثر بالمهام التي تحتها', style: TextStyle(color: kText)),
              subtitle: const Text(
                'مفعّل: تُحسب نسبة إنجازها وتكتمل تلقائيًا من المهام المرتبطة بها. معطّل: تُنجزها يدويًا مستقلةً عنها.',
                style: TextStyle(color: kMuted, fontSize: 12, height: 1.5),
              ),
              value: byChildren,
              onChanged: (v) => setState(() => byChildren = v),
            ),
          ],
          _label('مهام فرعية (قائمة تحقق)'),
          for (int i = 0; i < subs.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Checkbox(
                    value: subs[i].done,
                    activeColor: kEmerald,
                    onChanged: (v) => setState(() => subs[i].done = v ?? false),
                  ),
                  Expanded(child: Text(subs[i].t, style: const TextStyle(color: kText))),
                  IconButton(
                    onPressed: () => setState(() => subs.removeAt(i)),
                    icon: const Icon(Icons.close_rounded, color: kMuted, size: 20),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _newSub,
                  style: const TextStyle(color: kText),
                  decoration: _dec('أضف بندًا'),
                  onSubmitted: (v) {
                    final t = v.trim();
                    if (t.isEmpty) return;
                    setState(() {
                      subs.add(SubTask(t));
                      _newSub.clear();
                    });
                  },
                ),
              ),
              IconButton.filled(
                onPressed: () {
                  final t = _newSub.text.trim();
                  if (t.isEmpty) return;
                  setState(() {
                    subs.add(SubTask(t));
                    _newSub.clear();
                  });
                },
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
          _label('التكرار'),
          Wrap(
            spacing: 8,
            children: [
              for (int r = 0; r < 4; r++)
                ChoiceChip(
                  label: Text(r == 0 ? 'بدون' : repeatWord(r).replaceFirst('تتكرر ', '')),
                  selected: repeat == r,
                  onSelected: (_) => setState(() => repeat = r),
                ),
            ],
          ),
          if (repeat != 0)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('عند إنجازها تُنشأ نسختها القادمة تلقائيًا.',
                  style: TextStyle(color: kMuted, fontSize: 12)),
            ),
          _label('ملاحظات'),
          TextField(
            controller: _notes,
            maxLines: 3,
            style: const TextStyle(color: kText),
            decoration: _dec('تفاصيل إضافية'),
          ),
          const SizedBox(height: 26),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: kEmerald,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            ),
            onPressed: _save,
            child: Text(editing ? 'حفظ التعديلات' : 'إضافة المهمة',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════ صندوق الأفكار ═════════════════════════

class IdeasScreen extends StatefulWidget {
  const IdeasScreen({super.key});

  @override
  State<IdeasScreen> createState() => _IdeasScreenState();
}

class _IdeasScreenState extends State<IdeasScreen> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _add(AppStore store) {
    if (_ctrl.text.trim().isEmpty) return;
    store.addIdea(_ctrl.text);
    _ctrl.clear();
  }

  Future<void> _convert(BuildContext context, AppStore store, Idea idea) async {
    final lv = await showModalBottomSheet<PeriodType>(
      context: context,
      backgroundColor: kSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('حوّلها إلى مهمة', style: TextStyle(color: kText, fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              for (final p in [PeriodType.day, PeriodType.week, PeriodType.month, PeriodType.year])
                ListTile(
                  title: Text('مهمة ${levelWord(p)}', style: const TextStyle(color: kText)),
                  onTap: () => Navigator.pop(ctx, p),
                ),
            ],
          ),
        ),
      ),
    );
    if (lv == null || !context.mounted) return;
    final ws = store.settings.weekStart;
    final today = todayNum();
    final key = shiftedKey(lv, ws, today, 0);
    store.addTask(Task(
      id: store.newId(),
      title: idea.text,
      level: lv,
      anchor: anchorForKey(lv, ws, today, key),
      createdDay: today,
    ));
    store.deleteIdea(idea);
    toast(context, 'أُضيفت إلى مهام ${levelWord(lv)} ✓');
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('💡 صندوق الأفكار')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  autofocus: true,
                  style: const TextStyle(color: kText, fontSize: 16),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _add(store),
                  decoration: InputDecoration(
                    hintText: 'اكتب الفكرة بسرعة...',
                    hintStyle: const TextStyle(color: kMuted),
                    filled: true,
                    fillColor: kCard,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: kLine)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(onPressed: () => _add(store), icon: const Icon(Icons.add_rounded)),
            ],
          ),
          const SizedBox(height: 16),
          if (store.ideas.isEmpty)
            const Padding(
              padding: EdgeInsets.all(30),
              child: Text('لا أفكار بعد. دوّن كل فكرة تخطر ببالك ثم صنّفها لاحقًا.',
                  textAlign: TextAlign.center, style: TextStyle(color: kMuted, height: 1.6)),
            ),
          for (final i in store.ideas)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
                child: Row(
                  children: [
                    Expanded(child: Text(i.text, style: const TextStyle(color: kText, fontSize: 15, height: 1.5))),
                    IconButton(
                      tooltip: 'حوّلها لمهمة',
                      onPressed: () => _convert(context, store, i),
                      icon: const Icon(Icons.task_alt_rounded, color: kEmerald),
                    ),
                    IconButton(
                      tooltip: 'حذف',
                      onPressed: () => store.deleteIdea(i),
                      icon: const Icon(Icons.delete_outline_rounded, color: kMuted),
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
