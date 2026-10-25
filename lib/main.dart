import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'analytics.dart';

// =========================================================
// KOLORY I POMOCNICZE
// =========================================================

/// Kolor z przezroczystością (zamiast przestarzałego withOpacity).
Color fade(Color color, double opacity) => color.withAlpha((opacity * 255).round());

class AppColors {
  static const Color bg = Color(0xFFF5F7F4);
  static const Color text = Color(0xFF1C2620);
  static const Color muted = Color(0xFF5F6B63);
  static const Color border = Color(0xFFE3E8E4);
  static const Color track = Color(0xFFE6EBE7);
  static const Color primary = Color(0xFF2E7D32);
  static const Color primaryDark = Color(0xFF1B5E20);
  static const List<Color> greenGradient = [Color(0xFF43A047), Color(0xFF1B5E20)];
  static const List<Color> blueGradient = [Color(0xFF42A5F5), Color(0xFF1565C0)];
  static const List<Color> goldGradient = [Color(0xFFFFCA28), Color(0xFFFF8F00)];
}

// =========================================================
// STAN APLIKACJI – zapisywany w pamięci telefonu
// =========================================================
class AppState {
  static const int zoneCount = 5;
  static const int pointsPerZone = 50;
  static const int maxPoints = zoneCount * pointsPerZone; // 250
  static const int certificateThreshold = 200; // 4 ukończone strefy

  static String userName = "";
  static final List<bool> completed = List<bool>.filled(zoneCount, false);
  static final List<bool> earned = List<bool>.filled(zoneCount, false);
  static final List<int> savedStage = List<int>.filled(zoneCount, 0);

  /// Punkty liczone zawsze z ukończonych stref – nie da się ich "rozjechać".
  static int get userPoints => earned.where((e) => e).length * pointsPerZone;
  static int get completedCount => completed.where((e) => e).length;
  static bool isInProgress(int zone) => !completed[zone] && savedStage[zone] > 0;

  static int? get firstInProgress {
    for (int i = 0; i < zoneCount; i++) {
      if (isInProgress(i)) return i;
    }
    return null;
  }

  static String get rank {
    final int p = userPoints;
    if (p >= maxPoints) return "Mistrz Dobrostanu 🏆";
    if (p >= 150) return "Aktywny Odkrywca 🌟";
    if (p >= 50) return "Początkujący Wędrowiec 🌱";
    return "Startujący ✨";
  }

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      userName = prefs.getString('userName') ?? "";
      for (int i = 0; i < zoneCount; i++) {
        completed[i] = prefs.getBool('zone${i}_completed') ?? false;
        earned[i] = prefs.getBool('zone${i}_earned') ?? false;
        savedStage[i] = prefs.getInt('zone${i}_stage') ?? 0;
      }
    } catch (_) {
      // Gdy zapis nie działa, aplikacja i tak działa – tylko bez zapamiętywania.
    }
  }

  static Future<void> save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userName', userName);
      for (int i = 0; i < zoneCount; i++) {
        await prefs.setBool('zone${i}_completed', completed[i]);
        await prefs.setBool('zone${i}_earned', earned[i]);
        await prefs.setInt('zone${i}_stage', savedStage[i]);
      }
    } catch (_) {}
  }

  /// Zapamiętuje, na którym kroku użytkownik jest w danej strefie.
  static void saveProgress(int zone, int stage) {
    if (completed[zone]) return;
    savedStage[zone] = stage;
    save();
  }

  /// Kończy strefę. Zwraca true, jeśli punkty przyznano po raz pierwszy.
  static bool completeZone(int zone) {
    final bool firstTime = !earned[zone];
    completed[zone] = true;
    earned[zone] = true;
    savedStage[zone] = 0;
    save();
    trackEvent("strefa-${zone + 1}-ukonczona");
    return firstTime;
  }

  static Future<void> reset() async {
    userName = "";
    for (int i = 0; i < zoneCount; i++) {
      completed[i] = false;
      earned[i] = false;
      savedStage[i] = 0;
    }
    await save();
  }
}

// =========================================================
// START APLIKACJI
// =========================================================
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppState.load();
  runApp(const RuchNaLuzieApp());
}

class RuchNaLuzieApp extends StatelessWidget {
  const RuchNaLuzieApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ruch Na Luzie',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
        scaffoldBackgroundColor: AppColors.bg,
        snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
      ),
      home: const MainMenuScreen(),
    );
  }
}

// =========================================================
// KOLORY I TEKSTY STREF
// =========================================================
class ZoneTheme {
  final int index;
  final String name;
  final IconData icon;
  final Color main; // przyciski, akcenty
  final Color dark; // napisy w kolorze strefy
  final Color tint; // jasne tło strefy
  final List<Color> gradient; // ikony i nagłówek
  final int stepCount; // liczba kroków (do wyświetlania w menu)
  final String description;
  final String rewardTitle;
  final String rewardText;

  const ZoneTheme({
    required this.index,
    required this.name,
    required this.icon,
    required this.main,
    required this.dark,
    required this.tint,
    required this.gradient,
    required this.stepCount,
    required this.description,
    required this.rewardTitle,
    required this.rewardText,
  });
}

const ZoneTheme zone1Theme = ZoneTheme(
  index: 0,
  name: "Poznaj swój organizm",
  icon: Icons.accessibility_new_rounded,
  main: Color(0xFF2E7D32),
  dark: Color(0xFF1B5E20),
  tint: Color(0xFFF0F7F1),
  gradient: [Color(0xFF66BB6A), Color(0xFF2E7D32)],
  stepCount: 8,
  description: "Kompleksowe kroki do pełnej regeneracji i energii.",
  rewardTitle: "Strefa ukończona!",
  rewardText: "Wspaniała robota! Przeszedłeś pełny cykl zadań i lepiej poznałeś swój organizm.",
);

const ZoneTheme zone2Theme = ZoneTheme(
  index: 1,
  name: "Oddech i Spokój",
  icon: Icons.air_rounded,
  main: Color(0xFF0277BD),
  dark: Color(0xFF01579B),
  tint: Color(0xFFEEF6FC),
  gradient: [Color(0xFF4FC3F7), Color(0xFF0277BD)],
  stepCount: 7,
  description: "Ćwiczenia prowadzące do głębokiego relaksu i wyciszenia emocji.",
  rewardTitle: "Strefa ukończona!",
  rewardText: "Osiągnąłeś pełen spokój umysłu! Zyskałeś potężne narzędzie do walki ze stresem.",
);

const ZoneTheme zone3Theme = ZoneTheme(
  index: 2,
  name: "Emocje w ruchu",
  icon: Icons.psychology_rounded,
  main: Color(0xFFE65100),
  dark: Color(0xFFBF360C),
  tint: Color(0xFFFFF4EB),
  gradient: [Color(0xFFFFA726), Color(0xFFE65100)],
  stepCount: 8,
  description: "Dynamiczne kroki uwalniania emocji poprzez ciało.",
  rewardTitle: "Emocje w ruchu – ukończone!",
  rewardText: "Rozładowałeś stres i napięcie poprzez ruch! Twoja inteligencja emocjonalna rośnie.",
);

const ZoneTheme zone4Theme = ZoneTheme(
  index: 3,
  name: "Siła współpracy",
  icon: Icons.groups_rounded,
  main: Color(0xFFEF8F00),
  dark: Color(0xFFA35400),
  tint: Color(0xFFFFFAEB),
  gradient: [Color(0xFFFFC107), Color(0xFFEF6C00)],
  stepCount: 8,
  description: "Kroki budowania więzi, empatii i dobrej współpracy.",
  rewardTitle: "Siła współpracy – ukończona!",
  rewardText: "Razem możemy więcej! Budowanie relacji i wspieranie innych to klucz do zdrowia.",
);

const ZoneTheme zone5Theme = ZoneTheme(
  index: 4,
  name: "Mój Kompas Zdrowia",
  icon: Icons.explore_rounded,
  main: Color(0xFFAD1457),
  dark: Color(0xFF880E4F),
  tint: Color(0xFFFCEFF4),
  gradient: [Color(0xFFF06292), Color(0xFFAD1457)],
  stepCount: 7,
  description: "Ułóż swój osobisty plan dobrostanu i zdrowych nawyków.",
  rewardTitle: "Kompas Zdrowia – ukończony!",
  rewardText: "Stworzyłeś swój osobisty plan dobrostanu na ten tydzień!",
);

const List<ZoneTheme> allZones = [zone1Theme, zone2Theme, zone3Theme, zone4Theme, zone5Theme];

