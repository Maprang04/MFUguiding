import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_theme.dart';
import 'app_shells.dart';
import 'fail_screen.dart';
import 'loading_screen.dart';
import 'login_screen.dart';
import 'session_manager.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: AppColors.burgundy,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: AppColors.burgundy,
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarDividerColor: AppColors.burgundy,
    ),
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MFU SmartGuide',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const SessionBootstrap(),
      routes: {
        '/loading': (_) => const LoadingScreen(),
        '/login': (_) => const LoginScreen(),
        '/map': (_) => const UserAppShell(),
        '/fail': (_) => const FailScreen(),
      },
    );
  }
}

class SessionBootstrap extends StatefulWidget {
  const SessionBootstrap({super.key});

  @override
  State<SessionBootstrap> createState() => _SessionBootstrapState();
}

class _SessionBootstrapState extends State<SessionBootstrap> {
  Widget? _destination;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    final result = await SessionManager.restore();
    if (!mounted) return;
    setState(() {
      _destination = result == null
          ? const HomeScreen()
          : result.role == 'admin'
          ? const AdminAppShell()
          : const UserAppShell();
    });
  }

  @override
  Widget build(BuildContext context) {
    return _destination ?? const _SessionLoadingScreen();
  }
}

class _SessionLoadingScreen extends StatelessWidget {
  const _SessionLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.burgundy,
      body: Center(child: CircularProgressIndicator(color: Colors.white)),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.burgundy,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/welcome-background.png',
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x08000000),
                  Color(0x00000000),
                  Color(0x25000000),
                ],
                stops: [0, 0.65, 1],
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 38),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: SizedBox(
                    width: 360,
                    height: 760,
                    child: Column(
                      children: [
                        const SizedBox(height: 28),
                        SizedBox(
                          width: 230,
                          height: 300,
                          child: Image.asset(
                            'assets/mfu-logo.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(height: 22),
                        const Text(
                          'MFU',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 66,
                            height: 1,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 13),
                        const Text(
                          'SmartGuide',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 40,
                            height: 1,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(height: 100),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () =>
                                Navigator.pushNamed(context, '/login'),
                            style: ElevatedButton.styleFrom(
                              foregroundColor: AppColors.burgundyDark,
                              backgroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(62),
                              elevation: 7,
                              shadowColor: Colors.black45,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text(
                              'START',
                              style: TextStyle(
                                fontSize: 25,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 3,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
