import 'package:accounting_app/core/presentation/navigation/adaptive_page_route.dart';
import 'package:accounting_app/core/theme/theme_service.dart';
import 'package:accounting_app/features/accounting/presentation/home_screen.dart';
import 'package:accounting_app/features/security/presentation/biometric_lock_gate.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  ThemeService.instance.initialize();
  runApp(const AccountingApp());
}

class AccountingApp extends StatelessWidget {
  const AccountingApp({super.key});

  @override
  Widget build(BuildContext context) {
    final lightScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF059669),
      primary: const Color(0xFF047857),
      secondary: const Color(0xFF0284C7),
      brightness: Brightness.light,
    );
    final darkScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF10B981),
      primary: const Color(0xFF34D399),
      secondary: const Color(0xFF38BDF8),
      brightness: Brightness.dark,
    );

    return AnimatedBuilder(
      animation: ThemeService.instance,
      builder: (context, _) => MaterialApp(
        title: 'Accounting App',
        debugShowCheckedModeBanner: false,
        themeMode: ThemeService.instance.themeMode,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: lightScheme,
          scaffoldBackgroundColor: const Color(0xFFF8FAFC),
          pageTransitionsTheme: const PageTransitionsTheme(
            builders: {
              TargetPlatform.windows: DesktopFadePageTransitionsBuilder(),
              TargetPlatform.linux: DesktopFadePageTransitionsBuilder(),
              TargetPlatform.macOS: DesktopFadePageTransitionsBuilder(),
            },
          ),
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          colorScheme: darkScheme,
          scaffoldBackgroundColor: const Color(0xFF0B131E),
          pageTransitionsTheme: const PageTransitionsTheme(
            builders: {
              TargetPlatform.windows: DesktopFadePageTransitionsBuilder(),
              TargetPlatform.linux: DesktopFadePageTransitionsBuilder(),
              TargetPlatform.macOS: DesktopFadePageTransitionsBuilder(),
            },
          ),
        ),
        home: const BiometricLockGate(
          child: HomeScreen(),
        ),
      ),
    );
  }
}