Widget zoneScreen(int index) {
  switch (index) {
    case 0:
      return const Zone1Screen();
    case 1:
      return const Zone2Screen();
    case 2:
      return const Zone3Screen();
    case 3:
      return const Zone4Screen();
    default:
      return const Zone5Screen();
  }
}

// =========================================================
// WSPÓLNE ELEMENTY WYGLĄDU
// =========================================================

/// Biała karta z miękkim cieniem i zaokrągleniem.
class SoftCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final VoidCallback? onTap;

  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.color = Colors.white,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final BoxDecoration decoration = BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(28),
      border: Border.all(color: AppColors.border),
      boxShadow: [BoxShadow(color: fade(Colors.black, 0.04), blurRadius: 24, offset: const Offset(0, 8))],
    );

    if (onTap == null) {
      return Container(padding: padding, decoration: decoration, child: child);
    }
    return Material(
      type: MaterialType.transparency,
      child: Ink(
        decoration: decoration,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(28),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Kolorowy kwadracik z ikoną.
class IconBadge extends StatelessWidget {
  final IconData icon;
  final List<Color> colors;
  final double size;

  const IconBadge({super.key, required this.icon, required this.colors, this.size = 52});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(size * 0.32),
        boxShadow: [BoxShadow(color: fade(colors.last, 0.28), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Icon(icon, color: Colors.white, size: size * 0.5),
    );
  }
}

/// Duży, zaokrąglony przycisk – wygodny do trafienia palcem.
class BigButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final IconData? icon;
  final IconData? trailingIcon;

  const BigButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color = AppColors.primary,
    this.icon,
    this.trailingIcon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFE3E7E4),
          disabledForegroundColor: const Color(0xFF98A39B),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 22), const SizedBox(width: 8)],
            Flexible(child: Text(label, textAlign: TextAlign.center)),
            if (trailingIcon != null) ...[const SizedBox(width: 8), Icon(trailingIcon, size: 22)],
          ],
        ),
      ),
    );
  }
}

/// Okrągły przycisk z ikoną (np. "wstecz").
class CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const CircleIconButton({super.key, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(side: BorderSide(color: AppColors.border)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(width: 48, height: 48, child: Icon(icon, color: AppColors.text, size: 24)),
      ),
    );
  }
}

/// Licznik punktów w kształcie pigułki.
class PointsChip extends StatelessWidget {
  const PointsChip({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, color: Color(0xFFFFB300), size: 20),
          const SizedBox(width: 4),
          Text("${AppState.userPoints}", style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.text)),
        ],
      ),
    );
  }
}

/// Nagłówek ekranu z przyciskiem "wstecz".
class ScreenHeader extends StatelessWidget {
  final String title;

  const ScreenHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleIconButton(icon: Icons.arrow_back_rounded, onTap: () => Navigator.pop(context)),
        const SizedBox(width: 14),
        Expanded(
          child: Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.text)),
        ),
      ],
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String title;

  const SectionTitle(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.text));
  }
}

Widget roundedProgress(double value, Color color, {double height = 8}) {
  return ClipRRect(
    borderRadius: BorderRadius.circular(height),
    child: LinearProgressIndicator(
      value: value,
      minHeight: height,
      backgroundColor: AppColors.track,
      valueColor: AlwaysStoppedAnimation<Color>(color),
    ),
  );
}

// =========================================================
// MENU GŁÓWNE
// =========================================================
class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  static const List<String> _quotes = [
    "Pamiętaj o głębokim oddechu i postawie pełnej spokoju.",
    "Każdy Twój krok buduje zdrowie i dobrą energię.",
    "Zatrzymaj się na chwilę, uśmiechnij i ruszaj dalej.",
    "Ruch to najlepszy eliksir dla ciała i umysłu.",
    "Bądź dla siebie cierpliwy i dobry na co dzień.",
  ];

  late final String _quote;

  @override
  void initState() {
    super.initState();
    _quote = _quotes[Random().nextInt(_quotes.length)];
  }

  Future<void> _open(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final String name = AppState.userName;
    final String greeting = DateTime.now().hour < 18 ? "Dzień dobry" : "Dobry wieczór";
    final int? resume = AppState.firstInProgress;
    final bool certUnlocked = AppState.userPoints >= AppState.certificateThreshold;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("$greeting 👋", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.muted)),
                      const SizedBox(height: 2),
                      Text(
                        name.isNotEmpty ? name : "Ruch Na Luzie",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.text),
                      ),
                    ],
                  ),
                ),
                _AvatarButton(name: name, onTap: () => _open(const ProfileScreen())),
              ],
            ),
            const SizedBox(height: 20),
            _HeroCard(quote: _quote),
            if (resume != null) ...[
              const SizedBox(height: 16),
              _ContinueCard(zone: allZones[resume], onTap: () => _open(zoneScreen(resume))),
            ],
            const SizedBox(height: 28),
            const SectionTitle("Twoje strefy"),
            const SizedBox(height: 12),
            for (final ZoneTheme z in allZones)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ZoneListTile(zone: z, onTap: () => _open(zoneScreen(z.index))),
              ),
            const SizedBox(height: 16),
            const SectionTitle("Wyniki"),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _QuickTile(
                    icon: Icons.insights_rounded,
                    title: "Statystyki",
                    subtitle: "${AppState.completedCount} z ${AppState.zoneCount} stref",
                    colors: AppColors.blueGradient,
                    onTap: () => _open(const StatisticsScreen()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickTile(
                    icon: Icons.workspace_premium_rounded,
                    title: "Certyfikat",
                    subtitle: certUnlocked ? "Odblokowany 🎉" : "Od ${AppState.certificateThreshold} pkt",
                    colors: AppColors.goldGradient,
                    onTap: () => _open(const CertificateScreen()),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarButton extends StatelessWidget {
  final String name;
  final VoidCallback onTap;

  const _AvatarButton({required this.name, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: AppColors.greenGradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: fade(AppColors.primaryDark, 0.3), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Center(
          child: name.isNotEmpty
              ? Text(name[0].toUpperCase(), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white))
              : const Icon(Icons.person_rounded, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final String quote;

  const _HeroCard({required this.quote});

  @override
  Widget build(BuildContext context) {
    final int points = AppState.userPoints;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: AppColors.greenGradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: fade(AppColors.primaryDark, 0.3), blurRadius: 24, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 92,
                height: 92,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: points / AppState.maxPoints,
                      strokeWidth: 9,
                      backgroundColor: fade(Colors.white, 0.2),
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text("$points", style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white, height: 1.1)),
                          Text("pkt", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: fade(Colors.white, 0.8))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Twoja ranga", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: fade(Colors.white, 0.8))),
                    const SizedBox(height: 2),
                    Text(AppState.rank, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Colors.white)),
                    const SizedBox(height: 6),
                    Text(
                      "Ukończone strefy: ${AppState.completedCount} z ${AppState.zoneCount}",
                      style: TextStyle(fontSize: 15, color: fade(Colors.white, 0.85)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: fade(Colors.white, 0.14), borderRadius: BorderRadius.circular(18)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.format_quote_rounded, color: fade(Colors.white, 0.8)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(quote, style: const TextStyle(fontSize: 15, color: Colors.white, fontStyle: FontStyle.italic, height: 1.4)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ContinueCard extends StatelessWidget {
  final ZoneTheme zone;
  final VoidCallback onTap;

  const _ContinueCard({required this.zone, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final int stage = AppState.savedStage[zone.index];
    return SoftCard(
      onTap: onTap,
      color: zone.tint,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconBadge(icon: Icons.play_arrow_rounded, colors: zone.gradient, size: 54),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("KONTYNUUJ", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: zone.dark)),
                const SizedBox(height: 2),
                Text(zone.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.text)),
                Text("Wróć do kroku $stage z ${zone.stepCount}", style: const TextStyle(fontSize: 14, color: AppColors.muted)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.muted, size: 28),
        ],
      ),
    );
  }
}

class _ZoneListTile extends StatelessWidget {
  final ZoneTheme zone;
  final VoidCallback onTap;

  const _ZoneListTile({required this.zone, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final int i = zone.index;
    final bool done = AppState.completed[i];
    final bool inProgress = AppState.isInProgress(i);
    final double progress = done ? 1.0 : (inProgress ? (AppState.savedStage[i] - 1) / zone.stepCount : 0.0);
    final String status = done
        ? "Ukończona"
        : inProgress
            ? "W trakcie • krok ${AppState.savedStage[i]} z ${zone.stepCount}"
            : "${zone.stepCount} kroków • ${AppState.pointsPerZone} pkt";

    return SoftCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconBadge(icon: zone.icon, colors: zone.gradient, size: 58),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(zone.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.text)),
                const SizedBox(height: 3),
                Text(
                  status,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: done || inProgress ? zone.dark : AppColors.muted),
                ),
                const SizedBox(height: 10),
                roundedProgress(progress, zone.main, height: 6),
              ],
            ),
          ),
          const SizedBox(width: 12),
          done
              ? Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(color: zone.main, shape: BoxShape.circle),
                  child: const Icon(Icons.check_rounded, color: Colors.white, size: 20),
                )
              : const Icon(Icons.chevron_right_rounded, color: AppColors.muted, size: 28),
        ],
      ),
    );
  }
}

