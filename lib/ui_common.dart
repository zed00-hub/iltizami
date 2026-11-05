import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'util.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color? borderColor;
  final Gradient? gradient;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.onLongPress,
    this.borderColor,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(22);
    return Container(
      decoration: BoxDecoration(
        color: gradient == null ? kCard : null,
        gradient: gradient,
        borderRadius: radius,
        border: Border.all(color: borderColor ?? kLine, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionTitle(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(color: kGold, borderRadius: BorderRadius.circular(4)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(color: kText, fontSize: 17, fontWeight: FontWeight.w800)),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double stroke;
  RingPainter(this.progress, this.color, this.stroke);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset(stroke / 2, stroke / 2) &
        Size(size.width - stroke, size.height - stroke);
    final bg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = a(color, 0.16);
    final fg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(rect, 0, math.pi * 2, false, bg);
    final p = clampD(progress, 0.0, 1.0);
    if (p > 0) {
      canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * p, false, fg);
    }
  }

  @override
  bool shouldRepaint(covariant RingPainter old) =>
      old.progress != progress || old.color != color || old.stroke != stroke;
}

class Ring extends StatelessWidget {
  final double progress;
  final Color color;
  final double size;
  final double stroke;
  final Widget? child;
  const Ring({
    super.key,
    required this.progress,
    required this.color,
    this.size = 64,
    this.stroke = 7,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: RingPainter(progress, color, stroke),
        child: Center(child: child),
      ),
    );
  }
}

/// خريطة حرارية (الأقدم على اليمين في الواجهة العربية)
class Heatmap extends StatelessWidget {
  final Map<int, double> intensity;
  final int today;
  final int weeks;
  final int weekStart;
  final Color color;
  final void Function(int day)? onTapDay;

  const Heatmap({
    super.key,
    required this.intensity,
    required this.today,
    required this.weekStart,
    required this.color,
    this.weeks = 18,
    this.onTapDay,
  });

  @override
  Widget build(BuildContext context) {
    final curWeekStart = today - ((weekdayOf(today) - weekStart + 7) % 7);
    final first = curWeekStart - 7 * (weeks - 1);
    return LayoutBuilder(builder: (context, c) {
      double cell = (c.maxWidth - 4) / weeks;
      if (cell > 22) cell = 22;
      final inner = cell - 3;
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(weeks, (col) {
          return Column(
            children: List.generate(7, (row) {
              final day = first + col * 7 + row;
              final future = day > today;
              final v = intensity[day] ?? 0;
              Color fill;
              if (future) {
                fill = Colors.transparent;
              } else if (v <= 0) {
                fill = kCard2;
              } else {
                fill = a(color, 0.28 + 0.72 * clampD(v, 0.0, 1.0));
              }
              return GestureDetector(
                onTap: (future || onTapDay == null) ? null : () => onTapDay!(day),
                child: Container(
                  width: inner,
                  height: inner,
                  margin: const EdgeInsets.all(1.5),
                  decoration: BoxDecoration(
                    color: fill,
                    borderRadius: BorderRadius.circular(4),
                    border: day == today ? Border.all(color: kGold, width: 1.2) : null,
                  ),
                ),
              );
            }),
          );
        }),
      );
    });
  }
}

/// أعمدة بيانية بسيطة (الأقدم على اليمين). target اختياري لرسم خط الهدف.
class MiniBars extends StatelessWidget {
  final List<double> values;
  final List<String> labels;
  final double target;
  final Color color;
  final double height;

  const MiniBars({
    super.key,
    required this.values,
    required this.labels,
    required this.color,
    this.target = 0,
    this.height = 120,
  });

