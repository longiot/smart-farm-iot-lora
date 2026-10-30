import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'services/mqtt_service.dart';
import 'services/schedule_service.dart';
import 'services/note_service.dart';
import 'utils/threshold_manager.dart';
import 'screens/dashboard_screen.dart';
import 'screens/alerts_screen.dart';
import 'screens/history_screen.dart';
import 'screens/note_screen.dart';
import 'screens/settings_screen.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'screens/login_screen.dart';
import 'screens/device_list_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await ThresholdManager.init();

  // Khởi tạo Firebase
  try {
    if (kIsWeb) {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: 'FIREBASE_API_KEY',
          appId: '1:909325866215:android:57972e637fea97fa02be42',
          messagingSenderId: '909325866215',
          projectId: 'appnongnghiep-f9d6f',
          storageBucket: 'appnongnghiep-f9d6f.firebasestorage.app',
        ),
      );
    } else {
      await Firebase.initializeApp();
    }
  } catch (e) {
    debugPrint('[Firebase] Init: $e');
  }

  // Khởi tạo NoteService
  final noteService = NoteService();
  await noteService.init();

  // Khởi tạo ScheduleService (callback sẽ được set sau khi MqttService sẵn sàng)
  final scheduleService = ScheduleService();
  await scheduleService.init();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<MqttService>(
          create: (_) {
            final mqtt = MqttService()..connect();
            // Kết nối ScheduleService với MqttService để gửi lịch trình
            scheduleService.setMqttPublisher((topic, payload) {
              mqtt.publishRetained(topic, payload);
            });
            // Tự động gửi lại lịch khi MQTT kết nối lại (đảm bảo đồng bộ offline/online)
            mqtt.addListener(() {
              if (mqtt.isConnected) {
                scheduleService.syncToMqtt();
              }
            });
            return mqtt;
          },
        ),
        ChangeNotifierProvider<ScheduleService>.value(value: scheduleService),
        ChangeNotifierProvider<NoteService>.value(value: noteService),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ESP32 Nông nghiệp',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.transparent,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF16A34A),
          brightness: Brightness.light,
        ),
        textTheme: GoogleFonts.interTextTheme(),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          surfaceTintColor: Colors.transparent,
          titleTextStyle: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData) {
          // Đã đăng nhập
          return const DeviceListScreen();
        }
        // Chưa đăng nhập
        return LoginScreen();
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  MainShell
// ─────────────────────────────────────────────────────────────────
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  static const List<_NavItem> _items = [
    _NavItem(icon: Icons.dashboard_rounded,     label: 'Trang chủ'),
    _NavItem(icon: Icons.notifications_rounded, label: 'Cảnh báo'),
    _NavItem(icon: Icons.show_chart_rounded,    label: 'Lịch sử'),
    _NavItem(icon: Icons.note_alt_rounded,      label: 'Ghi chú'),
    _NavItem(icon: Icons.settings_rounded,      label: 'Cài đặt'),
  ];

  static const _titles = [
    'Trang chủ',
    'Cảnh báo',
    'Lịch sử',
    'Ghi chú',
    'Cài đặt',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,

      // ── AppBar ──────────────────────────────────────────────
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          _titles[_currentIndex],
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            shadows: [
              Shadow(
                color: Colors.black.withOpacity(0.35),
                blurRadius: 6,
                offset: const Offset(0, 1),
              ),
            ],
          ),
        ),
        actions: [
          Consumer<MqttService>(
            builder: (_, mqtt, __) => Padding(
              padding: const EdgeInsets.only(right: 16),
              child: _MqttStatusDot(isConnected: mqtt.isConnected),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white, size: 20),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
            },
            tooltip: 'Đăng xuất',
          ),
          const SizedBox(width: 8),
        ],
        // Subtle gradient underlay so text is readable
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF052e16).withOpacity(0.72),
                Colors.transparent,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ),

      // ── Body: background stack + IndexedStack ────────────────
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Full-screen nature background image
          Image.network(
            'https://images.unsplash.com/photo-1500382017468-9049fed747ef?w=1200&auto=format&fit=crop',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: const Color(0xFF166534),
            ),
          ),
          // Dark green overlay for readability
          Container(
            color: const Color(0xFF052e16).withOpacity(0.55),
          ),
          // Screen content
          IndexedStack(
            index: _currentIndex,
            children: const [
              DashboardScreen(),
              AlertsScreen(),
              HistoryScreen(),
              NoteScreen(),
              SettingsScreen(),
            ],
          ),
        ],
      ),

      // ── Floating Pill Bottom Nav ─────────────────────────────
      bottomNavigationBar: Consumer<MqttService>(
        builder: (_, mqtt, __) {
          int badgeCount = 0;
          if (!mqtt.isConnected) badgeCount++;
          if (mqtt.isDataStale) badgeCount++;
          final data = mqtt.latest;
          if (!data.tempValid || !data.lightValid) badgeCount++;
          if (!data.sdReady) badgeCount++;

          return SafeArea(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.97),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF16A34A).withOpacity(0.18),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.10),
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: _items.asMap().entries.map((e) {
                    final i = e.key;
                    final item = e.value;
                    final selected = i == _currentIndex;
                    final hasBadge = i == 1 && badgeCount > 0;

                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _currentIndex = i),
                        behavior: HitTestBehavior.opaque,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeInOut,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            color: selected
                                ? const Color(0xFF16A34A).withOpacity(0.12)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Icon with optional badge
                              hasBadge
                                  ? Badge(
                                      label: Text(
                                        '$badgeCount',
                                        style: GoogleFonts.inter(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      backgroundColor: const Color(0xFFEF4444),
                                      child: _NavIcon(
                                          icon: item.icon,
                                          selected: selected),
                                    )
                                  : _NavIcon(
                                      icon: item.icon, selected: selected),
                              const SizedBox(height: 3),
                              // Label always shows
                              AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 200),
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: selected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: selected
                                      ? const Color(0xFF16A34A)
                                      : const Color(0xFF94A3B8),
                                ),
                                child: Text(item.label),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Nav icon helper ──────────────────────────────────────────────
class _NavIcon extends StatelessWidget {
  final IconData icon;
  final bool selected;
  const _NavIcon({required this.icon, required this.selected});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: 36,
      height: 28,
      decoration: BoxDecoration(
        color: selected
            ? const Color(0xFF16A34A)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        icon,
        size: 18,
        color: selected ? Colors.white : const Color(0xFF94A3B8),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}

// ── MQTT connection status dot in AppBar ─────────────────────────
class _MqttStatusDot extends StatelessWidget {
  final bool isConnected;
  const _MqttStatusDot({required this.isConnected});

  @override
  Widget build(BuildContext context) {
    final color = isConnected
        ? const Color(0xFF4ADE80)
        : const Color(0xFFFF7070);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.6),
                blurRadius: 6,
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Text(
          isConnected ? 'MQTT' : 'Offline',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
            shadows: [
              Shadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 4,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