class _QuickTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> colors;
  final VoidCallback onTap;

  const _QuickTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      onTap: onTap,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBadge(icon: icon, colors: colors, size: 48),
          const SizedBox(height: 14),
          Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.text)),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(fontSize: 14, color: AppColors.muted)),
        ],
      ),
    );
  }
}

// =========================================================
// WSPÓLNA BAZA DLA WSZYSTKICH STREF
// (nagłówek, ekran startowy, karty kroków, quiz, skan, nagroda)
// =========================================================
abstract class ZoneBaseState<T extends StatefulWidget> extends State<T> {
  ZoneTheme get zone;

  /// Lista kroków strefy (bez ekranu startowego i nagrody).
  List<Widget Function()> get steps;

  int stage = 0; // 0 = ekran startowy, 1..n = kroki, n+1 = nagroda
  bool _pointsAwarded = false;
  String? quizAnswer;

  int get stepCount => steps.length;

  /// Wywoływane przy zmianie kroku i zamknięciu strefy (np. zatrzymanie zegara).
  void onLeaveStage() {}

  void goTo(int newStage) {
    onLeaveStage();
    setState(() {
      stage = newStage;
      if (stage > stepCount) {
        _pointsAwarded = AppState.completeZone(zone.index);
      } else if (stage > 0) {
        AppState.saveProgress(zone.index, stage);
      }
    });
  }

  void next() => goTo(stage + 1);

  @override
  void dispose() {
    onLeaveStage();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool inSteps = stage >= 1 && stage <= stepCount;

    return Scaffold(
      backgroundColor: zone.tint,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            if (inSteps)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
                child: _segmentedProgress(),
              ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(begin: const Offset(0.06, 0), end: Offset.zero).animate(animation),
                    child: child,
                  ),
                ),
                child: KeyedSubtree(key: ValueKey<int>(stage), child: _buildCurrent()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrent() {
    if (stage == 0) return _buildIntro();
    if (stage > stepCount) return _buildReward();
    return steps[stage - 1]();
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          CircleIconButton(icon: Icons.arrow_back_rounded, onTap: () => Navigator.pop(context)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "STREFA ${zone.index + 1}",
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: zone.dark),
                ),
                Text(
                  zone.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.text),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const PointsChip(),
        ],
      ),
    );
  }

  /// Pasek postępu podzielony na odcinki – jeden odcinek = jeden krok.
  Widget _segmentedProgress() {
    return Row(
      children: [
        for (int i = 1; i <= stepCount; i++)
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 6,
              margin: EdgeInsets.only(right: i == stepCount ? 0 : 4),
              decoration: BoxDecoration(
                color: i < stage ? zone.main : (i == stage ? fade(zone.main, 0.45) : const Color(0xFFDDE3DE)),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
      ],
    );
  }

  // ---------------- EKRAN STARTOWY STREFY ----------------
  Widget _buildIntro() {
    final int z = zone.index;
    final bool done = AppState.completed[z];
    final bool inProgress = AppState.isInProgress(z);
    final int resumeStage = min(max(AppState.savedStage[z], 1), stepCount);
    final double progress = done ? 1.0 : (inProgress ? (resumeStage - 1) / stepCount : 0.0);

    final String status = done
        ? "Strefa ukończona w 100%! Możesz ją powtórzyć, kiedy tylko zechcesz."
        : inProgress
            ? "Zatrzymałeś się na kroku $resumeStage z $stepCount. Dokończ wyzwanie!"
            : zone.description;

    final String buttonLabel = done
        ? "Powtórz strefę"
        : inProgress
            ? "Wznów od kroku $resumeStage"
            : "Rozpocznij strefę";

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: zone.gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(32),
              boxShadow: [BoxShadow(color: fade(zone.gradient.last, 0.35), blurRadius: 24, offset: const Offset(0, 10))],
            ),
            child: Column(
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(color: fade(Colors.white, 0.22), shape: BoxShape.circle),
                  child: Icon(zone.icon, size: 46, color: Colors.white),
                ),
                const SizedBox(height: 18),
                Text(
                  zone.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    shadows: [Shadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 1))],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  status,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    height: 1.45,
                    shadows: [Shadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 1))],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SoftCard(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _statBox(Icons.format_list_numbered_rounded, "$stepCount", "kroków")),
                    const SizedBox(width: 10),
                    Expanded(child: _statBox(Icons.star_rounded, "${AppState.pointsPerZone}", "punktów")),
                    const SizedBox(width: 10),
                    Expanded(child: _statBox(Icons.trending_up_rounded, "${(progress * 100).round()}%", "postępu")),
                  ],
                ),
                const SizedBox(height: 18),
                roundedProgress(progress, zone.main, height: 10),
              ],
            ),
          ),
          const SizedBox(height: 20),
          BigButton(
            label: buttonLabel,
            icon: done ? Icons.replay_rounded : Icons.play_arrow_rounded,
            color: zone.main,
            onPressed: () => goTo(inProgress ? resumeStage : 1),
          ),
          if (inProgress) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => goTo(1),
              child: Text("Zacznij od początku", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: zone.dark)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statBox(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(color: zone.tint, borderRadius: BorderRadius.circular(18)),
      child: Column(
        children: [
          Icon(icon, color: zone.main, size: 22),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.text)),
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.muted)),
        ],
      ),
    );
  }

  // ---------------- EKRAN NAGRODY ----------------
  Widget _buildReward() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 136,
              height: 136,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: AppColors.goldGradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: fade(const Color(0xFFFF8F00), 0.4), blurRadius: 30, offset: const Offset(0, 12))],
              ),
              child: const Icon(Icons.emoji_events_rounded, size: 72, color: Colors.white),
            ),
          ),
          const SizedBox(height: 26),
          Text(
            zone.rewardTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.text),
          ),
          const SizedBox(height: 12),
          Text(
            zone.rewardText,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17, color: AppColors.muted, height: 1.5),
          ),
          const SizedBox(height: 24),
          SoftCard(
            child: Row(
              children: [
                const IconBadge(icon: Icons.star_rounded, colors: AppColors.goldGradient, size: 50),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _pointsAwarded ? "+${AppState.pointsPerZone} punktów!" : "Strefa powtórzona",
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.text),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _pointsAwarded
                            ? "Masz teraz ${AppState.userPoints} z ${AppState.maxPoints} pkt"
                            : "Punkty za tę strefę zdobyłeś już wcześniej",
                        style: const TextStyle(fontSize: 15, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          BigButton(label: "Wróć do menu", icon: Icons.home_rounded, color: zone.main, onPressed: () => Navigator.pop(context)),
        ],
      ),
    );
  }

  // ---------------- ELEMENTY KROKÓW ----------------

  /// Karta jednego kroku: ikona, numer, tytuł, opis, treść i przycisk "dalej".
  Widget stepCard({
    required IconData icon,
    required String title,
    String? text,
    List<Widget> children = const [],
    required String buttonText,
    required bool canContinue,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      child: SoftCard(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconBadge(icon: icon, colors: zone.gradient, size: 54),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "KROK $stage Z $stepCount",
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.1, color: zone.dark),
                      ),
                      const SizedBox(height: 2),
                      Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.text, height: 1.2)),
                    ],
                  ),
                ),
              ],
            ),
            if (text != null) ...[
              const SizedBox(height: 16),
              Text(text, style: const TextStyle(fontSize: 17, color: AppColors.muted, height: 1.5)),
            ],
            const SizedBox(height: 22),
            ...children,
            const SizedBox(height: 10),
            BigButton(
              label: buttonText,
              color: zone.main,
              trailingIcon: Icons.arrow_forward_rounded,
              onPressed: canContinue ? next : null,
            ),
          ],
        ),
      ),
    );
  }

  /// Duża ikona w jasnym kółku – ilustracja ćwiczenia.
  Widget illustration(IconData icon, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Center(
        child: Container(
          width: 128,
          height: 128,
          decoration: BoxDecoration(color: zone.tint, shape: BoxShape.circle),
          child: Icon(icon, size: 66, color: color ?? zone.main),
        ),
      ),
    );
  }

  /// Przycisk pomocniczy (obrys).
  Widget secondaryButton(String label, VoidCallback? onPressed, {IconData icon = Icons.play_arrow_rounded}) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        style: OutlinedButton.styleFrom(
          foregroundColor: zone.dark,
          side: BorderSide(color: onPressed == null ? AppColors.border : zone.main, width: 2),
          shape: const StadiumBorder(),
        ),
      ),
    );
  }

  /// Pole "odhacz, że zrobione".
  Widget checkTile(String title, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: () => onChanged(!value),
          borderRadius: BorderRadius.circular(18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: value ? zone.tint : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: value ? zone.main : AppColors.border, width: 2),
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: value ? zone.main : Colors.white,
                    border: Border.all(color: value ? zone.main : const Color(0xFFB8C2BB), width: 2),
                  ),
                  child: value ? const Icon(Icons.check_rounded, color: Colors.white, size: 20) : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: value ? zone.dark : AppColors.text),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Opcja wyboru. Gdy [isCorrect] nie jest null – pokazuje wynik quizu.
  Widget optionTile(String text, {required bool selected, required VoidCallback onTap, bool? isCorrect}) {
    Color bg = selected ? zone.tint : Colors.white;
    Color border = selected ? zone.main : AppColors.border;
    Color textColor = selected ? zone.dark : AppColors.text;
    Widget indicator = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: selected ? zone.main : const Color(0xFFB8C2BB), width: selected ? 8 : 2),
      ),
    );

    if (isCorrect == true) {
      bg = const Color(0xFFE8F5E9);
      border = const Color(0xFF43A047);
      textColor = const Color(0xFF1B5E20);
      indicator = const Icon(Icons.check_circle_rounded, color: Color(0xFF43A047), size: 28);
    } else if (isCorrect == false) {
      if (selected) {
        bg = const Color(0xFFFFEBEE);
        border = const Color(0xFFE57373);
        textColor = const Color(0xFFC62828);
        indicator = const Icon(Icons.cancel_rounded, color: Color(0xFFE53935), size: 28);
      } else {
        bg = const Color(0xFFF5F6F5);
        border = Colors.transparent;
        textColor = const Color(0xFF98A39B);
        indicator = const Icon(Icons.remove_circle_outline_rounded, color: Color(0xFFC2C9C4), size: 28);
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: border, width: 2),
            ),
            child: Row(
              children: [
                SizedBox(width: 30, child: Center(child: indicator)),
                const SizedBox(width: 12),
                Expanded(child: Text(text, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: textColor))),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Pole tekstowe.
  Widget textInput(TextEditingController controller, String hint, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        onChanged: (_) => setState(() {}),
        style: const TextStyle(fontSize: 17, color: AppColors.text),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFF98A39B)),
          filled: true,
          fillColor: const Color(0xFFF3F5F3),
          contentPadding: const EdgeInsets.all(18),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: AppColors.border, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(color: zone.main, width: 2),
          ),
        ),
      ),
    );
  }

  /// Krok z quizem. Gdy [correct] == null, każda odpowiedź jest dobra.
  Widget quizStep({
    required IconData icon,
    required String title,
    required String question,
    required List<String> options,
    String? correct,
    required String explanation,
    required String buttonText,
  }) {
    final bool answered = quizAnswer != null;
    final bool isRight = correct == null || quizAnswer == correct;

    String feedback = explanation;
    if (answered && correct != null) {
      feedback = isRight ? "Brawo! $explanation" : "Nie tym razem. Poprawna odpowiedź: „$correct”. $explanation";
    }

    return stepCard(
      icon: icon,
      title: title,
      buttonText: buttonText,
      canContinue: answered,
      children: [
        Text(question, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.text, height: 1.4)),
        const SizedBox(height: 16),
        for (final String option in options)
          optionTile(
            option,
            selected: quizAnswer == option,
            onTap: () => setState(() => quizAnswer = option),
            isCorrect: (answered && correct != null) ? option == correct : null,
          ),
        if (answered)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isRight ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  isRight ? Icons.lightbulb_rounded : Icons.info_outline_rounded,
                  color: isRight ? const Color(0xFF2E7D32) : const Color(0xFFE65100),
                  size: 26,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    feedback,
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                      color: isRight ? const Color(0xFF1B5E20) : const Color(0xFFBF360C),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// Ostatni krok strefy: suwak 1–10 z buźką i wybór emocji.
  Widget reflectionStep({
    required String title,
    required String question,
    required double value,
    required ValueChanged<double> onChanged,
    required String emotionQuestion,
    required List<String> emotions,
    required String? selected,
    required ValueChanged<String> onSelect,
  }) {
    const List<String> faces = ["😣", "😟", "🙁", "😐", "😐", "🙂", "😊", "😄", "😁", "🤩"];
    final int v = value.toInt();
    final String buttonText = AppState.earned[zone.index] ? "Zakończ strefę" : "Zakończ strefę (+${AppState.pointsPerZone} pkt)";

    return stepCard(
      icon: Icons.insights_rounded,
      title: title,
      buttonText: buttonText,
      canContinue: selected != null,
      children: [
        Text(question, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.text)),
        const SizedBox(height: 16),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            decoration: BoxDecoration(color: zone.tint, borderRadius: BorderRadius.circular(24)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(faces[v - 1], style: const TextStyle(fontSize: 36)),
                const SizedBox(width: 12),
                Text("$v", style: TextStyle(fontSize: 38, fontWeight: FontWeight.w900, color: zone.dark)),
                const Text(" / 10", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.muted)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 8,
            activeTrackColor: zone.main,
            inactiveTrackColor: AppColors.track,
            thumbColor: zone.main,
            overlayColor: fade(zone.main, 0.15),
          ),
          child: Slider(value: value, min: 1, max: 10, divisions: 9, onChanged: onChanged),
        ),
        const SizedBox(height: 14),
        Text(emotionQuestion, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.text)),
        const SizedBox(height: 14),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final String e in emotions) _emotionPill(e, selected == e, () => onSelect(e)),
          ],
        ),
        const SizedBox(height: 22),
      ],
    );
  }

  Widget _emotionPill(String label, bool selected, VoidCallback onTap) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? zone.main : Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: selected ? zone.main : AppColors.border, width: 1.5),
          ),
          child: Text(
            label,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: selected ? Colors.white : AppColors.text),
          ),
        ),
      ),
    );
  }
}

