import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'notifications.dart';
import 'screen_editor.dart';
import 'screen_more.dart';
import 'screen_prayer.dart';
import 'screen_stats.dart';
import 'screen_today.dart';
import 'store.dart';
import 'util.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: kSurface,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  await NotificationService.init();
  final store = AppStore();
  runApp(IltizamApp(store: store));
  store.load();
}

class IltizamApp extends StatelessWidget {
  final AppStore store;
  const IltizamApp({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: kEmerald,
      brightness: Brightness.dark,
    ).copyWith(
      primary: kEmerald,
      secondary: kGold,
      surface: kSurface,
      onSurface: kText,
    );
    return StoreScope(
      store: store,
      child: MaterialApp(
        title: 'التزام',
        debugShowCheckedModeBanner: false,
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        themeMode: ThemeMode.dark,
        darkTheme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          colorScheme: scheme,
          scaffoldBackgroundColor: kBg,
          canvasColor: kBg,
          appBarTheme: const AppBarTheme(
            backgroundColor: kBg,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            titleTextStyle: TextStyle(color: kText, fontSize: 18, fontWeight: FontWeight.w800),
          ),
          navigationBarTheme: NavigationBarThemeData(
            backgroundColor: kSurface,
            surfaceTintColor: Colors.transparent,
            indicatorColor: a(kEmerald, 0.18),
            labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: states.contains(WidgetState.selected) ? kEmerald : kMuted,
                )),
            iconTheme: WidgetStateProperty.resolveWith((states) =>
                IconThemeData(color: states.contains(WidgetState.selected) ? kEmerald : kMuted)),
          ),
          segmentedButtonTheme: SegmentedButtonThemeData(
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith(
                  (s) => s.contains(WidgetState.selected) ? a(kEmerald, 0.2) : kCard),
              foregroundColor: WidgetStateProperty.resolveWith(
                  (s) => s.contains(WidgetState.selected) ? kEmerald : kMuted),
              side: const WidgetStatePropertyAll(BorderSide(color: kLine)),
            ),
          ),
          chipTheme: ChipThemeData(
            backgroundColor: kCard,
            selectedColor: a(kEmerald, 0.22),
            side: const BorderSide(color: kLine),
            labelStyle: const TextStyle(color: kText),
          ),
          popupMenuTheme: const PopupMenuThemeData(color: kCard2),
          snackBarTheme: const SnackBarThemeData(backgroundColor: kCard2),
        ),
        theme: ThemeData(brightness: Brightness.dark, useMaterial3: true, colorScheme: scheme),
        builder: (context, child) => Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox(),
        ),
        home: const HomeShell(),
      ),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // عند الرجوع للتطبيق (ربما في يوم جديد) نحدّث الواجهة ونعيد جدولة الإشعارات
    if (state == AppLifecycleState.resumed && mounted) {
      final store = StoreScope.of(context);
      setState(() {});
      NotificationService.scheduleSoon(store);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    if (!store.loaded) {
      return const Scaffold(
        body: Center(child: Text('🛡️', style: TextStyle(fontSize: 64))),
      );
    }
    final pages = <Widget>[
      TodayScreen(goTab: (i) => setState(() => tab = i)),
      const StatsScreen(),
      const PrayerScreen(),
      const MoreScreen(),
    ];
    return Scaffold(
      body: SafeArea(bottom: false, child: IndexedStack(index: tab, children: pages)),
      floatingActionButton: tab == 0
          ? FloatingActionButton.extended(
              onPressed: () => showHabitEditor(context),
              backgroundColor: kEmerald,
              foregroundColor: Colors.black,
              icon: const Icon(Icons.add_rounded),
              label: const Text('عادة جديدة', style: TextStyle(fontWeight: FontWeight.w800)),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.today_outlined), selectedIcon: Icon(Icons.today_rounded), label: 'اليوم'),
          NavigationDestination(icon: Icon(Icons.insights_outlined), selectedIcon: Icon(Icons.insights_rounded), label: 'التحليلات'),
          NavigationDestination(icon: Icon(Icons.mosque_outlined), selectedIcon: Icon(Icons.mosque_rounded), label: 'الصلاة'),
          NavigationDestination(icon: Icon(Icons.shield_outlined), selectedIcon: Icon(Icons.shield_rounded), label: 'المزيد'),
        ],
      ),
    );
  }
}
