import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'store.dart';
import 'util.dart';

/// لوحة أرقام لإدخال رمز من 4 خانات
class PinPad extends StatefulWidget {
  final String title;
  final String? subtitle;
  final String? error;
  final void Function(String pin) onComplete;
  const PinPad({super.key, required this.title, required this.onComplete, this.subtitle, this.error});

  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> {
  String pin = '';

  void _press(String d) {
    if (pin.length >= 4) return;
    HapticFeedback.selectionClick();
    setState(() => pin += d);
    if (pin.length == 4) {
      final p = pin;
      Future<void>.delayed(const Duration(milliseconds: 120), () {
        if (!mounted) return;
        setState(() => pin = '');
        widget.onComplete(p);
      });
    }
  }

  void _back() {
    if (pin.isEmpty) return;
    setState(() => pin = pin.substring(0, pin.length - 1));
  }

  Widget _key(String label, {VoidCallback? onTap, IconData? icon}) {
    return SizedBox(
      width: 78,
      height: 66,
      child: onTap == null
          ? const SizedBox()
          : InkResponse(
              onTap: onTap,
              radius: 40,
              child: Center(
                child: icon != null
                    ? Icon(icon, color: kText, size: 26)
                    : Text(label, style: const TextStyle(color: kText, fontSize: 28, fontWeight: FontWeight.w700)),
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('🛡️', style: TextStyle(fontSize: 54)),
        const SizedBox(height: 10),
        Text(widget.title, style: const TextStyle(color: kText, fontSize: 20, fontWeight: FontWeight.w900)),
        if (widget.subtitle != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(widget.subtitle!, style: const TextStyle(color: kMuted, fontSize: 13)),
          ),
        const SizedBox(height: 22),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < 4; i++)
              Container(
                width: 16,
                height: 16,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < pin.length ? kEmerald : Colors.transparent,
                  border: Border.all(color: i < pin.length ? kEmerald : kMuted, width: 2),
                ),
              ),
          ],
        ),
        SizedBox(
          height: 30,
          child: Center(
            child: Text(widget.error ?? '', style: const TextStyle(color: kDanger, fontSize: 13)),
          ),
        ),
        const SizedBox(height: 6),
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [for (final d in row) _key(d, onTap: () => _press(d))],
          ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _key('', onTap: null),
            _key('0', onTap: () => _press('0')),
            _key('', onTap: _back, icon: Icons.backspace_outlined),
          ],
        ),
      ],
    );
  }
}

/// شاشة القفل عند فتح التطبيق
class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  String? error;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return Scaffold(
      body: SafeArea(
        child: PinPad(
          title: 'أدخل رمز التطبيق',
          error: error,
          onComplete: (p) {
            if (store.checkPin(p)) {
              store.unlock();
            } else {
              HapticFeedback.heavyImpact();
              setState(() => error = 'الرمز غير صحيح');
            }
          },
        ),
      ),
    );
  }
}

enum PinMode { set, change, remove }

/// مسار إنشاء/تغيير/إزالة الرمز
class PinFlowPage extends StatefulWidget {
  final PinMode mode;
  const PinFlowPage({super.key, required this.mode});

  @override
  State<PinFlowPage> createState() => _PinFlowPageState();
}

class _PinFlowPageState extends State<PinFlowPage> {
  // 0 تحقق من الحالي، 1 رمز جديد، 2 تأكيد
  late int stage = widget.mode == PinMode.set ? 1 : 0;
  String first = '';
  String? error;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    String title;
    if (stage == 0) {
      title = 'أدخل الرمز الحالي';
    } else if (stage == 1) {
      title = 'أدخل رمزًا جديدًا من 4 أرقام';
    } else {
      title = 'أعد إدخال الرمز للتأكيد';
    }
    return Scaffold(
      appBar: AppBar(title: const Text('قفل التطبيق')),
      body: SafeArea(
        child: PinPad(
          key: ValueKey(stage),
          title: title,
          subtitle: stage == 1 ? 'احفظه جيدًا: لا يمكن استعادته إن نسيته إلا بمسح بيانات التطبيق' : null,
          error: error,
          onComplete: (p) {
            if (stage == 0) {
              if (!store.checkPin(p)) {
                setState(() => error = 'الرمز غير صحيح');
                return;
              }
              if (widget.mode == PinMode.remove) {
                store.setPin(null);
                toast(context, 'أُزيل القفل');
                Navigator.of(context).pop();
              } else {
                setState(() {
                  stage = 1;
                  error = null;
                });
              }
            } else if (stage == 1) {
              setState(() {
                first = p;
                stage = 2;
                error = null;
              });
            } else {
              if (p == first) {
                store.setPin(p);
                toast(context, 'فُعّل القفل ✓');
                Navigator.of(context).pop();
              } else {
                setState(() {
                  stage = 1;
                  first = '';
                  error = 'الرمزان غير متطابقين، أعد المحاولة';
                });
              }
            }
          },
        ),
      ),
    );
  }
}