// =========================================================
// STREFA 1: POZNAJ SWÓJ ORGANIZM (8 kroków)
// =========================================================
class Zone1Screen extends StatefulWidget {
  const Zone1Screen({super.key});

  @override
  State<Zone1Screen> createState() => _Zone1ScreenState();
}

class _Zone1ScreenState extends ZoneBaseState<Zone1Screen> {
  @override
  ZoneTheme get zone => zone1Theme;

  bool _task1 = false;
  bool _task2 = false;
  bool _task3 = false;
  int _secondsRemaining = 60;
  Timer? _timer;
  bool _isTimerRunning = false;
  bool _balanceDone = false;
  final TextEditingController _intentionController = TextEditingController();
  double _energy = 5;
  String? _emotion;

  @override
  List<Widget Function()> get steps => [
        _activity,
        _heartRate,
        _grounding,
        _powerPose,
        _quiz,
        _balance,
        _intention,
        _reflection,
      ];

  @override
  void onLeaveStage() {
    _timer?.cancel();
    _isTimerRunning = false;
  }

  @override
  void dispose() {
    _intentionController.dispose();
    super.dispose();
  }

  bool get _timerDone => _secondsRemaining == 0;

  void _startTimer() {
    if (_isTimerRunning || _timerDone) return;
    setState(() => _isTimerRunning = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _secondsRemaining--;
        if (_secondsRemaining <= 0) {
          _secondsRemaining = 0;
          _isTimerRunning = false;
          t.cancel();
        }
      });
    });
  }

  Widget _activity() {
    return stepCard(
      icon: Icons.directions_run_rounded,
      title: "Rozgrzewka",
      text: "Wykonaj wszystkie trzy ćwiczenia w swoim tempie i odhacz każde z nich.",
      buttonText: "Dalej",
      canContinue: _task1 && _task2 && _task3,
      children: [
        checkTile("20 pajacyków", _task1, (v) => setState(() => _task1 = v)),
        checkTile("10 przysiadów", _task2, (v) => setState(() => _task2 = v)),
        checkTile("1 minuta marszu", _task3, (v) => setState(() => _task3 = v)),
      ],
    );
  }

  Widget _heartRate() {
    return stepCard(
      icon: Icons.favorite_rounded,
      title: "Tętno",
      text: "Przyłóż dłoń do klatki piersiowej lub dwa palce do nadgarstka. Poczuj, jak szybko bije Twoje serce po wysiłku.",
      buttonText: "Czuję to! Idziemy dalej",
      canContinue: true,
      children: [
        illustration(Icons.monitor_heart_rounded, color: const Color(0xFFE53935)),
      ],
    );
  }

  Widget _grounding() {
    final String timerLabel = _timerDone
        ? "Gotowe!"
        : _isTimerRunning
            ? "Odliczanie w toku..."
            : "Rozpocznij 60 sekund";

    return stepCard(
      icon: Icons.visibility_rounded,
      title: "Uziemienie",
      text: "Znajdź 3 rzeczy, które widzisz, 2 dźwięki, które słyszysz, i 1 odczucie w ciele.",
      buttonText: "Wykonane, dalej",
      canContinue: _timerDone,
      children: [
        Center(
          child: SizedBox(
            width: 160,
            height: 160,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: _secondsRemaining / 60,
                  strokeWidth: 10,
                  backgroundColor: AppColors.track,
                  valueColor: AlwaysStoppedAnimation<Color>(zone.main),
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text("$_secondsRemaining", style: TextStyle(fontSize: 46, fontWeight: FontWeight.w900, color: zone.dark, height: 1.0)),
                      const Text("sekund", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.muted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        secondaryButton(
          timerLabel,
          (_isTimerRunning || _timerDone) ? null : _startTimer,
          icon: _timerDone ? Icons.check_rounded : Icons.timer_rounded,
        ),
        const SizedBox(height: 14),
      ],
    );
  }

  Widget _powerPose() {
    return stepCard(
      icon: Icons.accessibility_new_rounded,
      title: "Postawa Mocy",
      text: "Stań szeroko, podnieś ręce wysoko w górę w kształcie litery V, uśmiechnij się i weź 3 głębokie wdechy.",
      buttonText: "Czuję moc! Dalej",
      canContinue: true,
      children: [
        illustration(Icons.self_improvement_rounded, color: const Color(0xFFEF6C00)),
      ],
    );
  }

  Widget _quiz() {
    return quizStep(
      icon: Icons.quiz_rounded,
      title: "Quiz Wiedzy",
      question: "Co dzieje się z Twoim układem nerwowym, gdy robisz głęboki, powolny wydech?",
      options: const [
        "Dostaje sygnał do uspokojenia i zwalnia tętno",
        "Zwiększa się poziom stresu w organizmie",
        "Płuca całkowicie się kurczą na stałe",
      ],
      correct: "Dostaje sygnał do uspokojenia i zwalnia tętno",
      explanation: "Długi, spokojny wydech wycisza organizm – serce zwalnia, a ciało dostaje sygnał, że jest bezpieczne.",
      buttonText: "Dalej",
    );
  }

  Widget _balance() {
    return stepCard(
      icon: Icons.balance_rounded,
      title: "Balans",
      text: "Stań na jednej nodze i spróbuj utrzymać równowagę przez 20 sekund. Możesz pomóc sobie, rozkładając ręce na boki. W razie potrzeby przytrzymaj się krzesła.",
      buttonText: "Świetnie, idziemy dalej",
      canContinue: _balanceDone,
      children: [
        checkTile("Udało mi się utrzymać równowagę!", _balanceDone, (v) => setState(() => _balanceDone = v)),
      ],
    );
  }

  Widget _intention() {
    return stepCard(
      icon: Icons.edit_note_rounded,
      title: "Intencja",
      text: "Zapisz w jednym słowie lub krótkim zdaniu swoją intencję na resztę dnia (np. spokój, uśmiech, energia).",
      buttonText: "Zapisz intencję i dalej",
      canContinue: _intentionController.text.trim().isNotEmpty,
      children: [
        textInput(_intentionController, 'Wpisz swoją intencję...'),
      ],
    );
  }

  Widget _reflection() {
    return reflectionStep(
      title: "Twój Skan Końcowy",
      question: "Jak oceniasz teraz swoją energię?",
      value: _energy,
      onChanged: (v) => setState(() => _energy = v),
      emotionQuestion: "Jaką emocję teraz odczuwasz?",
      emotions: const ["Spokój 😌", "Energia ⚡", "Duma 💪", "Ulga 🍃"],
      selected: _emotion,
      onSelect: (e) => setState(() => _emotion = e),
    );
  }
}

// =========================================================
// STREFA 2: ODDECH I SPOKÓJ (7 kroków)
// =========================================================
class Zone2Screen extends StatefulWidget {
  const Zone2Screen({super.key});

  @override
  State<Zone2Screen> createState() => _Zone2ScreenState();
}

class _Zone2ScreenState extends ZoneBaseState<Zone2Screen> {
  @override
  ZoneTheme get zone => zone2Theme;

  int _cycle = 1;
  String _breathPhase = "Gotowy?";
  double _circleSize = 130.0;
  int _animationMs = 500;
  bool _isBreathing = false;
  bool _breathingDone = false;
  bool _bodyScanDone = false;
  bool _neckDone = false;
  final TextEditingController _needController = TextEditingController();
  String? _habit;
  double _calm = 5;
  String? _emotion;

  @override
  List<Widget Function()> get steps => [
        _breathing,
        _bodyScan,
        _quiz,
        _neck,
        _need,
        _habitStep,
        _reflection,
      ];

  @override
  void dispose() {
    _needController.dispose();
    super.dispose();
  }

  Future<void> _startBreathing() async {
    setState(() {
      _isBreathing = true;
      _breathingDone = false;
    });
    for (int i = 1; i <= 3; i++) {
      if (!mounted) return;
      setState(() {
        _cycle = i;
        _breathPhase = "Wdech...";
        _circleSize = 210.0;
        _animationMs = 4000;
      });
      await Future.delayed(const Duration(seconds: 4));
      if (!mounted) return;
      setState(() {
        _breathPhase = "Zatrzymaj...";
        _animationMs = 100;
      });
      await Future.delayed(const Duration(seconds: 4));
      if (!mounted) return;
      setState(() {
        _breathPhase = "Wydech...";
        _circleSize = 120.0;
        _animationMs = 6000;
      });
      await Future.delayed(const Duration(seconds: 6));
    }
    if (!mounted) return;
    setState(() {
      _breathPhase = "Świetnie!";
      _isBreathing = false;
      _breathingDone = true;
      _circleSize = 150.0;
      _animationMs = 1000;
    });
  }

  Widget _breathing() {
    return stepCard(
      icon: Icons.air_rounded,
      title: "Trening Oddechu 4-4-6",
      text: "Wdech przez 4 sekundy, zatrzymanie na 4, powolny wydech przez 6. Powtórzymy to 3 razy. Patrz na koło i oddychaj razem z nim.",
      buttonText: "Dalej",
      canContinue: _breathingDone,
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(color: zone.tint, borderRadius: BorderRadius.circular(20)),
            child: Text("Cykl $_cycle z 3", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: zone.dark)),
          ),
        ),
        SizedBox(
          height: 230,
          child: Center(
            child: AnimatedContainer(
              duration: Duration(milliseconds: _animationMs),
              curve: Curves.easeInOutSine,
              width: _circleSize,
              height: _circleSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: zone.gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
                boxShadow: [BoxShadow(color: fade(zone.main, 0.35), blurRadius: 30, spreadRadius: 4)],
              ),
              child: Center(
                child: Text(_breathPhase, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
              ),
            ),
          ),
        ),
        if (!_isBreathing && !_breathingDone) ...[
          secondaryButton("Rozpocznij oddech", _startBreathing),
          const SizedBox(height: 14),
        ],
      ],
    );
  }

  Widget _bodyScan() {
    return stepCard(
      icon: Icons.self_improvement_rounded,
      title: "Skan Ciała",
      text: "Skieruj uwagę na swoje barki i szczękę. Często nieświadomie trzymamy tam napięcie. Rozluźnij je teraz na 3 sekundy.",
      buttonText: "Idziemy dalej",
      canContinue: _bodyScanDone,
      children: [
        checkTile("Rozluźniłem ramiona i szczękę", _bodyScanDone, (v) => setState(() => _bodyScanDone = v)),
      ],
    );
  }

  Widget _quiz() {
    return quizStep(
      icon: Icons.lightbulb_rounded,
      title: "Sytuacja z życia",
      question: "Masz ważne zadanie i czujesz silny stres. Serce bije Ci szybciej. Co pomoże Ci najlepiej odzyskać spokój w tej chwili?",
      options: const [
        "Wypicie 3 filiżanek kawy",
        "Krótkie ćwiczenie oddechowe (np. 4-4-6)",
        "Scrollowanie social mediów",
      ],
      correct: "Krótkie ćwiczenie oddechowe (np. 4-4-6)",
      explanation: "Oddech to najszybszy sposób na „oszukanie” układu nerwowego i wysłanie sygnału: jestem bezpieczny.",
      buttonText: "Zrozumiałem, idziemy dalej",
    );
  }

  Widget _neck() {
    return stepCard(
      icon: Icons.accessibility_rounded,
      title: "Ruch Szyi",
      text: "Wykonaj powolny skłon głowy do prawego ramienia, a potem do lewego. Poczuj ulgę w mięśniach karku.",
      buttonText: "Czuję ulgę, dalej",
      canContinue: _neckDone,
      children: [
        checkTile("Rozciągnąłem kark i odetchnąłem", _neckDone, (v) => setState(() => _neckDone = v)),
      ],
    );
  }

  Widget _need() {
    return stepCard(
      icon: Icons.spa_rounded,
      title: "Mini Spokój",
      text: "Napisz jedno słowo oznaczające to, czego najbardziej potrzebujesz dzisiaj (np. cisza, herbata, odpoczynek).",
      buttonText: "Zatwierdź i dalej",
      canContinue: _needController.text.trim().isNotEmpty,
      children: [
        textInput(_needController, 'Wpisz swoje słowo...'),
      ],
    );
  }

  Widget _habitStep() {
    const List<String> habits = [
      "Wykonywanie 5 głębokich oddechów przed zadaniem",
      "Krótki spacer bez telefonu",
      "Rozmowa o swoich emocjach z bliską osobą",
    ];
    return stepCard(
      icon: Icons.psychology_rounded,
      title: "Jeden mały krok",
      text: "Wybierz jedną metodę radzenia sobie ze stresem, którą spróbujesz zastosować w tym tygodniu:",
      buttonText: "Dalej",
      canContinue: _habit != null,
      children: [
        for (final String h in habits) optionTile(h, selected: _habit == h, onTap: () => setState(() => _habit = h)),
      ],
    );
  }

  Widget _reflection() {
    return reflectionStep(
      title: "Skan Spokoju",
      question: "Jak oceniasz teraz swój wewnętrzny spokój?",
      value: _calm,
      onChanged: (v) => setState(() => _calm = v),
      emotionQuestion: "Jaka emocja dominuje?",
      emotions: const ["Spokój 😌", "Lekkość 🍃", "Skupienie 🎯", "Ulga ✨"],
      selected: _emotion,
      onSelect: (e) => setState(() => _emotion = e),
    );
  }
}