  @override
  Widget build(BuildContext context) {
    double maxV = target;
    for (final v in values) {
      if (v > maxV) maxV = v;
    }
    if (maxV <= 0) maxV = 1;
    return Column(
      children: [
        SizedBox(
          height: height,
          child: Stack(
            children: [
              Positioned.fill(
                  child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(values.length, (i) {
                  final v = values[i];
                  final h = (v / maxV) * (height - 18);
                  final ok = target <= 0 ? v > 0 : v >= target - 0.000001;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (v > 0)
                            Text(num1(v),
                                style: const TextStyle(color: kMuted, fontSize: 9),
                                maxLines: 1,
                                overflow: TextOverflow.clip),
                          const SizedBox(height: 2),
                          Container(
                            height: v > 0 ? math.max(3.0, h) : 3.0,
                            decoration: BoxDecoration(
                              color: v <= 0 ? kCard2 : (ok ? color : a(color, 0.45)),
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              )),
              if (target > 0)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: (target / maxV) * (height - 18),
                  child: Container(height: 1, color: a(kGold, 0.7)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: List.generate(labels.length, (i) {
            return Expanded(
              child: Text(labels[i],
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: const TextStyle(color: kMuted, fontSize: 9)),
            );
          }),
        ),
      ],
    );
  }
}

class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;
  final String? emoji;
  final Color? color;
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.sub,
    this.emoji,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            if (emoji != null) Text('$emoji ', style: const TextStyle(fontSize: 14)),
            Expanded(
              child: Text(label,
                  style: const TextStyle(color: kMuted, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
          ]),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(color: color ?? kText, fontSize: 21, fontWeight: FontWeight.w800)),
          if (sub != null)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(sub!, style: const TextStyle(color: kMuted, fontSize: 11)),
            ),
        ],
      ),
    );
  }
}

/// شبكة من عنصرين في كل صف
class TwoColumn extends StatelessWidget {
  final List<Widget> children;
  const TwoColumn({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (int i = 0; i < children.length; i += 2) {
      rows.add(Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: children[i]),
              const SizedBox(width: 10),
              Expanded(child: i + 1 < children.length ? children[i + 1] : const SizedBox()),
            ],
          ),
        ),
      ));
    }
    return Column(children: rows);
  }
}

class EmojiBadge extends StatelessWidget {
  final String emoji;
  final Color color;
  final double size;
  const EmojiBadge({super.key, required this.emoji, required this.color, this.size = 48});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: a(color, 0.16),
        borderRadius: BorderRadius.circular(size * 0.34),
        border: Border.all(color: a(color, 0.5)),
      ),
      child: Text(emoji, style: TextStyle(fontSize: size * 0.46)),
    );
  }
}

/// نص زمن منقضٍ يتحدّث كل ثانية (للمؤقّت)
class ElapsedText extends StatefulWidget {
  final int startMs;
  final TextStyle? style;
  const ElapsedText({super.key, required this.startMs, this.style});

  @override
  State<ElapsedText> createState() => _ElapsedTextState();
}

class _ElapsedTextState extends State<ElapsedText> {
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    int s = (DateTime.now().millisecondsSinceEpoch - widget.startMs) ~/ 1000;
    if (s < 0) s = 0;
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final sec = s % 60;
    final txt = h > 0 ? '$h:${pad2(m)}:${pad2(sec)}' : '${pad2(m)}:${pad2(sec)}';
    return Text(txt,
        style: widget.style ??
            const TextStyle(color: kEmerald, fontSize: 17, fontWeight: FontWeight.w800),
        textDirection: TextDirection.ltr);
  }
}

Future<double?> askNumber(
  BuildContext context, {
  required String title,
  required double initial,
  String suffix = '',
}) {
  final ctrl = TextEditingController(text: initial > 0 ? num1(initial) : '');
  return showDialog<double>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        backgroundColor: kCard,
        title: Text(title, style: const TextStyle(color: kText, fontSize: 17)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(color: kText, fontSize: 20),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            suffixText: suffix.isEmpty ? null : suffix,
            hintText: '0',
            filled: true,
            fillColor: kCard2,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء', style: TextStyle(color: kMuted)),
          ),
          FilledButton(
            onPressed: () {
              final v = double.tryParse(ctrl.text.trim().replaceAll(',', '.'));
              Navigator.pop(ctx, v ?? 0);
            },
            child: const Text('حفظ'),
          ),
        ],
      );
    },
  );
}

Future<bool> confirmDialog(BuildContext context, String title, String body,
    {String ok = 'تأكيد', bool danger = false}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: kCard,
      title: Text(title, style: const TextStyle(color: kText, fontSize: 17)),
      content: Text(body, style: const TextStyle(color: kMuted, height: 1.5)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('إلغاء', style: TextStyle(color: kMuted)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: danger ? kDanger : kEmerald),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(ok, style: const TextStyle(color: Colors.black)),
        ),
      ],
    ),
  );
  return r ?? false;
}
