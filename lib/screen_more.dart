import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'habit_widgets.dart';
import 'notifications.dart';
import 'screen_focus.dart';
import 'screen_habit.dart';
import 'screen_lock.dart';
import 'screen_meds.dart';
import 'screen_review.dart';
import 'screen_tasks.dart';
import 'screen_tracking.dart';
import 'stats.dart';
import 'store.dart';
import 'ui_common.dart';
import 'util.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  void _open(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  Widget _tile(BuildContext context, String emoji, String title, String sub, Widget page) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      onTap: () => _open(context, page),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(color: kText, fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(sub, style: const TextStyle(color: kMuted, fontSize: 11.5, height: 1.4)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final s = store.settings;
    final all = store.allStats();
    int xp = 0;
    for (final h in store.habits) {
      final st = all[h.id];
      if (st != null) xp += xpOf(h, st);
    }
    final lvl = levelFor(xp);
    final badges = computeBadges(store.habits, all);
    final earned = badges.where((b) => b.earned).length;
    final archived = store.archived;
    final today = todayNum();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 110),
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 6, 4, 10),
          child: Text('المزيد', style: TextStyle(color: kText, fontSize: 26, fontWeight: FontWeight.w900)),
        ),

        // ── المستوى
        AppCard(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [a(kGold, 0.2), kCard],
          ),
          borderColor: a(kGold, 0.4),
          child: Column(
            children: [
              const Text('🛡️', style: TextStyle(fontSize: 42)),
              const SizedBox(height: 4),
              Text(lvl.title, style: const TextStyle(color: kGold, fontSize: 24, fontWeight: FontWeight.w900)),
              Text('المستوى ${lvl.level}  •  ${lvl.xp} XP', style: const TextStyle(color: kText, fontSize: 14)),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: LinearProgressIndicator(
                  value: lvl.progress,
                  minHeight: 9,
                  backgroundColor: a(kGold, 0.15),
                  valueColor: const AlwaysStoppedAnimation<Color>(kGold),
                ),
              ),
              const SizedBox(height: 6),
              Text('${lvl.into} / ${lvl.span} XP للمستوى التالي',
                  style: const TextStyle(color: kMuted, fontSize: 12)),
            ],
          ),
        ),

        // ── الأدوات
        const SectionTitle('أدواتك'),
        TwoColumn(children: [
          _tile(context, '💊', 'الأدوية', 'جرعات متعددة، مخزون، مدة علاج، تأجيل', const MedsScreen()),
          _tile(context, '📏', 'قياساتي', 'قياسات تسمّيها أنت ومنحنياتها', const MetricsScreen()),
          _tile(context, '📝', 'يومية المزاج', 'مزاجك وتأمّلك وعلاقتهما بالتزامك', const JournalScreen()),
          _tile(context, '🚫', 'عادات للترك', 'عدّاد أيام نظيفة وأطول فترة', const QuitScreen()),
          _tile(context, '📖', 'ختمة القرآن', 'صفحاتك وإيقاعك وموعد ختمك', const KhatmaScreen()),
          _tile(context, '🍅', 'مؤقت التركيز', 'جلسات بومودورو مرتبطة بمهامك', const FocusScreen()),
          _tile(context, '🗓️', 'مراجعة الأسبوع', 'ملخّص تلقائي وتأمّل', const ReviewScreen()),
          _tile(context, '💡', 'صندوق الأفكار', 'دوّن بسرعة وصنّف لاحقًا', const IdeasScreen()),
        ]),

        // ── الأوسمة
        SectionTitle('الأوسمة', trailing: Text('$earned / ${badges.length}', style: const TextStyle(color: kMuted))),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.95,
          children: [
            for (final b in badges)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: b.earned ? a(kGold, 0.1) : kCard,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: b.earned ? a(kGold, 0.5) : kLine),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Opacity(opacity: b.earned ? 1 : 0.28, child: Text(b.emoji, style: const TextStyle(fontSize: 30))),
                    const SizedBox(height: 5),
                    Text(b.title,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: b.earned ? kText : kMuted, fontSize: 12.5, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(b.desc,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: kMuted, fontSize: 10, height: 1.3)),
                  ],
                ),
              ),
          ],
        ),

        // ── الإعدادات
        const SectionTitle('الإعدادات'),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('أول يوم في الأسبوع', style: TextStyle(color: kText, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              const Text('يحدد بداية الأسبوع في الأهداف والخطط الأسبوعية',
                  style: TextStyle(color: kMuted, fontSize: 12)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [
                  for (final w in const [6, 7, 1])
                    ChoiceChip(
                      label: Text(kWeekdaysAr[w - 1]),
                      selected: s.weekStart == w,
                      onSelected: (_) => store.updateSettings((x) => x.weekStart = w),
                    ),
                ],
              ),
              const Divider(color: kLine, height: 28),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: kEmerald,
                title: const Text('حماية السلسلة', style: TextStyle(color: kText)),
                subtitle: const Text('تنبيه 9:30 مساءً إن لم تنجز عادة سلسلتها 3 أيام أو أكثر',
                    style: TextStyle(color: kMuted, fontSize: 12)),
                value: s.streakGuard,
                onChanged: (v) async {
                  if (v) await NotificationService.requestPermission();
                  store.updateSettings((x) => x.streakGuard = v);
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: kEmerald,
                title: const Text('تنبيه المراجعة الأسبوعية', style: TextStyle(color: kText)),
                subtitle: const Text('كل جمعة 8 مساءً', style: TextStyle(color: kMuted, fontSize: 12)),
                value: s.weekReview,
                onChanged: (v) async {
                  if (v) await NotificationService.requestPermission();
                  store.updateSettings((x) => x.weekReview = v);
                },
              ),
            ],
          ),
        ),

        // ── الإجازة
        const SectionTitle('وضع الإجازة / المرض'),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'خلال الإجازة تُجمَّد السلاسل اليومية فلا تنكسر ولا تزيد، وتتوقف تذكيراتها. الصرامة تبقى كاملة في الأيام العادية.',
                style: TextStyle(color: kMuted, fontSize: 12.5, height: 1.6),
              ),
              for (int i = 0; i < s.vacations.length; i++)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Icon(Icons.beach_access_rounded,
                          color: (today >= s.vacations[i][0] && today <= s.vacations[i][1]) ? kEmerald : kMuted,
                          size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('${fmtShort(s.vacations[i][0])} ← ${fmtShort(s.vacations[i][1])}',
                            style: const TextStyle(color: kText, fontWeight: FontWeight.w700)),
                      ),
                      if (today >= s.vacations[i][0] && today <= s.vacations[i][1])
                        const MiniChip('فعّالة الآن', color: kEmerald),
                      IconButton(
                        onPressed: () => store.updateSettings((x) => x.vacations.removeAt(i)),
                        icon: const Icon(Icons.close_rounded, color: kMuted, size: 18),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () async {
                  final now = DateTime.now();
                  final r = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(now.year - 1),
                    lastDate: now.add(const Duration(days: 730)),
                    initialDateRange: DateTimeRange(start: now, end: now.add(const Duration(days: 3))),
                  );
                  if (r != null) {
                    store.updateSettings((x) => x.vacations.add([dayOf(r.start), dayOf(r.end)]));
                  }
                },
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('إضافة فترة إجازة'),
              ),
            ],
          ),
        ),

        // ── القفل
        const SectionTitle('قفل التطبيق'),
        AppCard(
          child: s.pinHash == null
              ? Row(
                  children: [
                    const Expanded(
                      child: Text('احمِ بياناتك برمز من 4 أرقام يُطلب عند فتح التطبيق.',
                          style: TextStyle(color: kMuted, fontSize: 12.5, height: 1.6)),
                    ),
                    FilledButton(
                      onPressed: () => _open(context, const PinFlowPage(mode: PinMode.set)),
                      child: const Text('تفعيل'),
                    ),
                  ],
                )
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: () => _open(context, const PinFlowPage(mode: PinMode.change)),
                      child: const Text('تغيير الرمز'),
                    ),
                    OutlinedButton(
                      onPressed: () => _open(context, const PinFlowPage(mode: PinMode.remove)),
                      child: const Text('إزالة القفل', style: TextStyle(color: kDanger)),
                    ),
                    FilledButton(
                      onPressed: store.lockNow,
                      child: const Text('اقفل الآن'),
                    ),
                  ],
                ),
        ),

        // ── الأرشيف
        if (archived.isNotEmpty) ...[
          SectionTitle('أرشيف العادات', trailing: Text('${archived.length}', style: const TextStyle(color: kMuted))),
          for (final h in archived)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                onTap: () => _open(context, HabitDetailScreen(habitId: h.id)),
                child: Row(
                  children: [
                    Text(h.emoji, style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 10),
                    Expanded(child: Text(h.name, style: const TextStyle(color: kMuted, fontWeight: FontWeight.w700))),
                    TextButton(
                      onPressed: () => store.setArchived(h, false),
                      child: const Text('استعادة', style: TextStyle(color: kEmerald)),
                    ),
                  ],
                ),
              ),
            ),
        ],

        // ── النسخ الاحتياطي والتقارير
        const SectionTitle('النسخ الاحتياطي والتقارير'),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'بياناتك محفوظة على هاتفك فقط. انسخها إلى مكان آمن (رسائل محفوظة أو ملاحظات) لتستعيدها عند تغيير الهاتف أو حذف التطبيق.',
                style: TextStyle(color: kMuted, fontSize: 12.5, height: 1.6),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: store.exportJson()));
                        if (context.mounted) toast(context, 'نُسخت بياناتك إلى الحافظة ✓');
                      },
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: const Text('نسخ'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _import(context, store),
                      icon: const Icon(Icons.download_rounded, size: 18),
                      label: const Text('استعادة'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => showReportSheet(context),
                  icon: const Icon(Icons.summarize_rounded, size: 18),
                  label: const Text('تصدير تقرير'),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 26),
        const Center(
          child: Text('التزام 🛡️  •  الإصدار 2.0', style: TextStyle(color: kMuted, fontSize: 12)),
        ),
      ],
    );
  }

  Future<void> _import(BuildContext context, AppStore store) async {
    final ctrl = TextEditingController();
    final clip = await Clipboard.getData('text/plain');
    final clipText = clip?.text ?? '';
    if (clipText.contains('"habits"')) ctrl.text = clipText;
    if (!context.mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCard,
        title: const Text('استعادة نسخة', style: TextStyle(color: kText, fontSize: 17)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('الصق النسخة الاحتياطية هنا. سيحلّ ذلك محل البيانات الحالية.',
                style: TextStyle(color: kMuted, fontSize: 12.5, height: 1.5)),
            const SizedBox(height: 10),
            TextField(
              controller: ctrl,
              maxLines: 5,
              style: const TextStyle(color: kText, fontSize: 12),
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                filled: true,
                fillColor: kCard2,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء', style: TextStyle(color: kMuted))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kDanger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('استبدال', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
    final text = ctrl.text;
    ctrl.dispose();
    if (ok != true) return;
    final err = store.importJson(text);
    if (context.mounted) toast(context, err ?? 'تمت الاستعادة بنجاح ✓');
  }
}