// =========================================================
// STREFA 3: EMOCJE W RUCHU (8 kroków)
// =========================================================
class Zone3Screen extends StatefulWidget {
  const Zone3Screen({super.key});

  @override
  State<Zone3Screen> createState() => _Zone3ScreenState();
}

class _Zone3ScreenState extends ZoneBaseState<Zone3Screen> {
  @override
  ZoneTheme get zone => zone3Theme;

  bool _shakeDone = false;
  bool _danceDone = false;
  bool _stretchDone = false;
  bool _poseDone = false;
  final TextEditingController _positivesController = TextEditingController();
  final TextEditingController _promiseController = TextEditingController();
  double _mood = 5;
  String? _emotion;

  @override
  List<Widget Function()> get steps => [
        _shake,
        _dance,
        _quiz,
        _stretch,
        _triumph,
        _positives,
        _promise,
        _reflection,
      ];

  @override
  void dispose() {
    _positivesController.dispose();
    _promiseController.dispose();
    super.dispose();
  }

  Widget _shake() {
    return stepCard(
      icon: Icons.bolt_rounded,
      title: "Strząśnij Napięcie",
      text: "Przez 20 sekund energicznie potrząśnij rękami oraz nogami (możesz to robić na siedząco). Wyobraź sobie, że zrzucasz z siebie wszelki stres.",
      buttonText: "Czuję luz, idziemy dalej",
      canContinue: _shakeDone,
      children: [
        checkTile("Strząsnąłem napięcie z całego ciała", _shakeDone, (v) => setState(() => _shakeDone = v)),
      ],
    );
  }

  Widget _dance() {
    return stepCard(
      icon: Icons.music_note_rounded,
      title: "Taniec Ekspresji",
      text: "Włącz w głowie ulubioną piosenkę i zatańcz przez minutę tak, jakby nikt na Ciebie nie patrzył. Poczuj radość w ruchu!",
      buttonText: "Super, dalej",
      canContinue: _danceDone,
      children: [
        checkTile("Zatańczyłem z radością", _danceDone, (v) => setState(() => _danceDone = v)),
      ],
    );
  }

  Widget _quiz() {
    return quizStep(
      icon: Icons.psychology_rounded,
      title: "Labirynt Emocji",
      question: "Ktoś bliski w ostatniej chwili odwołał wasze długo wyczekiwane spotkanie. Jaką emocję możesz w tej sytuacji odczuwać?",
      options: const ["Smutek", "Złość", "Rozczarowanie", "Wszystkie powyższe"],
      correct: null, // każda odpowiedź jest dobra
      explanation: "Każda z tych reakcji jest prawidłowa! Różni ludzie reagują na to samo zdarzenie zupełnie inaczej.",
      buttonText: "To ma sens",
    );
  }

  Widget _stretch() {
    return stepCard(
      icon: Icons.self_improvement_rounded,
      title: "Skłon Ulgowy",
      text: "Zrób głęboki wdech, a z wydechem zrób luźny skłon w przód – opuść ramiona i głowę w dół. Wyobraź sobie, że z każdym wydechem oddajesz zmartwienia ziemi.",
      buttonText: "Dalej",
      canContinue: _stretchDone,
      children: [
        checkTile("Wykonałem skłon i wypuściłem napięcie", _stretchDone, (v) => setState(() => _stretchDone = v)),
      ],
    );
  }

  Widget _triumph() {
    return stepCard(
      icon: Icons.emoji_events_rounded,
      title: "Triumf",
      text: "Podnieś ręce wysoko w geście zwycięstwa (jak na mecie maratonu). Poczuj dumę z tego, że dbasz o siebie.",
      buttonText: "Czuję siłę, dalej",
      canContinue: _poseDone,
      children: [
        checkTile("Przybrałem postawę zwycięzcy", _poseDone, (v) => setState(() => _poseDone = v)),
      ],
    );
  }

  Widget _positives() {
    return stepCard(
      icon: Icons.favorite_border_rounded,
      title: "Pozytywy",
      text: "Zapisz jedną, nawet najmniejszą rzecz, która dziś wywołała u Ciebie uśmiech lub ulgę.",
      buttonText: "Zapisz i dalej",
      canContinue: _positivesController.text.trim().isNotEmpty,
      children: [
        textInput(_positivesController, 'Np. dobra kawa, słońce, miłe słowo...'),
      ],
    );
  }

  Widget _promise() {
    return stepCard(
      icon: Icons.lightbulb_rounded,
      title: "Obietnica",
      text: "Napisz, co miłego zrobisz dziś dla siebie (np. krótka przerwa bez ekranu, spacer).",
      buttonText: "Zatwierdź i dalej",
      canContinue: _promiseController.text.trim().isNotEmpty,
      children: [
        textInput(_promiseController, 'Moja obietnica to...'),
      ],
    );
  }

  Widget _reflection() {
    return reflectionStep(
      title: "Skan Emocji",
      question: "Jak oceniasz teraz swój nastrój?",
      value: _mood,
      onChanged: (v) => setState(() => _mood = v),
      emotionQuestion: "Wybierz emocję po ćwiczeniach:",
      emotions: const ["Spokój 😌", "Radość ✨", "Siła 💪", "Lekkość 🍃"],
      selected: _emotion,
      onSelect: (e) => setState(() => _emotion = e),
    );
  }
}

// =========================================================
// STREFA 4: SIŁA WSPÓŁPRACY (8 kroków)
// =========================================================
class Zone4Screen extends StatefulWidget {
  const Zone4Screen({super.key});

  @override
  State<Zone4Screen> createState() => _Zone4ScreenState();
}

class _Zone4ScreenState extends ZoneBaseState<Zone4Screen> {
  @override
  ZoneTheme get zone => zone4Theme;

  bool _teamDone = false;
  bool _complimentDone = false;
  bool _listeningDone = false;
  bool _helpDone = false;
  final TextEditingController _teamGoalController = TextEditingController();
  final TextEditingController _thanksController = TextEditingController();
  double _teamwork = 5;
  String? _emotion;

  @override
  List<Widget Function()> get steps => [
        _teamPhysical,
        _riddle,
        _compliment,
        _listening,
        _help,
        _teamGoal,
        _thanks,
        _reflection,
      ];

  @override
  void dispose() {
    _teamGoalController.dispose();
    _thanksController.dispose();
    super.dispose();
  }

  Widget _teamPhysical() {
    return stepCard(
      icon: Icons.handshake_rounded,
      title: "Razem Raźniej",
      text: "Wspólnie z kimś z rodziny lub znajomym przenieście dowolny lekki przedmiot z jednego końca pokoju na drugi – bez użycia dłoni!",
      buttonText: "Przejdź dalej",
      canContinue: _teamDone,
      children: [
        checkTile("Udało się!", _teamDone, (v) => setState(() => _teamDone = v)),
      ],
    );
  }

  Widget _riddle() {
    return quizStep(
      icon: Icons.auto_awesome_rounded,
      title: "Zagadka",
      question: "Co rośnie tym bardziej, im więcej się tym dzielisz z innymi ludźmi?",
      options: const ["Zmartwienia", "Szczęście i wiedza", "Pieniądze"],
      correct: "Szczęście i wiedza",
      explanation: "Dzielenie się swoimi zasobami i pozytywną energią buduje więzi.",
      buttonText: "Dalej",
    );
  }

  Widget _compliment() {
    return stepCard(
      icon: Icons.thumb_up_rounded,
      title: "Miłe Słowo",
      text: "Powiedz komuś w pobliżu, zadzwoń lub napisz w wiadomości miły komplement albo słowo uznania.",
      buttonText: "Dalej",
      canContinue: _complimentDone,
      children: [
        checkTile("Powiedziałem komuś miłe słowo", _complimentDone, (v) => setState(() => _complimentDone = v)),
      ],
    );
  }

  Widget _listening() {
    return stepCard(
      icon: Icons.hearing_rounded,
      title: "Uważne Słuchanie",
      text: "Przeprowadź z kimś krótką rozmowę, w której w pełni skupisz się na wysłuchaniu drugiej osoby – bez przerywania i patrzenia w telefon.",
      buttonText: "Dalej",
      canContinue: _listeningDone,
      children: [
        checkTile("Wysłuchałem kogoś z pełną uwagą", _listeningDone, (v) => setState(() => _listeningDone = v)),
      ],
    );
  }

  Widget _help() {
    return stepCard(
      icon: Icons.volunteer_activism_rounded,
      title: "Gotowość do Pomocy",
      text: "Zaoferuj komuś drobną pomoc, np. w zakupach lub codziennych obowiązkach.",
      buttonText: "Dalej",
      canContinue: _helpDone,
      children: [
        checkTile("Zaoferowałem pomoc", _helpDone, (v) => setState(() => _helpDone = v)),
      ],
    );
  }

  Widget _teamGoal() {
    return stepCard(
      icon: Icons.flag_rounded,
      title: "Wspólny Cel",
      text: "Napisz, jaki cel mogłaby osiągnąć Twoja rodzina lub grupa znajomych, działając razem.",
      buttonText: "Zatwierdź i dalej",
      canContinue: _teamGoalController.text.trim().isNotEmpty,
      children: [
        textInput(_teamGoalController, 'Wpisz wspólny cel...'),
      ],
    );
  }

  Widget _thanks() {
    return stepCard(
      icon: Icons.forum_rounded,
      title: "Słowo Dziękuję",
      text: "Pomyśl o kimś, kto Ci pomógł. Zapisz, za co chciałbyś tej osobie podziękować.",
      buttonText: "Zapisz i dalej",
      canContinue: _thanksController.text.trim().isNotEmpty,
      children: [
        textInput(_thanksController, 'Dziękuję za...', maxLines: 3),
      ],
    );
  }

  Widget _reflection() {
    return reflectionStep(
      title: "Skan Więzi",
      question: "Jak oceniasz swoje poczucie wsparcia i bliskości z innymi?",
      value: _teamwork,
      onChanged: (v) => setState(() => _teamwork = v),
      emotionQuestion: "Jaka emocja teraz przeważa?",
      emotions: const ["Wdzięczność 🥰", "Radość 🎉", "Przynależność 🤝", "Spokój 🍃"],
      selected: _emotion,
      onSelect: (e) => setState(() => _emotion = e),
    );
  }
}

// =========================================================
// STREFA 5: MÓJ KOMPAS ZDROWIA (7 kroków)
// =========================================================
class Zone5Screen extends StatefulWidget {
  const Zone5Screen({super.key});

  @override
  State<Zone5Screen> createState() => _Zone5ScreenState();
}

class _Zone5ScreenState extends ZoneBaseState<Zone5Screen> {
  @override
  ZoneTheme get zone => zone5Theme;

  bool _sprintDone = false;
  String? _focusArea;
  String? _mainGoal;
  final List<bool> _habits = [false, false, false, false, false];
  final TextEditingController _supportController = TextEditingController();
  final TextEditingController _obstacleController = TextEditingController();
  double _confidence = 5;
  String? _symbol;

  static const List<String> _habitTexts = [
    "Spacer min. 20 minut dziennie",
    "Aktywność fizyczna 3 razy w tygodniu",
    "Ćwiczenie oddechowe (np. 4-4-6) raz dziennie",
    "Rozmowa z bliską osobą bez patrzenia w telefon",
    "Odłożenie ekranów na godzinę przed snem",
  ];

  @override
  List<Widget Function()> get steps => [
        _sprint,
        _focusStep,
        _goalStep,
        _habitsStep,
        _support,
        _obstacle,
        _confidenceStep,
      ];

  @override
  void dispose() {
    _supportController.dispose();
    _obstacleController.dispose();
    super.dispose();
  }

  Widget _sprint() {
    return stepCard(
      icon: Icons.timer_rounded,
      title: "Marsz do Mety",
      text: "Ostatnia prosta! Maszeruj w miejscu przez pełną minutę w wygodnym dla siebie tempie, zanim ułożysz swój plan.",
      buttonText: "Stwórz Plan Dobrostanu",
      canContinue: _sprintDone,
      children: [
        checkTile("Gotowe!", _sprintDone, (v) => setState(() => _sprintDone = v)),
      ],
    );
  }

  Widget _focusStep() {
    const List<String> areas = [
      "Zdrowie fizyczne i ruch 💪",
      "Spokój i zdrowie psychiczne 🍃",
      "Relacje i bliscy 🤝",
      "Sen i regeneracja 🌙",
    ];
    return stepCard(
      icon: Icons.center_focus_strong_rounded,
      title: "Bilans Sił",
      text: "Na którym obszarze chcesz się najbardziej skupić w tym tygodniu?",
      buttonText: "Dalej",
      canContinue: _focusArea != null,
      children: [
        for (final String a in areas) optionTile(a, selected: _focusArea == a, onTap: () => setState(() => _focusArea = a)),
      ],
    );
  }

  Widget _goalStep() {
    const List<String> goals = [
      "Więcej ruchu na świeżym powietrzu",
      "Więcej uważności na oddech i mniej stresu",
      "Regularny kontakt z bliskimi i życzliwość",
      "Stała, zdrowa ilość snu",
    ];
    return stepCard(
      icon: Icons.flag_rounded,
      title: "Główny Cel Tygodnia",
      text: "Wybierz jedną, najważniejszą intencję na najbliższe dni:",
      buttonText: "Dalej",
      canContinue: _mainGoal != null,
      children: [
        for (final String g in goals) optionTile(g, selected: _mainGoal == g, onTap: () => setState(() => _mainGoal = g)),
      ],
    );
  }

  Widget _habitsStep() {
    return stepCard(
      icon: Icons.checklist_rounded,
      title: "Kodeks Nawyków",
      text: "Zaznacz nawyki, które zobowiązujesz się realizować:",
      buttonText: "Zatwierdź nawyki",
      canContinue: _habits.contains(true),
      children: [
        for (int i = 0; i < _habitTexts.length; i++)
          checkTile(_habitTexts[i], _habits[i], (v) => setState(() => _habits[i] = v)),
      ],
    );
  }

  Widget _support() {
    return stepCard(
      icon: Icons.people_rounded,
      title: "Moje Wsparcie",
      text: "Na kogo lub na co możesz liczyć w trudniejszych momentach?",
      buttonText: "Zatwierdź i dalej",
      canContinue: _supportController.text.trim().isNotEmpty,
      children: [
        textInput(_supportController, 'Np. przyjaciel, rodzina, sąsiad...'),
      ],
    );
  }

  Widget _obstacle() {
    return stepCard(
      icon: Icons.shield_rounded,
      title: "Plan Awaryjny",
      text: "Co zrobię, gdy poczuję silny stres lub spadek formy?",
      buttonText: "Zatwierdź plan",
      canContinue: _obstacleController.text.trim().isNotEmpty,
      children: [
        textInput(_obstacleController, 'Np. 5 głębokich oddechów i spacer...'),
      ],
    );
  }

  Widget _confidenceStep() {
    return reflectionStep(
      title: "Skan Gotowości",
      question: "Jak oceniasz swoją gotowość na ten tydzień?",
      value: _confidence,
      onChanged: (v) => setState(() => _confidence = v),
      emotionQuestion: "Wybierz słowo podsumowujące:",
      emotions: const ["Gotowy 🚀", "Spokojny 🍃", "Silny 💪", "Zmotywowany ⭐"],
      selected: _symbol,
      onSelect: (e) => setState(() => _symbol = e),
    );
  }
}

// =========================================================
// WYNIKI I STATYSTYKI
// =========================================================
class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            const ScreenHeader(title: "Wyniki i statystyki"),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: AppColors.blueGradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [BoxShadow(color: fade(const Color(0xFF1565C0), 0.3), blurRadius: 24, offset: const Offset(0, 10))],
              ),
              child: Column(
                children: [
                  const Icon(Icons.military_tech_rounded, color: Colors.white, size: 52),
                  const SizedBox(height: 6),
                  Text("Twoja ranga", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: fade(Colors.white, 0.85))),
                  const SizedBox(height: 2),
                  Text(
                    AppState.rank,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(child: _heroStat("${AppState.userPoints}", "z ${AppState.maxPoints} pkt")),
                      Container(width: 1, height: 44, color: fade(Colors.white, 0.3)),
                      Expanded(child: _heroStat("${AppState.completedCount}", "z ${AppState.zoneCount} stref")),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            const SectionTitle("Postęp w strefach"),
            const SizedBox(height: 12),
            for (final ZoneTheme z in allZones)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _zoneRow(z),
              ),
          ],
        ),
      ),
    );
  }

  Widget _heroStat(String value, String label) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: Colors.white)),
        Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: fade(Colors.white, 0.85))),
      ],
    );
  }

  Widget _zoneRow(ZoneTheme z) {
    final int i = z.index;
    final bool done = AppState.completed[i];
    final bool inProgress = AppState.isInProgress(i);
    final double progress = done ? 1.0 : (inProgress ? (AppState.savedStage[i] - 1) / z.stepCount : 0.0);

    String status = "Nierozpoczęta";
    Color statusColor = AppColors.muted;
    if (done) {
      status = "Ukończona ✓";
      statusColor = const Color(0xFF2E7D32);
    } else if (inProgress) {
      status = "W trakcie";
      statusColor = const Color(0xFFE65100);
    }

    return SoftCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconBadge(icon: z.icon, colors: z.gradient, size: 48),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(z.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.text)),
                    ),
                    const SizedBox(width: 8),
                    Text(status, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: statusColor)),
                  ],
                ),
                const SizedBox(height: 10),
                roundedProgress(progress, z.main, height: 6),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =========================================================
// CERTYFIKAT
// =========================================================
class CertificateScreen extends StatelessWidget {
  const CertificateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final int points = AppState.userPoints;
    final int threshold = AppState.certificateThreshold;
    final bool canUnlock = points >= threshold;
    final String userName = AppState.userName;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            const ScreenHeader(title: "Certyfikat"),
            const SizedBox(height: 24),
            if (canUnlock)
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: AppColors.goldGradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [BoxShadow(color: fade(const Color(0xFFFF8F00), 0.35), blurRadius: 30, offset: const Offset(0, 12))],
                ),
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(27)),
                  child: Column(
                    children: [
                      const IconBadge(icon: Icons.workspace_premium_rounded, colors: AppColors.goldGradient, size: 76),
                      const SizedBox(height: 18),
                      const Text(
                        "CERTYFIKAT",
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 4, color: AppColors.muted),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Ambasador Dobrostanu",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.primaryDark),
                      ),
                      const SizedBox(height: 22),
                      const Text("przyznany dla", style: TextStyle(fontSize: 15, color: AppColors.muted)),
                      const SizedBox(height: 6),
                      Text(
                        userName.isNotEmpty ? userName : "Ciebie!",
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, fontStyle: FontStyle.italic, color: AppColors.primary),
                      ),
                      const SizedBox(height: 20),
                      const Divider(color: AppColors.border, thickness: 1.5),
                      const SizedBox(height: 16),
                      const Text(
                        "Za pomyślne ukończenie wyzwań i podjęcie kroków ku lepszemu zdrowiu psychicznemu i fizycznemu.",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, height: 1.5, color: AppColors.text),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(color: const Color(0xFFFFF8E1), borderRadius: BorderRadius.circular(30)),
                        child: Text(
                          "⭐ $points / ${AppState.maxPoints} pkt",
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF8D6E63)),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SoftCard(
                padding: const EdgeInsets.all(28),
                child: Column(
                  children: [
                    Container(
                      width: 104,
                      height: 104,
                      decoration: const BoxDecoration(color: Color(0xFFF1F3F1), shape: BoxShape.circle),
                      child: const Icon(Icons.lock_rounded, size: 50, color: Color(0xFF98A39B)),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      "Certyfikat zablokowany",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.text),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Zdobądź $threshold punktów (czyli ukończ ${threshold ~/ AppState.pointsPerZone} strefy), aby odblokować certyfikat Ambasadora Dobrostanu.",
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, color: AppColors.muted, height: 1.5),
                    ),
                    const SizedBox(height: 22),
                    roundedProgress(points / threshold, const Color(0xFFFFB300), height: 12),
                    const SizedBox(height: 10),
                    Text(
                      "$points / $threshold pkt • brakuje ${threshold - points} pkt",
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 28),
            BigButton(label: "Powrót do menu", icon: Icons.home_rounded, onPressed: () => Navigator.pop(context)),
          ],
        ),
      ),
    );
  }
}

// =========================================================
// PROFIL (imię + reset aplikacji)
// =========================================================
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _nameController.text = AppState.userName;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    AppState.userName = _nameController.text.trim();
    await AppState.save();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Zapisano imię!', style: TextStyle(fontSize: 16)),
        backgroundColor: AppColors.primaryDark,
      ),
    );
    Navigator.pop(context);
  }

  void _resetApp() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          title: const Text("Zresetować aplikację?"),
          content: const Text(
            "Wszystkie punkty, imię oraz ukończone strefy zostaną wyczyszczone.",
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Anuluj", style: TextStyle(fontSize: 16)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFD32F2F)),
              onPressed: () async {
                Navigator.pop(dialogContext);
                await AppState.reset();
                if (!mounted) return;
                setState(() => _nameController.clear());
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Zresetowano postęp aplikacji.', style: TextStyle(fontSize: 16)),
                    backgroundColor: Color(0xFFD32F2F),
                  ),
                );
              },
              child: const Text("Resetuj", style: TextStyle(fontSize: 16)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final String typed = _nameController.text.trim();

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            const ScreenHeader(title: "Twój profil"),
            const SizedBox(height: 28),
            Center(
              child: Container(
                width: 112,
                height: 112,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: AppColors.greenGradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: fade(AppColors.primaryDark, 0.3), blurRadius: 20, offset: const Offset(0, 8))],
                ),
                child: Center(
                  child: typed.isNotEmpty
                      ? Text(typed[0].toUpperCase(), style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w800, color: Colors.white))
                      : const Icon(Icons.person_rounded, color: Colors.white, size: 60),
                ),
              ),
            ),
            const SizedBox(height: 28),
            SoftCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    "Jak mamy się do Ciebie zwracać?",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.text),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _nameController,
                    onChanged: (_) => setState(() {}),
                    textCapitalization: TextCapitalization.words,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: 'Wpisz swoje imię...',
                      filled: true,
                      fillColor: const Color(0xFFF3F5F3),
                      contentPadding: const EdgeInsets.all(18),
                      prefixIcon: const Icon(Icons.badge_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: const BorderSide(color: AppColors.border, width: 1.5),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: const BorderSide(color: AppColors.primary, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  BigButton(label: "Zapisz zmiany", icon: Icons.check_rounded, onPressed: _saveName),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(18)),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: AppColors.primary),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Twój postęp zapisuje się automatycznie na tym urządzeniu.",
                      style: TextStyle(fontSize: 15, color: AppColors.primaryDark, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              height: 54,
              child: OutlinedButton.icon(
                onPressed: _resetApp,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text("Zresetuj aplikację", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFD32F2F),
                  side: const BorderSide(color: Color(0xFFEF9A9A), width: 1.5),
                  shape: const StadiumBorder(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
